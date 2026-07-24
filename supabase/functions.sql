-- ════════════════════════════════════════════════════════════════
-- CommercHaiti — Fonctions RPC Supabase
-- BF-020 : transaction atomique stock-- ET création commande,
-- appelée depuis lib/services/database_service.dart → createOrder().
-- Les noms de paramètres DOIVENT correspondre exactement à ceux
-- envoyés par _supabase.rpc('create_order_atomic', params: {...}).
--
-- À exécuter après schema.sql.
-- ════════════════════════════════════════════════════════════════

create or replace function public.create_order_atomic(
  p_client_id           uuid,
  p_shop_id             uuid,
  p_seller_id           uuid,
  p_product_id          uuid,
  p_quantite            integer,
  p_total               numeric,
  p_adresse_livraison   text,
  p_zone                text,
  p_telephone_client    text,
  p_nom_produit         text,
  p_prix_produit        numeric,
  p_couleur             text default null,
  p_taille              text default null,
  p_note_vendeur        text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stock_actuel  integer;
  v_order_id      uuid;
begin
  -- Verrouille la ligne produit pour éviter une survente concurrente
  select stock into v_stock_actuel
  from public.products
  where id = p_product_id
  for update;

  if v_stock_actuel is null then
    raise exception 'produit_introuvable';
  end if;

  if v_stock_actuel < p_quantite then
    raise exception 'stock_insuffisant';
  end if;

  update public.products
  set stock = stock - p_quantite,
      total_commandes = total_commandes + p_quantite
  where id = p_product_id;

  insert into public.orders (
    client_id, shop_id, seller_id, total, statut,
    adresse_livraison, zone, telephone_client, note_vendeur
  ) values (
    p_client_id, p_shop_id, p_seller_id, p_total, 'nouvelle',
    p_adresse_livraison, p_zone, p_telephone_client, p_note_vendeur
  )
  returning id into v_order_id;

  insert into public.order_items (
    order_id, product_id, nom, prix, quantite, couleur, taille
  ) values (
    v_order_id, p_product_id, p_nom_produit, p_prix_produit, p_quantite, p_couleur, p_taille
  );

  return v_order_id;
end;
$$;

-- Exécutable par tout utilisateur authentifié (le client qui commande)
grant execute on function public.create_order_atomic(
  uuid, uuid, uuid, uuid, integer, numeric, text, text, text, text, numeric, text, text, text
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
