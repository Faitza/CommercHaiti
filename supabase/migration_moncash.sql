-- ════════════════════════════════════════════════════════════════
-- Migration — paiement MonCash avec confirmation manuelle
-- (feature/moncash-manuel)
--
-- Pas d'API MonCash : le client envoie l'argent au numéro MonCash de la
-- boutique depuis son téléphone, saisit le numéro de transaction dans
-- l'app, et le vendeur confirme qu'il a bien reçu le paiement.
--
-- À exécuter UNE fois dans Supabase → SQL Editor (peut être relancé).
-- ════════════════════════════════════════════════════════════════

-- ─── 1. Colonnes ────────────────────────────────────────────────
-- Numéro MonCash de la boutique (vide = MonCash non proposé).
alter table public.shops
  add column if not exists moncash_numero text;

alter table public.orders
  add column if not exists mode_paiement text not null default 'livraison';
alter table public.orders
  add column if not exists moncash_reference text;
-- null (paiement à la livraison) | 'en_attente' | 'confirme' | 'refuse'
alter table public.orders
  add column if not exists paiement_statut text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'orders_mode_paiement_check') then
    alter table public.orders add constraint orders_mode_paiement_check
      check (mode_paiement in ('livraison', 'moncash'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'orders_paiement_statut_check') then
    alter table public.orders add constraint orders_paiement_statut_check
      check (paiement_statut in ('en_attente', 'confirme', 'refuse'));
  end if;
end $$;

-- ─── 2. Le client déclare son paiement MonCash ──────────────────
-- SECURITY DEFINER : la RLS ne laisse le client modifier sa commande que
-- pour l'annuler. Utilisable juste après la création de la commande, ou
-- plus tard depuis l'écran de suivi (ex. si le vendeur a répondu « pas
-- reçu » et que le client corrige le numéro de transaction).
create or replace function public.declarer_paiement_moncash(
  p_order_id   uuid,
  p_reference  text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order   public.orders%rowtype;
  v_numero  text;
begin
  if auth.uid() is null then
    raise exception 'non_connecte';
  end if;
  if p_reference is null or length(trim(p_reference)) < 4 then
    raise exception 'reference_invalide';
  end if;

  select * into v_order from public.orders where id = p_order_id for update;
  if not found or v_order.client_id <> auth.uid() then
    raise exception 'commande_introuvable';
  end if;
  if v_order.statut in ('livree', 'annulee') then
    raise exception 'commande_terminee';
  end if;
  if v_order.paiement_statut = 'confirme' then
    raise exception 'paiement_deja_confirme';
  end if;

  select moncash_numero into v_numero from public.shops where id = v_order.shop_id;
  if coalesce(trim(v_numero), '') = '' then
    raise exception 'moncash_non_disponible';
  end if;

  update public.orders
  set mode_paiement     = 'moncash',
      moncash_reference = trim(p_reference),
      paiement_statut   = 'en_attente'
  where id = p_order_id;
end;
$$;

revoke execute on function public.declarer_paiement_moncash(uuid, text) from public, anon;
grant execute on function public.declarer_paiement_moncash(uuid, text) to authenticated;

-- ─── 3. Le vendeur confirme (ou non) la réception ───────────────
-- Le vendeur peut déjà modifier ses commandes (policy
-- orders_update_seller) ; cette fonction ajoute seulement les contrôles
-- (bonne commande, paiement déclaré) et un point d'entrée clair.
create or replace function public.confirmer_paiement_moncash(
  p_order_id  uuid,
  p_recu      boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if not found or v_order.seller_id <> auth.uid() then
    raise exception 'commande_introuvable';
  end if;
  if v_order.mode_paiement <> 'moncash' or v_order.paiement_statut is null then
    raise exception 'aucun_paiement_declare';
  end if;

  update public.orders
  set paiement_statut = case when p_recu then 'confirme' else 'refuse' end
  where id = p_order_id;
end;
$$;

revoke execute on function public.confirmer_paiement_moncash(uuid, boolean) from public, anon;
grant execute on function public.confirmer_paiement_moncash(uuid, boolean) to authenticated;
