-- ════════════════════════════════════════════════════════════════
-- Migration — le client peut signaler un problème (litige) sur sa
-- commande depuis l'app (feature/litige-client).
--
-- PRÉREQUIS : admin_migration.sql (dépôt CommercHaiti-admin, colonnes
-- litige_*) puis migration_admin_moderation.sql.
--
-- Avant : seul un admin pouvait ouvrir un litige, depuis l'admin web.
-- Après : le client l'ouvre depuis l'écran de suivi de sa commande
-- (motif, description, jusqu'à 3 photos). L'admin le voit dans
-- l'admin web (filtre « Litiges ») et le résout comme avant.
--
-- À exécuter UNE fois dans Supabase → SQL Editor (peut être relancé).
-- ════════════════════════════════════════════════════════════════

-- ─── 1. Colonnes ────────────────────────────────────────────────
alter table public.orders
  add column if not exists litige_photos text[] not null default '{}',
  -- 'client' (depuis l'app) ou 'admin' (depuis l'admin web)
  add column if not exists litige_ouvert_par text,
  add column if not exists litige_date timestamptz;

-- ─── 2. Ouvrir un litige (client) ───────────────────────────────
-- SECURITY DEFINER car la RLS ne laisse le client modifier sa commande
-- que pour l'annuler. La fonction vérifie elle-même que :
--  - la commande appartient au client connecté ;
--  - elle n'est plus au statut 'nouvelle' (dans ce cas le client peut
--    simplement l'annuler) ;
--  - aucun litige n'est déjà ouvert ou résolu sur cette commande.
create or replace function public.ouvrir_litige(
  p_order_id  uuid,
  p_motif     text,
  p_photos    text[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
begin
  if auth.uid() is null then
    raise exception 'non_connecte';
  end if;
  if p_motif is null or length(trim(p_motif)) < 5 then
    raise exception 'motif_trop_court';
  end if;
  if coalesce(array_length(p_photos, 1), 0) > 3 then
    raise exception 'trop_de_photos';
  end if;

  select * into v_order from public.orders where id = p_order_id for update;
  if not found or v_order.client_id <> auth.uid() then
    raise exception 'commande_introuvable';
  end if;
  if v_order.statut = 'nouvelle' then
    raise exception 'commande_pas_encore_acceptee';
  end if;
  if v_order.litige_statut is not null then
    raise exception 'litige_deja_ouvert';
  end if;

  -- Variable de transaction lue par proteger_colonnes_admin() : autorise
  -- CETTE mise à jour des colonnes litige_* (sinon réservées aux admins).
  perform set_config('commerchaiti.litige_client', p_order_id::text, true);

  update public.orders
  set litige_statut     = 'ouvert',
      litige_motif      = trim(p_motif),
      litige_resolution = null,
      litige_photos     = coalesce(p_photos, '{}'),
      litige_ouvert_par = 'client',
      litige_date       = now()
  where id = p_order_id;

  perform set_config('commerchaiti.litige_client', '', true);
end;
$$;

revoke execute on function public.ouvrir_litige(uuid, text, text[]) from public, anon;
grant execute on function public.ouvrir_litige(uuid, text, text[]) to authenticated;

-- ─── 3. Colonnes réservées aux admins : exception pour ouvrir_litige ─
-- Même fonction que dans migration_admin_moderation.sql, avec une seule
-- différence : la mise à jour faite par ouvrir_litige() est autorisée
-- (et seulement pour la commande qu'elle traite). Un client ne peut pas
-- poser cette variable lui-même : l'API Supabase n'expose que les
-- fonctions du schéma public, pas set_config().
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
    if (new.litige_statut is distinct from old.litige_statut
        or new.litige_motif is distinct from old.litige_motif
        or new.litige_resolution is distinct from old.litige_resolution
        or new.litige_photos is distinct from old.litige_photos
        or new.litige_ouvert_par is distinct from old.litige_ouvert_par
        or new.litige_date is distinct from old.litige_date)
       and coalesce(current_setting('commerchaiti.litige_client', true), '')
           <> new.id::text then
      raise exception 'Gestion des litiges réservée aux admins';
    end if;
  end if;
  return new;
end;
$$;

-- ─── 4. Photos : bucket Storage « litiges » ─────────────────────
-- Lecture publique (comme les photos produits) pour que l'admin web
-- les affiche ; les noms de fichiers sont aléatoires. Chaque client
-- n'écrit que dans son propre dossier : litiges/<son uid>/...
insert into storage.buckets (id, name, public)
values ('litiges', 'litiges', true)
on conflict (id) do nothing;

drop policy if exists "litiges_upload_own_folder" on storage.objects;
create policy "litiges_upload_own_folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'litiges'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "litiges_read_public" on storage.objects;
create policy "litiges_read_public" on storage.objects
  for select using (bucket_id = 'litiges');
