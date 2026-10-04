#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# Sauvegarde de la base Supabase — checklist production (point 20)
#
# Crée 3 fichiers dans sauvegardes/AAAA-MM-JJ/ : rôles, structure,
# données. Nécessite la CLI Supabase (https://supabase.com/docs/guides/cli)
# et la chaîne de connexion de la base (Dashboard → Connect → Session
# pooler), à mettre dans la variable SUPABASE_DB_URL.
#
#   export SUPABASE_DB_URL='postgresql://postgres.xxxx:MOTDEPASSE@aws-0-us-west-1.pooler.supabase.com:5432/postgres'
#   ./scripts/sauvegarde_supabase.sh
#
# Ne jamais mettre ces fichiers sur GitHub (données des clients) :
# le dossier sauvegardes/ est dans .gitignore.
# Restauration et vérification : voir docs/PRODUCTION.md, point 20.
# ════════════════════════════════════════════════════════════════
set -euo pipefail

: "${SUPABASE_DB_URL:?Définissez SUPABASE_DB_URL (voir en-tête du script)}"

dossier="sauvegardes/$(date +%F)"
mkdir -p "$dossier"

supabase db dump --db-url "$SUPABASE_DB_URL" -f "$dossier/roles.sql" --role-only
supabase db dump --db-url "$SUPABASE_DB_URL" -f "$dossier/schema.sql"
supabase db dump --db-url "$SUPABASE_DB_URL" -f "$dossier/data.sql" --use-copy --data-only

echo "Sauvegarde terminée dans $dossier :"
ls -lh "$dossier"
