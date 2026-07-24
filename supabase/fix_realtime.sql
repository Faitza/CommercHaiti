-- Active Realtime sur orders/products/shops SANS erreur si déjà actif
-- (ALTER PUBLICATION ... ADD TABLE échoue si la table est déjà membre —
-- ce bloc vérifie avant d'ajouter).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'orders'
  ) then
    alter publication supabase_realtime add table public.orders;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'products'
  ) then
    alter publication supabase_realtime add table public.products;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'shops'
  ) then
    alter publication supabase_realtime add table public.shops;
  end if;
end $$;

-- Vérification — devrait afficher orders, products, shops
select tablename from pg_publication_tables where pubname = 'supabase_realtime';
