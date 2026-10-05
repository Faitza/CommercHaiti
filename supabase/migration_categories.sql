-- ════════════════════════════════════════════════════════════════
-- Migration — catégories vendues par boutique (feature/categories)
-- À exécuter UNE fois dans Supabase → SQL Editor, AVANT de déployer
-- la nouvelle version de l'app (sinon la création / modification de
-- boutique échoue : colonne `categories` inconnue).
-- ════════════════════════════════════════════════════════════════

alter table public.shops
  add column if not exists categories text[] not null default '{}';

-- Les boutiques existantes ont une liste vide : l'app leur propose alors
-- toutes les catégories à l'ajout d'un produit, et le vendeur devra en
-- cocher au moins une la prochaine fois qu'il modifie sa boutique.
