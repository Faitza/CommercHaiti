-- ═══════════════════════════════════════════════════════════════════
-- Recherche par photo (comme sur Shein)
-- Path : supabase/migration_recherche_photo.sql
--
-- Chaque produit reçoit une « empreinte » de sa photo principale : un
-- vecteur de 1024 nombres calculé DANS l'app (modèle MobileNet V3 embarqué,
-- assets/models/recherche_photo.tflite). Deux photos qui se ressemblent
-- (forme, couleur, style) ont des empreintes proches. Quand un client
-- cherche avec une photo, l'app calcule l'empreinte de sa photo et la
-- fonction rechercher_produits_par_photo() renvoie les produits dont
-- l'empreinte est la plus proche.
--
-- Aucun service externe ni clé : pgvector est inclus gratuitement dans
-- Supabase.
--
-- Ordre de lancement : après migration_admin_moderation.sql (la recherche
-- respecte la lecture des produits définie par la modération).
-- ═══════════════════════════════════════════════════════════════════

create extension if not exists vector with schema extensions;

-- Table séparée (et non une colonne de products) : les écrans font
-- souvent select() sur products ; une colonne de 1024 nombres alourdirait
-- chaque chargement de catalogue.
create table if not exists public.product_embeddings (
  product_id  uuid primary key references public.products(id) on delete cascade,
  empreinte   extensions.vector(1024) not null,
  -- Photo à partir de laquelle l'empreinte a été calculée : si le vendeur
  -- change la photo principale, l'app sait qu'il faut recalculer.
  photo_url   text not null,
  updated_at  timestamptz not null default now()
);

create index if not exists idx_product_embeddings_empreinte
  on public.product_embeddings
  using hnsw (empreinte extensions.vector_cosine_ops);

alter table public.product_embeddings enable row level security;

-- Lecture : nécessaire à la recherche (y compris visiteurs sans compte).
-- Une empreinte ne révèle rien de plus que la photo publique du produit.
drop policy if exists "product_embeddings_select" on public.product_embeddings;
create policy "product_embeddings_select" on public.product_embeddings
  for select using (true);

-- Écriture : seulement le vendeur propriétaire de la boutique du produit
-- (empêche quiconque de fausser les résultats d'un autre vendeur).
drop policy if exists "product_embeddings_write_owner" on public.product_embeddings;
create policy "product_embeddings_write_owner" on public.product_embeddings
  for all
  using (
    exists (
      select 1 from public.products p
      join public.shops s on s.id = p.shop_id
      where p.id = product_id and s.proprietaire_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.products p
      join public.shops s on s.id = p.shop_id
      where p.id = product_id and s.proprietaire_id = auth.uid()
    )
  );

grant select on public.product_embeddings to anon, authenticated;
grant insert, update, delete on public.product_embeddings to authenticated;

-- Recherche : produits disponibles les plus ressemblants, du plus proche
-- au moins proche. SECURITY INVOKER : la lecture de products passe par
-- ses règles RLS, donc les produits masqués par l'admin ou les boutiques
-- bloquées n'apparaissent pas. p_seuil écarte les photos sans rapport
-- (similarité cosinus entre 0 et 1).
create or replace function public.rechercher_produits_par_photo(
  p_empreinte extensions.vector(1024),
  p_limite    integer default 40,
  p_seuil     double precision default 0.3
)
returns setof public.products
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select p.*
  from public.product_embeddings e
  join public.products p on p.id = e.product_id
  where p.disponible
    and 1 - (e.empreinte <=> p_empreinte) >= p_seuil
  order by e.empreinte <=> p_empreinte
  limit least(greatest(coalesce(p_limite, 40), 1), 100);
$$;

grant execute on function public.rechercher_produits_par_photo(
  extensions.vector, integer, double precision) to anon, authenticated;
