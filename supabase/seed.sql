-- ════════════════════════════════════════════════════════════════
-- CommercHaiti — Données de démonstration
--
-- Ce script cible directement votre boutique de test réelle
-- "Marche Jeudi" (trouvée automatiquement via l'API publique —
-- id ci-dessous) et lui ajoute des produits Fruits/Légumes/Épices
-- (jan maket la montre) SANS toucher aux produits que vous avez
-- déjà créés (Roble fleurie, Tocquet).
--
-- Le compte Client de démo (client.demo@commerchaiti.test / Demo2026!)
-- est déjà créé et son UID déjà renseigné ci-dessous — rien à modifier,
-- exécutez tel quel.
-- ════════════════════════════════════════════════════════════════

do $$
declare
  v_shop_id      uuid := '220d86f1-cc71-466e-b3c1-43db3298e3dd'; -- Marche Jeudi
  v_vendeur_id   uuid := '03bd40e9-5bbf-4e11-8c1e-ad57115beb78'; -- propriétaire
  v_client_id_txt text := 'c77b9953-8d6a-4ac6-986b-364da9e1387e'; -- client.demo@commerchaiti.test
  v_client_id    uuid;
  v_avocat_id    uuid;
  v_mangue_id    uuid;
  v_order_id     uuid;
begin
  null; -- kenbe block la valid pandan tout rès la an komantè anba a

  -- ── Pwodui demo yo (Fruits/Légumes/Épices) — an komantè paske yo deja
  --    egziste nan baz done a. Si w re-egzekite fichye sa a san dekomante
  --    yo, okenn nouvo pwodui pa pral kreye (zewo doub).
  -- insert into public.products (shop_id, nom, prix, prix_promo, photos, stock, categorie, sous_categorie, disponible, total_commandes)
  -- values (v_shop_id, 'Avocat frais', 75, 60, '{}', 20, 'Fruits', 'Avocats', true, 142)
  -- returning id into v_avocat_id;

  -- insert into public.products (shop_id, nom, prix, prix_promo, photos, stock, categorie, sous_categorie, disponible, total_commandes)
  -- values (v_shop_id, 'Mangues fraîches', 120, null, '{}', 15, 'Fruits', 'Mangues', true, 98)
  -- returning id into v_mangue_id;

  -- insert into public.products (shop_id, nom, prix, prix_promo, photos, stock, categorie, sous_categorie, disponible, total_commandes) values
  --   (v_shop_id, 'Citron vert',   50,  null, '{}', 30, 'Fruits',  'Agrumes',   true, 40),
  --   (v_shop_id, 'Ananas',        90,  null, '{}', 12, 'Fruits',  'Tropicaux', true, 22),
  --   (v_shop_id, 'Chou vert',     45,  null, '{}', 25, 'Légumes', 'Choux',     true, 18),
  --   (v_shop_id, 'Carotte',       35,  null, '{}', 40, 'Légumes', 'Racines',   true, 27),
  --   (v_shop_id, 'Tomate',        55,  40,   '{}', 3,  'Légumes', 'Tomates',   true, 61),
  --   (v_shop_id, 'Piment bouc',   30,  null, '{}', 50, 'Épices',  'Piments',   true, 76),
  --   (v_shop_id, 'Thym frais',    25,  null, '{}', 0,  'Épices',  'Herbes',    false, 5),
  --   (v_shop_id, 'Gingembre',     40,  null, '{}', 8,  'Épices',  'Racines',   true, 3);

  -- Commande de démonstration — an komantè tou paske li depann de
  -- v_avocat_id/v_mangue_id ki soti nan insert yo pi wo a (san yo, li pral
  -- kraze paske product_id pa ka null).
  -- if v_client_id_txt != 'CLIENT_UID_ICI' then
  --   v_client_id := v_client_id_txt::uuid;
  --   insert into public.orders (
  --     client_id, shop_id, seller_id, total, statut,
  --     adresse_livraison, zone, telephone_client
  --   ) values (
  --     v_client_id, v_shop_id, v_vendeur_id, 240, 'nouvelle',
  --     'Rue Borno, Les Cayes', 'Cayes Centre', '+509 3712 4856'
  --   ) returning id into v_order_id;

  --   insert into public.order_items (order_id, product_id, nom, prix, quantite)
  --   values
  --     (v_order_id, v_avocat_id, 'Avocat frais', 60, 2),
  --     (v_order_id, v_mangue_id, 'Mangues fraîches', 120, 1);
  -- end if;
end $$;
