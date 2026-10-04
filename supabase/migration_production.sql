-- ════════════════════════════════════════════════════════════════
-- Migration — checklist production (feature/checklist-production)
--
-- Points couverts côté base de données :
--   01 / 02  limite le nombre de requêtes par utilisateur (commandes,
--            avis, produits, boutiques, favoris, journal d'erreurs)
--   10       empêche la double commande / le double paiement
--            (clé d'idempotence + n° de transaction MonCash unique)
--   12       index pour accélérer les recherches et les listes
--   15       poids et type maximum des fichiers envoyés (buckets)
--   18       journal des erreurs de l'app (table app_errors)
--
-- À exécuter UNE fois dans Supabase → SQL Editor, APRÈS schema.sql et
-- functions.sql (et après les migrations des autres PR si elles sont
-- déjà passées). Peut être relancée sans risque.
-- Si migration_moncash.sql est exécutée PLUS TARD, relancer ce fichier
-- ensuite pour créer l'index unique MonCash (section 6).
-- ════════════════════════════════════════════════════════════════


-- ─── 1. Limite de requêtes (points 01 et 02) ────────────────────
-- Compteur par utilisateur, par action et par tranche de temps.
-- Personne ne lit/écrit cette table directement (RLS sans policy) :
-- seule la fonction verifier_limite() (SECURITY DEFINER) y touche.
create table if not exists public.limites_requetes (
  user_id   uuid        not null,
  action    text        not null,
  fenetre   timestamptz not null,
  compteur  integer     not null default 0,
  primary key (user_id, action, fenetre)
);
alter table public.limites_requetes enable row level security;

-- Lève l'erreur 'trop_de_requetes' si l'utilisateur connecté a déjà
-- fait [p_max] fois l'action [p_action] dans la tranche [p_fenetre]
-- en cours. Les visiteurs non connectés partagent un compteur commun
-- (uuid 0) — utilisé seulement pour le journal d'erreurs. Les appels
-- d'administration (SQL Editor, service_role) ne sont pas limités.
create or replace function public.verifier_limite(
  p_action   text,
  p_max      integer,
  p_fenetre  interval
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid     uuid := coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid);
  v_debut   timestamptz := date_bin(p_fenetre, now(), timestamptz '2000-01-01');
  v_total   integer;
begin
  -- Appels faits depuis le SQL Editor, le service_role (admin) ou un
  -- script serveur : pas de limite (ex. seed.sql, outils d'admin).
  if auth.uid() is null and coalesce(auth.role(), '') <> 'anon' then
    return;
  end if;

  insert into public.limites_requetes as l (user_id, action, fenetre, compteur)
  values (v_uid, p_action, v_debut, 1)
  on conflict (user_id, action, fenetre)
  do update set compteur = l.compteur + 1
  returning compteur into v_total;

  if v_total > p_max then
    raise exception 'trop_de_requetes'
      using hint = 'Limite ' || p_action || ' : ' || p_max || ' par ' || p_fenetre;
  end if;

  -- Ménage (environ 1 appel sur 100) : on efface les compteurs de plus
  -- d'un jour pour que la table reste petite.
  if random() < 0.01 then
    delete from public.limites_requetes where fenetre < now() - interval '1 day';
  end if;
end;
$$;

revoke execute on function public.verifier_limite(text, integer, interval) from public, anon, authenticated;

-- Trigger générique : appliqué AVANT insertion sur une table.
-- Arguments : action, max, fenêtre (ex. 'avis', '10', '1 hour').
create or replace function public.trg_limite_insertion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.verifier_limite(tg_argv[0], tg_argv[1]::integer, tg_argv[2]::interval);
  return new;
end;
$$;

-- Avis : 10 par heure et par client.
drop trigger if exists trg_limite_reviews on public.reviews;
create trigger trg_limite_reviews
before insert on public.reviews
for each row execute function public.trg_limite_insertion('avis', '10', '1 hour');

-- Produits : 60 créations par heure et par vendeur.
drop trigger if exists trg_limite_products on public.products;
create trigger trg_limite_products
before insert on public.products
for each row execute function public.trg_limite_insertion('produit', '60', '1 hour');

-- Boutiques : 3 créations par jour et par compte.
drop trigger if exists trg_limite_shops on public.shops;
create trigger trg_limite_shops
before insert on public.shops
for each row execute function public.trg_limite_insertion('boutique', '3', '1 day');

-- Favoris : 60 ajouts par minute (protège contre un bouton martelé).
drop trigger if exists trg_limite_favorites on public.favorites;
create trigger trg_limite_favorites
before insert on public.favorites
for each row execute function public.trg_limite_insertion('favori', '60', '1 minute');


-- ─── 2. Commande : clé d'idempotence + limite (points 01 et 10) ─
-- Chaque formulaire de commande envoie une clé unique. Si la même clé
-- revient (double appui, nouvel essai après un délai réseau dépassé
-- alors que la 1re requête avait abouti), on renvoie la commande déjà
-- créée au lieu d'en créer une 2e.
alter table public.orders
  add column if not exists cle_idempotence uuid;

create unique index if not exists idx_orders_cle_idempotence
  on public.orders (client_id, cle_idempotence)
  where cle_idempotence is not null;

-- Remplace la version à 9 paramètres de functions.sql (même logique de
-- stock, + p_cle_idempotence, + limites, + contrôle que le client qui
-- commande est bien l'utilisateur connecté).
drop function if exists public.create_order_atomic(
  uuid, uuid, uuid, jsonb, numeric, text, text, text, text
);

create or replace function public.create_order_atomic(
  p_client_id           uuid,
  p_shop_id             uuid,
  p_seller_id           uuid,
  p_items               jsonb,
  p_total               numeric,
  p_adresse_livraison   text,
  p_zone                text,
  p_telephone_client    text,
  p_note_vendeur        text default null,
  p_cle_idempotence     uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_id      uuid;
  v_item          jsonb;
  v_product_id    uuid;
  v_quantite      integer;
  v_stock_actuel  integer;
begin
  -- La fonction contourne la RLS (SECURITY DEFINER) : on vérifie donc
  -- que la commande est passée au nom de l'utilisateur connecté.
  if auth.uid() is null or auth.uid() <> p_client_id then
    raise exception 'non_autorise';
  end if;

  -- Même clé déjà utilisée → on renvoie la commande existante.
  if p_cle_idempotence is not null then
    select id into v_order_id
    from public.orders
    where client_id = p_client_id and cle_idempotence = p_cle_idempotence;
    if v_order_id is not null then
      return v_order_id;
    end if;
  end if;

  -- Point 01 : au plus 5 commandes par minute et 50 par jour par client.
  perform public.verifier_limite('commande_minute', 5, interval '1 minute');
  perform public.verifier_limite('commande_jour', 50, interval '1 day');

  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'panier_vide';
  end if;

  -- 1ère passe : verrouille (for update) et vérifie le stock de CHAQUE
  -- article AVANT toute écriture (voir functions.sql).
  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_product_id := (v_item->>'product_id')::uuid;
    v_quantite   := (v_item->>'quantite')::integer;

    select stock into v_stock_actuel
    from public.products
    where id = v_product_id
    for update;

    if v_stock_actuel is null then
      raise exception 'produit_introuvable';
    end if;

    if v_stock_actuel < v_quantite then
      raise exception 'stock_insuffisant';
    end if;
  end loop;

  begin
    insert into public.orders (
      client_id, shop_id, seller_id, total, statut,
      adresse_livraison, zone, telephone_client, note_vendeur,
      cle_idempotence
    ) values (
      p_client_id, p_shop_id, p_seller_id, p_total, 'nouvelle',
      p_adresse_livraison, p_zone, p_telephone_client, p_note_vendeur,
      p_cle_idempotence
    )
    returning id into v_order_id;
  exception when unique_violation then
    -- Deux appels avec la même clé exactement en même temps : le 2e
    -- renvoie la commande créée par le 1er.
    select id into v_order_id
    from public.orders
    where client_id = p_client_id and cle_idempotence = p_cle_idempotence;
    return v_order_id;
  end;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_product_id := (v_item->>'product_id')::uuid;
    v_quantite   := (v_item->>'quantite')::integer;

    update public.products
    set stock = stock - v_quantite,
        total_commandes = total_commandes + v_quantite
    where id = v_product_id;

    insert into public.order_items (
      order_id, product_id, nom, prix, quantite, couleur, taille
    ) values (
      v_order_id,
      v_product_id,
      v_item->>'nom',
      (v_item->>'prix')::numeric,
      v_quantite,
      v_item->>'couleur',
      v_item->>'taille'
    );
  end loop;

  return v_order_id;
end;
$$;

revoke execute on function public.create_order_atomic(
  uuid, uuid, uuid, jsonb, numeric, text, text, text, text, uuid
) from public, anon;
grant execute on function public.create_order_atomic(
  uuid, uuid, uuid, jsonb, numeric, text, text, text, text, uuid
) to authenticated;


-- ─── 3. Index (point 12) ────────────────────────────────────────
-- Recherche produit par nom (`ilike '%texte%'` sur l'accueil et dans
-- « Où acheter ce produit ») : index trigramme, sans lui Postgres lit
-- toute la table à chaque lettre tapée.
create extension if not exists pg_trgm with schema extensions;
do $$
declare
  v_schema text;
begin
  -- pg_trgm peut déjà exister dans un autre schéma (ex. public).
  select n.nspname into v_schema
  from pg_extension e join pg_namespace n on n.oid = e.extnamespace
  where e.extname = 'pg_trgm';
  execute format(
    'create index if not exists idx_products_nom_trgm
       on public.products using gin (nom %I.gin_trgm_ops)', v_schema);
end $$;

-- Produits populaires / catalogue (disponible = true, tri par ventes).
create index if not exists idx_products_dispo_ventes
  on public.products (disponible, total_commandes desc);
-- Produits d'une boutique par catégorie (fiche boutique, sous-catégories).
create index if not exists idx_products_shop_categorie
  on public.products (shop_id, categorie, sous_categorie);
-- Section « Promotions ».
create index if not exists idx_products_promo
  on public.products (disponible)
  where prix_promo is not null;

-- Boutiques ouvertes (récentes / mieux notées).
create index if not exists idx_shops_ouvertes_recentes
  on public.shops (is_open, created_at desc);
create index if not exists idx_shops_ouvertes_note
  on public.shops (is_open, rating desc);

-- Commandes d'un client / d'un vendeur, les plus récentes d'abord.
-- Remplacent les index sur client_id / seller_id seuls.
create index if not exists idx_orders_client_date
  on public.orders (client_id, created_at desc);
create index if not exists idx_orders_seller_date
  on public.orders (seller_id, created_at desc);
drop index if exists public.idx_orders_client;
drop index if exists public.idx_orders_seller;
create index if not exists idx_orders_shop
  on public.orders (shop_id);

-- Clés étrangères sans index (suppressions et jointures plus rapides).
create index if not exists idx_order_items_product
  on public.order_items (product_id);
create index if not exists idx_reviews_order
  on public.reviews (order_id);
create index if not exists idx_reviews_client
  on public.reviews (client_id);
create index if not exists idx_favorites_shop
  on public.favorites (shop_id);

-- Avis d'une boutique, les plus récents d'abord (remplace idx_reviews_shop).
create index if not exists idx_reviews_shop_date
  on public.reviews (shop_id, created_at desc);
drop index if exists public.idx_reviews_shop;


-- ─── 4. Fichiers envoyés (point 15) ─────────────────────────────
-- 2 Mo maximum par fichier, images seulement. L'app compresse déjà
-- avant l'envoi (voir lib/services/storage_service.dart) ; cette limite
-- protège contre un envoi qui contournerait l'app.
update storage.buckets
set file_size_limit    = 2097152,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id in ('products', 'shops', 'litiges');


-- ─── 5. Journal des erreurs de l'app (point 18) ─────────────────
create table if not exists public.app_errors (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  user_id     uuid,
  message     text not null,
  stack       text,
  contexte    text,
  plateforme  text
);
create index if not exists idx_app_errors_date
  on public.app_errors (created_at desc);
-- RLS sans policy : personne ne lit la table depuis l'app ; on la
-- consulte dans Supabase (SQL Editor / Table Editor).
alter table public.app_errors enable row level security;

create or replace function public.journaliser_erreur(
  p_message     text,
  p_stack       text default null,
  p_contexte    text default null,
  p_plateforme  text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- 30 erreurs par minute par utilisateur ; 300 par minute pour tous
  -- les visiteurs non connectés ensemble.
  perform public.verifier_limite(
    'journal_erreur',
    case when auth.uid() is null then 300 else 30 end,
    interval '1 minute');

  insert into public.app_errors (user_id, message, stack, contexte, plateforme)
  values (
    auth.uid(),
    left(coalesce(p_message, ''), 1000),
    left(p_stack, 4000),
    left(p_contexte, 200),
    left(p_plateforme, 30)
  );

  -- On ne garde que 90 jours d'historique.
  if random() < 0.01 then
    delete from public.app_errors where created_at < now() - interval '90 days';
  end if;
end;
$$;

revoke execute on function public.journaliser_erreur(text, text, text, text) from public;
grant execute on function public.journaliser_erreur(text, text, text, text) to anon, authenticated;


-- ─── 6. MonCash : un n° de transaction = une seule commande (point 10)
-- Empêche de déclarer le même paiement MonCash pour deux commandes.
-- Ne fait rien tant que migration_moncash.sql (PR MonCash) n'est pas
-- passée : relancer ce fichier après elle.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'orders'
      and column_name = 'moncash_reference'
  ) then
    execute $i$
      create unique index if not exists idx_orders_moncash_reference_unique
        on public.orders (lower(trim(moncash_reference)))
        where moncash_reference is not null
          and paiement_statut is distinct from 'refuse'
    $i$;
  end if;
end $$;


-- ─── Vérification ───────────────────────────────────────────────
-- Doit lister les nouveaux index.
select indexname from pg_indexes
where schemaname = 'public' and indexname in (
  'idx_products_nom_trgm', 'idx_orders_client_date', 'idx_orders_cle_idempotence',
  'idx_reviews_shop_date', 'idx_app_errors_date'
);
