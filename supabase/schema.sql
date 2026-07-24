-- ════════════════════════════════════════════════════════════════
-- CommercHaiti — Schéma Supabase (Postgres)
-- Traduction du modèle Firestore du cahier des charges (section 10)
-- vers des tables Postgres, en snake_case, tel qu'attendu par
-- lib/models/*.dart et lib/services/database_service.dart.
--
-- À exécuter dans Supabase Dashboard → SQL Editor, une seule fois
-- (dans l'ordre : schema.sql puis functions.sql).
-- ════════════════════════════════════════════════════════════════

-- ────────────────────────────────
-- USERS — profil + rôle (1-1 avec auth.users)
-- ────────────────────────────────
create table if not exists public.users (
  id          uuid primary key references auth.users(id) on delete cascade,
  nom         text not null,
  telephone   text not null,
  email       text not null,
  role        text not null check (role in ('seller', 'customer')),
  adresse     text,
  shop_code   text,
  created_at  timestamptz not null default now()
);

-- ────────────────────────────────
-- SHOPS — boutique du vendeur
-- ────────────────────────────────
create table if not exists public.shops (
  id                uuid primary key default gen_random_uuid(),
  proprietaire_id   uuid not null references auth.users(id) on delete cascade,
  nom               text not null,
  description       text not null default '',
  logo_url          text,
  shop_code         text not null unique,
  zones_livraison   jsonb not null default '[]'::jsonb,
  rating            numeric(2,1) not null default 0.0,
  total_avis        integer not null default 0,
  is_open           boolean not null default true,
  created_at        timestamptz not null default now()
);

create index if not exists idx_shops_proprietaire on public.shops(proprietaire_id);

-- ────────────────────────────────
-- PRODUCTS — catalogue (sous-collection Firestore → table à part avec shop_id)
-- ────────────────────────────────
create table if not exists public.products (
  id                uuid primary key default gen_random_uuid(),
  shop_id           uuid not null references public.shops(id) on delete cascade,
  nom               text not null,
  prix              numeric(10,2) not null,
  prix_promo        numeric(10,2),
  photos            text[] not null default '{}',
  stock             integer not null default 0,
  categorie         text not null,
  sous_categorie    text not null default '',
  couleurs          text[] not null default '{}',
  tailles           text[] not null default '{}',
  disponible        boolean not null default true,
  total_commandes   integer not null default 0,
  created_at        timestamptz not null default now()
);

create index if not exists idx_products_shop on public.products(shop_id);
create index if not exists idx_products_categorie on public.products(categorie, sous_categorie);
create index if not exists idx_products_total_commandes on public.products(total_commandes desc);

-- ────────────────────────────────
-- ORDERS — commandes
-- ────────────────────────────────
create table if not exists public.orders (
  id                  uuid primary key default gen_random_uuid(),
  client_id           uuid not null references auth.users(id),
  shop_id             uuid not null references public.shops(id),
  seller_id           uuid not null references auth.users(id),
  total               numeric(10,2) not null,
  statut              text not null default 'nouvelle'
                        check (statut in ('nouvelle','acceptee','preparation','livraison','livree','annulee')),
  adresse_livraison   text not null,
  zone                text not null,
  telephone_client    text not null,
  note_vendeur        text,
  receipt_url         text,
  created_at          timestamptz not null default now()
);

create index if not exists idx_orders_client on public.orders(client_id);
create index if not exists idx_orders_seller on public.orders(seller_id);

-- ────────────────────────────────
-- ORDER_ITEMS — articles d'une commande
-- ────────────────────────────────
create table if not exists public.order_items (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references public.orders(id) on delete cascade,
  product_id   uuid not null references public.products(id),
  nom          text not null,
  prix         numeric(10,2) not null,
  quantite     integer not null check (quantite > 0),
  couleur      text,
  taille       text
);

create index if not exists idx_order_items_order on public.order_items(order_id);

-- ────────────────────────────────
-- FAVORITES — boutiques favorites du client (menu hamburger client)
-- ────────────────────────────────
create table if not exists public.favorites (
  id            uuid primary key default gen_random_uuid(),
  client_id     uuid not null references auth.users(id) on delete cascade,
  shop_id       uuid not null references public.shops(id) on delete cascade,
  created_at    timestamptz not null default now(),
  unique (client_id, shop_id)
);

create index if not exists idx_favorites_client on public.favorites(client_id);

-- ────────────────────────────────
-- REVIEWS — avis clients sur les boutiques
-- ────────────────────────────────
create table if not exists public.reviews (
  id            uuid primary key default gen_random_uuid(),
  shop_id       uuid not null references public.shops(id) on delete cascade,
  client_id     uuid not null references auth.users(id),
  order_id      uuid not null references public.orders(id),
  note          integer not null check (note between 1 and 5),
  commentaire   text,
  created_at    timestamptz not null default now()
);

create index if not exists idx_reviews_shop on public.reviews(shop_id);

-- ────────────────────────────────
-- Trigger : recalcule shops.rating / total_avis à chaque avis
-- (comportement documenté dans review_model.dart)
-- ────────────────────────────────
create or replace function public.update_shop_rating()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.shops s
  set rating     = coalesce((select avg(r.note)::numeric(2,1) from public.reviews r where r.shop_id = coalesce(new.shop_id, old.shop_id)), 0.0),
      total_avis = (select count(*) from public.reviews r where r.shop_id = coalesce(new.shop_id, old.shop_id))
  where s.id = coalesce(new.shop_id, old.shop_id);
  return null;
end;
$$;

drop trigger if exists trg_update_shop_rating on public.reviews;
create trigger trg_update_shop_rating
after insert or update or delete on public.reviews
for each row execute function public.update_shop_rating();

-- ────────────────────────────────
-- Realtime — nécessaire pour les .stream() dans order_provider.dart / shop_provider.dart
-- ────────────────────────────────
alter publication supabase_realtime add table public.orders;
alter publication supabase_realtime add table public.products;
alter publication supabase_realtime add table public.shops;

-- ────────────────────────────────
-- Row Level Security (section 11 du cahier des charges)
-- ────────────────────────────────
alter table public.users enable row level security;
alter table public.shops enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.reviews enable row level security;
alter table public.favorites enable row level security;

-- USERS : chacun lit/modifie seulement son propre profil
create policy "users_select_own" on public.users
  for select using (auth.uid() = id);
create policy "users_insert_own" on public.users
  for insert with check (auth.uid() = id);
create policy "users_update_own" on public.users
  for update using (auth.uid() = id);

-- SHOPS : lecture publique (mode visiteur inclus), écriture par le propriétaire seulement
create policy "shops_select_public" on public.shops
  for select using (true);
create policy "shops_insert_owner" on public.shops
  for insert with check (auth.uid() = proprietaire_id);
create policy "shops_update_owner" on public.shops
  for update using (auth.uid() = proprietaire_id);

-- PRODUCTS : lecture publique (catalogue consultable sans compte — BF-010),
-- écriture réservée au vendeur propriétaire de la boutique
create policy "products_select_public" on public.products
  for select using (true);
create policy "products_write_owner" on public.products
  for insert with check (
    exists (select 1 from public.shops s where s.id = shop_id and s.proprietaire_id = auth.uid())
  );
create policy "products_update_owner" on public.products
  for update using (
    exists (select 1 from public.shops s where s.id = shop_id and s.proprietaire_id = auth.uid())
  );
create policy "products_delete_owner" on public.products
  for delete using (
    exists (select 1 from public.shops s where s.id = shop_id and s.proprietaire_id = auth.uid())
  );

-- ORDERS : le client et le vendeur concernés seulement (section 11.1)
create policy "orders_select_participants" on public.orders
  for select using (auth.uid() = client_id or auth.uid() = seller_id);
-- Création directe désactivée : passe uniquement par la fonction create_order_atomic()
-- (SECURITY DEFINER, voir functions.sql) qui contourne RLS de façon contrôlée.
-- Le vendeur fait progresser le statut ; le client peut seulement annuler (nouvelle → annulee, BF-029b)
create policy "orders_update_seller" on public.orders
  for update using (auth.uid() = seller_id);
create policy "orders_cancel_client" on public.orders
  for update using (auth.uid() = client_id and statut = 'nouvelle')
  with check (auth.uid() = client_id and statut = 'annulee');

-- ORDER_ITEMS : visibles seulement via une commande accessible
create policy "order_items_select_participants" on public.order_items
  for select using (
    exists (
      select 1 from public.orders o
      where o.id = order_id and (auth.uid() = o.client_id or auth.uid() = o.seller_id)
    )
  );
-- Insertion uniquement via create_order_atomic() (SECURITY DEFINER)

-- REVIEWS : lecture publique, écriture par le client auteur de la commande livrée
create policy "reviews_select_public" on public.reviews
  for select using (true);
create policy "reviews_insert_client" on public.reviews
  for insert with check (auth.uid() = client_id);

-- FAVORITES : chaque client gère uniquement ses propres favoris
create policy "favorites_select_own" on public.favorites
  for select using (auth.uid() = client_id);
create policy "favorites_insert_own" on public.favorites
  for insert with check (auth.uid() = client_id);
create policy "favorites_delete_own" on public.favorites
  for delete using (auth.uid() = client_id);
