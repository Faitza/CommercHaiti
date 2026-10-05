-- ════════════════════════════════════════════════════════════════
-- Migration — liste de livreurs par boutique (feature/livreurs)
--
-- Chaque vendeur enregistre ses livreurs (nom, téléphone). Quand il
-- prépare une commande, il choisit le livreur qui la porte : le client
-- voit alors le nom et le téléphone du livreur sur l'écran de suivi.
--
-- Les livreurs n'ont pas de compte dans l'app : le vendeur leur envoie
-- la commande par WhatsApp depuis le détail de la commande.
--
-- À exécuter UNE fois dans Supabase → SQL Editor (peut être relancé).
-- ════════════════════════════════════════════════════════════════

create table if not exists public.livreurs (
  id          uuid primary key default gen_random_uuid(),
  shop_id     uuid not null references public.shops(id) on delete cascade,
  nom         text not null check (length(trim(nom)) > 0),
  telephone   text not null check (length(trim(telephone)) > 0),
  actif       boolean not null default true,
  created_at  timestamptz not null default now()
);

create index if not exists idx_livreurs_shop on public.livreurs(shop_id);

alter table public.livreurs enable row level security;

-- Seul le propriétaire de la boutique voit et gère ses livreurs. Le
-- client ne lit jamais cette table : le nom et le téléphone du livreur
-- sont copiés sur la commande au moment de l'assignation.
drop policy if exists "livreurs_owner_all" on public.livreurs;
create policy "livreurs_owner_all" on public.livreurs
  for all
  using (exists (select 1 from public.shops s
                 where s.id = shop_id and s.proprietaire_id = auth.uid()))
  with check (exists (select 1 from public.shops s
                      where s.id = shop_id and s.proprietaire_id = auth.uid()));

-- ─── Livreur assigné à une commande ─────────────────────────────
alter table public.orders
  add column if not exists livreur_id uuid references public.livreurs(id) on delete set null,
  add column if not exists livreur_nom text,
  add column if not exists livreur_telephone text;

-- Quand le vendeur change livreur_id : vérifie que ce livreur est bien
-- à la boutique de la commande, puis copie son nom et son téléphone
-- (lisibles par le client via la commande). livreur_id null = retiré.
create or replace function public.copier_livreur_commande()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_livreur public.livreurs%rowtype;
begin
  if new.livreur_id is not distinct from old.livreur_id then
    -- Empêche de modifier à la main le nom/téléphone copiés.
    new.livreur_nom := old.livreur_nom;
    new.livreur_telephone := old.livreur_telephone;
    return new;
  end if;

  if new.livreur_id is null then
    new.livreur_nom := null;
    new.livreur_telephone := null;
    return new;
  end if;

  select * into v_livreur from public.livreurs where id = new.livreur_id;
  if not found or v_livreur.shop_id <> new.shop_id then
    raise exception 'livreur_invalide';
  end if;

  new.livreur_nom := v_livreur.nom;
  new.livreur_telephone := v_livreur.telephone;
  return new;
end;
$$;

drop trigger if exists trg_copier_livreur_commande on public.orders;
create trigger trg_copier_livreur_commande
before update on public.orders
for each row execute function public.copier_livreur_commande();
