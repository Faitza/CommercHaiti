-- ════════════════════════════════════════════════════════════════
-- Vérification d'une restauration — checklist production (point 20)
--
-- À exécuter dans le SQL Editor du projet d'ORIGINE, puis dans celui du
-- projet de TEST restauré : les deux résultats doivent être identiques
-- (même nombre de lignes, même dernière date).
-- ════════════════════════════════════════════════════════════════
select 'users' as table_, count(*) as lignes, max(created_at) as derniere from public.users
union all select 'shops',       count(*), max(created_at) from public.shops
union all select 'products',    count(*), max(created_at) from public.products
union all select 'orders',      count(*), max(created_at) from public.orders
union all select 'order_items', count(*), null from public.order_items
union all select 'reviews',     count(*), max(created_at) from public.reviews
union all select 'favorites',   count(*), max(created_at) from public.favorites
union all select 'auth.users',  count(*), max(created_at) from auth.users
order by 1;
