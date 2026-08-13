-- ════════════════════════════════════════════════════════════════
-- CommercHaiti — Fonctions RPC Supabase
-- BF-020 : transaction atomique stock-- ET création commande,
-- appelée depuis lib/services/database_service.dart → createOrder().
-- Les noms de paramètres DOIVENT correspondre exactement à ceux
-- envoyés par _supabase.rpc('create_order_atomic', params: {...}).
--
-- À exécuter après schema.sql.
-- ════════════════════════════════════════════════════════════════

-- IMPORTANT — mise à jour du 2026 : l'ancienne version de cette fonction
-- (14 paramètres, un seul p_product_id/p_quantite) ne traitait QU'UN SEUL
-- article par commande. Quand un client mettait plusieurs produits
-- différents dans son panier, seul `cart.items.first` était réellement
-- envoyé côté serveur : la commande n'apparaissait chez le vendeur qu'avec
-- un seul article, et le stock des AUTRES produits n'était jamais
-- décrémenté (aucune ligne order_items créée pour eux). La nouvelle
-- version ci-dessous accepte un tableau JSON `p_items` (un élément par
-- produit du panier) et traite chaque article dans la même transaction :
-- toujours atomique (si un seul produit manque de stock, TOUTE la
-- commande est annulée, rien n'est décrémenté), mais gère maintenant
-- correctement un panier à plusieurs produits.
--
-- Exécutez d'abord ce DROP pour retirer l'ancienne signature (sinon les
-- deux versions coexisteraient et Postgres ne saurait pas laquelle
-- appeler depuis Dart) :
drop function if exists public.create_order_atomic(
  uuid, uuid, uuid, uuid, integer, numeric, text, text, text, text, numeric, text, text, text
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
  p_note_vendeur        text default null
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
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'panier_vide';
  end if;

  -- 1ère passe : verrouille (for update) et vérifie le stock de CHAQUE
  -- article AVANT toute écriture. Si un seul produit manque de stock,
  -- l'exception interrompt la fonction entière et Postgres annule
  -- automatiquement tout ce qui aurait pu être fait plus haut (rien
  -- n'est donc jamais décrémenté "à moitié").
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

  -- 2ème passe : tout le stock est confirmé suffisant → on crée la
  -- commande (une seule ligne `orders` pour tout le panier)...
  insert into public.orders (
    client_id, shop_id, seller_id, total, statut,
    adresse_livraison, zone, telephone_client, note_vendeur
  ) values (
    p_client_id, p_shop_id, p_seller_id, p_total, 'nouvelle',
    p_adresse_livraison, p_zone, p_telephone_client, p_note_vendeur
  )
  returning id into v_order_id;

  -- ...puis on décrémente le stock et on insère une ligne order_items
  -- POUR CHAQUE article du panier (au lieu d'un seul avant ce correctif).
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

-- Exécutable par tout utilisateur authentifié (le client qui commande)
grant execute on function public.create_order_atomic(
  uuid, uuid, uuid, jsonb, numeric, text, text, text, text
) to authenticated;

-- ════════════════════════════════════════════════════════════════
-- Téléphone du vendeur — bouton WhatsApp (BF-012)
-- La table users est protégée par RLS (chacun lit seulement sa propre
-- ligne), mais un client doit pouvoir contacter le vendeur d'une
-- boutique qu'il consulte. Cette fonction SECURITY DEFINER expose
-- UNIQUEMENT le téléphone d'un vendeur (role='seller'), rien d'autre.
-- ════════════════════════════════════════════════════════════════
create or replace function public.get_vendor_telephone(p_user_id uuid)
returns text
language sql
security definer
set search_path = public
as $$
  select telephone from public.users
  where id = p_user_id and role = 'seller';
$$;

grant execute on function public.get_vendor_telephone(uuid) to authenticated, anon;
