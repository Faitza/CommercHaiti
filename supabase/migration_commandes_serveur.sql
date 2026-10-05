-- ════════════════════════════════════════════════════════════════
-- CommercHaiti — prix, total et stock des commandes décidés par le serveur
-- À exécuter dans Supabase → SQL Editor, après schema.sql et functions.sql.
-- Indépendant des autres migrations : peut tourner avant ou après
-- migration_frais_livraison.sql, migration_production.sql, etc.
--
-- Avant : create_order_atomic() enregistrait le prix, le nom et le total
-- envoyés par le téléphone du client. Une app modifiée pouvait donc
-- commander un produit à 1 HTG, ou au nom d'un autre client / vendeur.
-- Le stock était aussi baissé deux fois : à la commande (ici, côté
-- serveur) puis une 2e fois par l'app quand le vendeur acceptait.
--
-- Après :
--   1. chaque ligne order_items prend le prix (promo comprise) et le nom
--      du produit dans la table products, et la quantité doit être ≥ 1 ;
--   2. le total de la commande est recalculé = somme des articles
--      + frais_livraison (si la colonne existe, voir migration_frais_livraison) ;
--   3. seller_id vient de la boutique, et client_id doit être l'utilisateur
--      connecté ;
--   4. le stock n'est baissé qu'une fois (à la commande) et il est remis
--      quand une commande non livrée est annulée.
--
-- Ce sont des triggers : ils restent actifs même quand une autre
-- migration remplace create_order_atomic() (ex. migration_production.sql).
-- ════════════════════════════════════════════════════════════════

-- ─── 1. Commande : vendeur et client fiables ────────────────────
create or replace function public.commande_valeurs_serveur()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_vendeur uuid;
begin
  -- auth.uid() est null dans le SQL Editor (service_role) : autorisé.
  if auth.uid() is not null and new.client_id is distinct from auth.uid() then
    raise exception 'non_autorise';
  end if;

  select proprietaire_id into v_vendeur from public.shops where id = new.shop_id;
  if v_vendeur is null then
    raise exception 'boutique_introuvable';
  end if;
  new.seller_id := v_vendeur;
  return new;
end;
$$;

drop trigger if exists trg_commande_valeurs_serveur on public.orders;
create trigger trg_commande_valeurs_serveur
before insert on public.orders
for each row execute function public.commande_valeurs_serveur();

-- ─── 2. Article : prix et nom lus dans products ─────────────────
create or replace function public.article_prix_serveur()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_produit public.products%rowtype;
  v_shop    uuid;
begin
  if new.quantite is null or new.quantite < 1 then
    raise exception 'quantite_invalide';
  end if;

  select * into v_produit from public.products where id = new.product_id;
  if v_produit.id is null then
    raise exception 'produit_introuvable';
  end if;

  select shop_id into v_shop from public.orders where id = new.order_id;
  if v_produit.shop_id is distinct from v_shop then
    raise exception 'produit_autre_boutique';
  end if;

  -- Même règle que ProductModel.prixAffiche : prix promo s'il existe.
  new.prix := coalesce(v_produit.prix_promo, v_produit.prix);
  new.nom  := v_produit.nom;
  return new;
end;
$$;

drop trigger if exists trg_article_prix_serveur on public.order_items;
create trigger trg_article_prix_serveur
before insert on public.order_items
for each row execute function public.article_prix_serveur();

-- ─── 3. Total recalculé après chaque article ────────────────────
-- to_jsonb(o) lit frais_livraison sans planter si la colonne n'existe
-- pas encore (migration_frais_livraison.sql pas encore exécutée).
create or replace function public.commande_recalculer_total()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.orders o
  set total = (
        select coalesce(sum(i.prix * i.quantite), 0)
        from public.order_items i
        where i.order_id = new.order_id
      )
      + coalesce((to_jsonb(o) ->> 'frais_livraison')::numeric, 0)
  where o.id = new.order_id;
  return null;
end;
$$;

drop trigger if exists trg_commande_recalculer_total on public.order_items;
create trigger trg_commande_recalculer_total
after insert on public.order_items
for each row execute function public.commande_recalculer_total();

-- ─── 4. Stock remis à l'annulation ──────────────────────────────
-- create_order_atomic() baisse le stock dès la commande. Si la commande
-- est annulée avant la livraison (client, ou vendeur qui refuse), les
-- articles redeviennent disponibles. Une commande livrée puis annulée
-- (litige) ne remet pas le stock : la marchandise est déjà partie.
create or replace function public.commande_remettre_stock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.statut = 'annulee' and old.statut not in ('annulee', 'livree') then
    update public.products p
    set stock = p.stock + i.quantite,
        total_commandes = greatest(p.total_commandes - i.quantite, 0)
    from (
      select product_id, sum(quantite) as quantite
      from public.order_items
      where order_id = new.id
      group by product_id
    ) i
    where p.id = i.product_id;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_commande_remettre_stock on public.orders;
create trigger trg_commande_remettre_stock
after update of statut on public.orders
for each row execute function public.commande_remettre_stock();
