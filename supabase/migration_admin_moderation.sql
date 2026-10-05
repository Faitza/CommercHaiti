-- ════════════════════════════════════════════════════════════════
-- Migration — appliquer dans l'app les décisions de l'admin web
-- (feature/admin-moderation)
--
-- PRÉREQUIS : avoir exécuté `supabase/admin_migration.sql` du dépôt
-- CommercHaiti-admin (colonnes statut_validation, is_blocked,
-- masque_admin, litige_* et fonction is_admin()).
--
-- À exécuter UNE fois dans Supabase → SQL Editor.
--
-- 1. Les clients (et visiteurs) ne voient que les boutiques approuvées
--    dont le vendeur n'est pas bloqué, et que les produits non masqués
--    de ces boutiques. Le vendeur voit toujours sa propre boutique et
--    ses produits ; un client voit encore la boutique de ses anciennes
--    commandes (historique, reçus).
-- 2. Commande refusée si le client est bloqué, la boutique invisible
--    ou un produit masqué.
-- 3. Un vendeur ne peut pas modifier lui-même les colonnes gérées par
--    l'admin (validation boutique, masquage produit, litiges).
-- ════════════════════════════════════════════════════════════════

-- ─── Fonctions utilitaires (SECURITY DEFINER : ignorent la RLS) ──
create or replace function public.is_user_blocked(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select is_blocked from public.users where id = p_uid), false);
$$;

create or replace function public.boutique_visible(p_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.shops s
    where s.id = p_shop_id
      and s.statut_validation = 'approuvee'
      and not public.is_user_blocked(s.proprietaire_id)
  );
$$;

-- ─── 1. Visibilité (RLS) ────────────────────────────────────────
drop policy if exists "shops_select_public" on public.shops;
create policy "shops_select_public" on public.shops
  for select using (
    public.boutique_visible(id)
    or proprietaire_id = auth.uid()
    or public.is_admin()
    or exists (
      select 1 from public.orders o
      where o.shop_id = shops.id and o.client_id = auth.uid()
    )
  );

drop policy if exists "products_select_public" on public.products;
create policy "products_select_public" on public.products
  for select using (
    (not masque_admin and public.boutique_visible(shop_id))
    or exists (
      select 1 from public.shops s
      where s.id = shop_id and s.proprietaire_id = auth.uid()
    )
    or public.is_admin()
  );

-- ─── 2. Garde-fous à la commande ────────────────────────────────
-- create_order_atomic() est SECURITY DEFINER (contourne la RLS) : ces
-- triggers s'exécutent dans sa transaction et l'annulent entièrement.
create or replace function public.verifier_commande_autorisee()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_user_blocked(new.client_id) then
    raise exception 'compte_bloque';
  end if;
  if not public.boutique_visible(new.shop_id) then
    raise exception 'boutique_indisponible';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_verifier_commande on public.orders;
create trigger trg_verifier_commande
before insert on public.orders
for each row execute function public.verifier_commande_autorisee();

create or replace function public.verifier_article_autorise()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (select 1 from public.products where id = new.product_id and masque_admin) then
    raise exception 'produit_indisponible';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_verifier_article on public.order_items;
create trigger trg_verifier_article
before insert on public.order_items
for each row execute function public.verifier_article_autorise();

-- ─── 3. Colonnes réservées aux admins ───────────────────────────
-- auth.uid() est null dans le SQL Editor (service_role) : autorisé.
create or replace function public.proteger_colonnes_admin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;

  if tg_table_name = 'shops' then
    if tg_op = 'INSERT' then
      new.statut_validation := 'en_attente';
    elsif new.statut_validation is distinct from old.statut_validation then
      raise exception 'Validation de la boutique réservée aux admins';
    end if;
  elsif tg_table_name = 'products' then
    if tg_op = 'INSERT' then
      new.masque_admin := false;
      new.motif_moderation := null;
    elsif new.masque_admin is distinct from old.masque_admin
       or new.motif_moderation is distinct from old.motif_moderation then
      raise exception 'Modération du produit réservée aux admins';
    end if;
  elsif tg_table_name = 'orders' and tg_op = 'UPDATE' then
    if new.litige_statut is distinct from old.litige_statut
       or new.litige_motif is distinct from old.litige_motif
       or new.litige_resolution is distinct from old.litige_resolution then
      raise exception 'Gestion des litiges réservée aux admins';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_proteger_admin_shops on public.shops;
create trigger trg_proteger_admin_shops
before insert or update on public.shops
for each row execute function public.proteger_colonnes_admin();

drop trigger if exists trg_proteger_admin_products on public.products;
create trigger trg_proteger_admin_products
before insert or update on public.products
for each row execute function public.proteger_colonnes_admin();

drop trigger if exists trg_proteger_admin_orders on public.orders;
create trigger trg_proteger_admin_orders
before update on public.orders
for each row execute function public.proteger_colonnes_admin();
