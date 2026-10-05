-- ════════════════════════════════════════════════════════════════
-- Migration — horaire automatique des boutiques (feature/shop-hours)
-- À exécuter UNE fois dans Supabase → SQL Editor, AVANT de déployer
-- la nouvelle version de l'app.
-- ════════════════════════════════════════════════════════════════

alter table public.shops
  add column if not exists horaire_ouverture time,
  add column if not exists horaire_fermeture time,
  add column if not exists jours_ouverture   text[] not null default '{}',
  -- true = "Ouvrir maintenant", false = "Fermer maintenant",
  -- null = statut calculé automatiquement selon l'horaire.
  add column if not exists is_open_manuel    boolean;

-- Les boutiques "suspendues" avec l'ancien interrupteur (is_open = false)
-- deviennent "fermées manuellement" : elles restent fermées, mais le
-- vendeur peut désormais les rouvrir avec "Ouvrir maintenant" ou
-- "Revenir à l'horaire automatique".
update public.shops
   set is_open_manuel = false,
       is_open = true
 where is_open = false;
