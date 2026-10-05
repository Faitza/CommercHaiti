-- ════════════════════════════════════════════════════════════════
-- CommercHaiti — Notifications (in-app + push)
--
-- Ce qui est créé ici :
--   1. public.device_tokens  : le jeton FCM de chaque téléphone connecté
--      (un utilisateur peut avoir plusieurs téléphones).
--   2. public.notifications  : la boîte de notifications de chaque
--      utilisateur (affichée dans l'app, écran "Notifications").
--   3. users.notif_commandes / users.notif_nouveaux_produits : les
--      préférences, stockées sur le serveur pour que les triggers les
--      respectent (avant, elles n'étaient que sur le téléphone).
--   4. Des triggers qui insèrent automatiquement une notification :
--        - nouvelle commande          → le vendeur
--        - changement de statut       → le client
--        - nouveau produit en vente   → les clients qui ont la boutique
--                                       en favori
--
-- L'envoi PUSH vers le téléphone est fait par l'Edge Function
-- supabase/functions/send-push, appelée par un Database Webhook sur
-- INSERT dans public.notifications (voir supabase/NOTIFICATIONS.md).
-- Sans ce webhook, les notifications restent visibles dans l'app.
--
-- À exécuter après schema.sql et functions.sql. Peut être relancé sans
-- erreur (if not exists / or replace / drop ... if exists).
-- ════════════════════════════════════════════════════════════════

-- ────────────────────────────────
-- 1. DEVICE_TOKENS
-- ────────────────────────────────
create table if not exists public.device_tokens (
  token        text primary key,
  user_id      uuid not null references auth.users(id) on delete cascade,
  platform     text not null default 'android',
  updated_at   timestamptz not null default now()
);

create index if not exists idx_device_tokens_user on public.device_tokens(user_id);

alter table public.device_tokens enable row level security;

-- Chaque utilisateur gère seulement ses propres jetons. Un même téléphone
-- peut changer de compte : le jeton est alors réattribué au nouveau
-- compte par register_device_token() ci-dessous (SECURITY DEFINER), car
-- un simple upsert serait bloqué par RLS (la ligne appartient à l'ancien
-- compte).
drop policy if exists "device_tokens_select_own" on public.device_tokens;
create policy "device_tokens_select_own" on public.device_tokens
  for select using (auth.uid() = user_id);
drop policy if exists "device_tokens_delete_own" on public.device_tokens;
create policy "device_tokens_delete_own" on public.device_tokens
  for delete using (auth.uid() = user_id);

create or replace function public.register_device_token(
  p_token     text,
  p_platform  text default 'android'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'non_connecte';
  end if;
  insert into public.device_tokens (token, user_id, platform, updated_at)
  values (p_token, auth.uid(), coalesce(p_platform, 'android'), now())
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = now();
end;
$$;

grant execute on function public.register_device_token(text, text) to authenticated;

-- ────────────────────────────────
-- 2. NOTIFICATIONS
-- ────────────────────────────────
create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  -- 'nouvelle_commande' | 'statut_commande' | 'nouveau_produit'
  type        text not null,
  titre       text not null,
  message     text not null,
  -- Données pour ouvrir le bon écran au tap : order_id, product_id, shop_id
  data        jsonb not null default '{}'::jsonb,
  lu          boolean not null default false,
  created_at  timestamptz not null default now()
);

create index if not exists idx_notifications_user
  on public.notifications(user_id, created_at desc);

alter table public.notifications enable row level security;

-- Lecture / marquer comme lu / supprimer : seulement ses propres
-- notifications. Pas de policy INSERT : seules les fonctions trigger
-- (SECURITY DEFINER) ci-dessous en créent.
drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own" on public.notifications
  for select using (auth.uid() = user_id);
drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own" on public.notifications
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "notifications_delete_own" on public.notifications;
create policy "notifications_delete_own" on public.notifications
  for delete using (auth.uid() = user_id);

-- Realtime : le badge de la cloche se met à jour sans recharger l'écran.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;

-- ────────────────────────────────
-- 3. PRÉFÉRENCES (sur le serveur)
-- ────────────────────────────────
alter table public.users
  add column if not exists notif_commandes boolean not null default true;
alter table public.users
  add column if not exists notif_nouveaux_produits boolean not null default true;

-- ────────────────────────────────
-- 4. TRIGGERS
-- ────────────────────────────────

-- Libellé lisible d'un statut de commande (mêmes valeurs que
-- orders.statut et OrderModel).
create or replace function public.libelle_statut_commande(p_statut text)
returns text
language sql
immutable
as $$
  select case p_statut
    when 'nouvelle'    then 'reçue'
    when 'acceptee'    then 'acceptée'
    when 'preparation' then 'en préparation'
    when 'livraison'   then 'en route'
    when 'livree'      then 'livrée'
    when 'annulee'     then 'annulée'
    else p_statut
  end;
$$;

-- Nouvelle commande → notification au vendeur.
create or replace function public.notifier_nouvelle_commande()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_veut boolean;
begin
  select coalesce(notif_commandes, true) into v_veut
  from public.users where id = new.seller_id;

  if coalesce(v_veut, true) then
    insert into public.notifications (user_id, type, titre, message, data)
    values (
      new.seller_id,
      'nouvelle_commande',
      'Nouvelle commande',
      'Commande de ' || to_char(new.total, 'FM999G999G990') || ' HTG — zone ' || new.zone,
      jsonb_build_object('order_id', new.id, 'shop_id', new.shop_id)
    );
  end if;
  return null;
end;
$$;

drop trigger if exists trg_notifier_nouvelle_commande on public.orders;
create trigger trg_notifier_nouvelle_commande
after insert on public.orders
for each row execute function public.notifier_nouvelle_commande();

-- Changement de statut → notification au client (sauf quand c'est le
-- client lui-même qui annule) et au vendeur quand le client annule.
create or replace function public.notifier_statut_commande()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_boutique text;
  v_dest     uuid;
  v_veut     boolean;
  v_titre    text;
  v_message  text;
begin
  if new.statut is not distinct from old.statut then
    return null;
  end if;

  select nom into v_boutique from public.shops where id = new.shop_id;

  if new.statut = 'annulee' and auth.uid() = new.client_id then
    -- Le client a annulé lui-même → on prévient le vendeur.
    v_dest    := new.seller_id;
    v_titre   := 'Commande annulée';
    v_message := 'Le client a annulé sa commande de '
                 || to_char(new.total, 'FM999G999G990') || ' HTG.';
  else
    v_dest    := new.client_id;
    v_titre   := 'Commande ' || public.libelle_statut_commande(new.statut);
    v_message := 'Votre commande chez ' || coalesce(v_boutique, 'la boutique')
                 || ' est ' || public.libelle_statut_commande(new.statut) || '.';
  end if;

  select coalesce(notif_commandes, true) into v_veut
  from public.users where id = v_dest;

  if coalesce(v_veut, true) then
    insert into public.notifications (user_id, type, titre, message, data)
    values (
      v_dest,
      'statut_commande',
      v_titre,
      v_message,
      jsonb_build_object('order_id', new.id, 'shop_id', new.shop_id,
                         'statut', new.statut)
    );
  end if;
  return null;
end;
$$;

drop trigger if exists trg_notifier_statut_commande on public.orders;
create trigger trg_notifier_statut_commande
after update of statut on public.orders
for each row execute function public.notifier_statut_commande();

-- Nouveau produit → notification aux clients qui ont la boutique en
-- favori et qui n'ont pas désactivé "Nouveaux produits".
--
-- Compatible avec migration_admin_moderation.sql (PR #4) sans en
-- dépendre : les colonnes masque_admin / statut_validation sont lues via
-- to_jsonb(), donc ce trigger fonctionne que ces colonnes existent ou non.
-- Un produit masqué par l'admin ou une boutique pas encore approuvée ne
-- déclenche aucune notification.
create or replace function public.notifier_nouveau_produit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop public.shops%rowtype;
begin
  if not new.disponible
     or coalesce((to_jsonb(new) ->> 'masque_admin')::boolean, false) then
    return null;
  end if;

  select * into v_shop from public.shops where id = new.shop_id;
  if not found
     or coalesce(to_jsonb(v_shop) ->> 'statut_validation', 'approuvee') <> 'approuvee' then
    return null;
  end if;

  insert into public.notifications (user_id, type, titre, message, data)
  select
    f.client_id,
    'nouveau_produit',
    'Nouveau chez ' || v_shop.nom,
    new.nom || ' — ' || to_char(coalesce(new.prix_promo, new.prix), 'FM999G999G990') || ' HTG',
    jsonb_build_object('product_id', new.id, 'shop_id', new.shop_id)
  from public.favorites f
  join public.users u on u.id = f.client_id
  where f.shop_id = new.shop_id
    and coalesce(u.notif_nouveaux_produits, true);

  return null;
end;
$$;

drop trigger if exists trg_notifier_nouveau_produit on public.products;
create trigger trg_notifier_nouveau_produit
after insert on public.products
for each row execute function public.notifier_nouveau_produit();
