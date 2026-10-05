# Checklist production — CommercHaiti

État des 20 points pour l'app mobile (Flutter + Supabase), après la PR
« Checklist production ». Légende : ✅ fait dans le code · 🟡 en partie ·
👤 à faire par toi dans tes comptes (étapes plus bas).

| #  | Point | État | Où |
|----|-------|------|----|
| 01 | Limiter les requêtes par visiteur | ✅ + 👤 | `verifier_limite()` dans `supabase/migration_production.sql` (commandes 5/min et 50/jour, avis 10/h, produits 60/h, boutiques 3/jour, favoris 60/min). Connexion / inscription : réglage Supabase (étape A). |
| 02 | Plafonner les appels d'API | ✅ | Un seul abonnement temps réel par liste (avant : un de plus à chaque visite d'écran), articles des commandes en 1 requête au lieu d'1 par commande, recherche lancée 400 ms après la dernière lettre, flux produits du vendeur créé une seule fois. |
| 03 | Plafonner les dépenses chez les fournisseurs | 👤 | Étape B. |
| 04 | Message quand ça plante | ✅ | `lib/services/erreur_service.dart` : message « Oups… » + encadré lisible à la place de l'écran gris. |
| 05 | Chargement au lieu d'écran blanc | ✅ | `lib/widgets/etat_widgets.dart`, utilisé sur l'accueil, les commandes, le suivi, la boutique, le catalogue… |
| 06 | Cas « rien à afficher » | ✅ | Messages vides sur l'accueil, la recherche vendeur, la boutique, le suivi (commande introuvable). |
| 07 | Requêtes qui échouent | ✅ | Message clair + bouton « Réessayer » au lieu d'une liste vide. |
| 08 | API qui ne répondent pas | ✅ | `TimeoutHttpClient` : toute requête Supabase abandonnée après 20 s (90 s pour un envoi de photo). |
| 09 | Double clic sur « envoyer » | ✅ | Garde au début de chaque envoi (commande, produit, boutique, avis, profil, connexion, statut de commande, annulation). |
| 10 | Double paiement | ✅ | Clé unique par commande : un 2e envoi renvoie la même commande. N° de transaction MonCash unique (actif quand la PR MonCash est passée). |
| 11 | Charger seulement ce qu'on affiche | 🟡 | Pagination + listes limitées. Les requêtes lisent encore toutes les colonnes (`select()`), car les modèles Dart en ont besoin ; les tables sont petites. |
| 12 | Index pour les recherches | ✅ | 16 index (recherche par nom, catalogue, commandes, avis…) dans la migration. |
| 13 | Longues listes en pages | 🟡 | Catalogue et sous-catégories : pages de 30 au défilement. Avis vendeur : 20 + « Charger plus ». Les commandes (temps réel) et la fiche boutique restent en un bloc (voir « Limites connues »). |
| 14 | Compresser les fichiers | ✅ | Photo réduite au choix (1600 px) puis compressée (600 px, JPEG 85, recompressée à 60 si besoin). |
| 15 | Limiter le poids des fichiers | ✅ | App : refus au-delà de 15 Mo avant compression et de 2 Mo après. Serveur : buckets limités à 2 Mo, images seulement. |
| 16 | Garder en mémoire ce qui ne change pas | ✅ | Images en cache sur le téléphone (`cached_network_image`). |
| 17 | Être alerté si le site tombe | 👤 | Edge Function `health` fournie ; alerte à créer (étape C). |
| 18 | Trace de chaque erreur | ✅ | Table `app_errors` (90 jours). Requêtes de lecture plus bas. |
| 19 | Tester avec plusieurs visiteurs | 👤 | Script `loadtest/k6_catalogue.js` (étape D). |
| 20 | Vérifier que la sauvegarde se restaure | 👤 | `scripts/sauvegarde_supabase.sh` + `scripts/verifier_restauration.sql` (étape E). |

## Ordre de mise en route

1. Exécuter `supabase/migration_production.sql` dans Supabase → SQL
   Editor, **avant** de publier la nouvelle version de l'app (l'app reste
   compatible avec l'ancienne base, mais la protection anti-double
   commande n'est active qu'après la migration). Si `migration_moncash.sql`
   passe plus tard, relancer `migration_production.sql` après elle.
2. `flutter pub get` (nouvelle dépendance : `cached_network_image`).
3. Faire les étapes A à E ci-dessous.

> ⚠ Le projet Supabase est actuellement **en pause** (statut INACTIVE).
> Sur l'offre gratuite, un projet sans activité pendant 7 jours est mis
> en pause : l'app ne marche plus jusqu'à ce que tu cliques « Restore »
> dans le Dashboard. Pour une app en production, l'offre Pro évite ça et
> ajoute les sauvegardes quotidiennes (étape E).

## A. Limites de connexion / inscription (point 01)

Supabase Dashboard → **Authentication → Rate Limits**. Valeurs conseillées :
- Connexions et inscriptions : 30 par 5 minutes par adresse IP.
- E-mails envoyés (confirmation, mot de passe oublié) : laisser la valeur
  par défaut si tu utilises le serveur e-mail de Supabase.

## B. Plafond de dépenses (point 03)

- **Supabase** : Dashboard → Organization → **Billing → Cost Control** :
  laisser **Spend Cap activé** (offre Pro). Le projet ne pourra pas
  dépasser le prix de l'offre ; s'il atteint une limite, il est ralenti
  au lieu de te facturer plus.
- **Firebase** (notifications push, PR notifications) : rester sur
  l'offre **Spark** (gratuite, sans carte bancaire) — l'envoi de
  notifications FCM est gratuit et ne demande pas l'offre Blaze. Si un
  jour tu passes à Blaze : console Google Cloud → **Billing → Budgets &
  alerts** → budget de 5 $ avec alertes à 50 %, 90 %, 100 %.
- **Vercel** (admin web) : l'offre **Hobby** ne facture rien. Sur Pro :
  Settings → **Billing → Spend Management**, montant maximum + « Pause
  projects » coché.

## C. Alerte si le site tombe (point 17)

1. Déployer la fonction de santé (une fois) :
   `supabase functions deploy health --no-verify-jwt`
2. Créer un compte gratuit sur **UptimeRobot** (uptimerobot.com) ou
   **Better Stack**.
3. Ajouter 2 moniteurs HTTP(S), vérification toutes les 5 minutes :
   - `https://<ton-projet>.supabase.co/functions/v1/health` (app mobile :
     répond 200 si la base répond, 503 sinon) ;
   - l'adresse Vercel de l'admin web.
4. Alerte par e-mail (et SMS / WhatsApp si proposé) vers ton adresse.
5. Tester : mettre en pause le projet Supabase de test, vérifier que
   l'alerte arrive.

## D. Test avec plusieurs visiteurs (point 19)

1. Installer **k6** : https://grafana.com/docs/k6/latest/set-up/install-k6/
2. De préférence sur une **copie** du projet (projet de test restauré à
   l'étape E), pas aux heures où de vrais clients utilisent l'app.
3. Lancer :
   ```
   k6 run -e SUPABASE_URL=https://xxxx.supabase.co \
          -e SUPABASE_ANON_KEY=<clé publishable> loadtest/k6_catalogue.js
   ```
4. Le test simule 50 visiteurs en même temps pendant 2 minutes. Il est
   **réussi** si k6 affiche des coches vertes pour `http_req_failed`
   (< 1 % d'erreurs) et `http_req_duration` (95 % des réponses en moins
   de 1,5 s). Sinon, m'envoyer le résumé affiché.

## E. Sauvegarde qui se restaure vraiment (point 20)

- **Offre Pro** : sauvegarde automatique chaque jour (Dashboard →
  Database → Backups). **Offre gratuite** : aucune sauvegarde
  automatique, il faut utiliser le script.

Une fois par mois (et avant chaque grosse migration) :
1. Installer la CLI Supabase et copier la chaîne de connexion
   (Dashboard → **Connect** → Session pooler).
2. Sauvegarder :
   ```
   export SUPABASE_DB_URL='postgresql://postgres.xxxx:MOTDEPASSE@...pooler.supabase.com:5432/postgres'
   ./scripts/sauvegarde_supabase.sh
   ```
3. Créer un **nouveau projet Supabase de test** (vide) et restaurer
   dedans (chaîne de connexion du projet de test) :
   ```
   psql --single-transaction --variable ON_ERROR_STOP=1 \
     --file sauvegardes/AAAA-MM-JJ/roles.sql \
     --file sauvegardes/AAAA-MM-JJ/schema.sql \
     --command 'SET session_replication_role = replica' \
     --file sauvegardes/AAAA-MM-JJ/data.sql \
     --dbname "$URL_PROJET_TEST"
   ```
4. Exécuter `scripts/verifier_restauration.sql` dans le SQL Editor des
   **deux** projets : les nombres de lignes doivent être identiques.
5. Garder les fichiers de sauvegarde hors de GitHub (Google Drive privé
   par exemple). Le dossier `sauvegardes/` est déjà ignoré par git.

## Lire le journal d'erreurs (point 18)

Supabase → SQL Editor :
```sql
-- Les 50 dernières erreurs
select created_at, plateforme, contexte, message
from public.app_errors order by created_at desc limit 50;

-- Les erreurs les plus fréquentes sur 7 jours
select message, count(*) as nb, max(created_at) as derniere
from public.app_errors
where created_at > now() - interval '7 days'
group by message order by nb desc limit 20;
```

## Limites connues

- Les listes de commandes (client et vendeur) restent chargées en entier
  car elles sont en temps réel et le chiffre d'affaires du tableau de bord
  vendeur est calculé à partir d'elles. Les découper demande de calculer
  le chiffre d'affaires côté serveur : à faire si un vendeur dépasse
  quelques centaines de commandes.
- La fiche boutique charge tous les produits disponibles de la boutique
  (nécessaire pour la liste des catégories).
- La recherche dans « Tous les produits » filtre les produits déjà
  chargés ; la recherche complète est celle de l'accueil.
- Les visiteurs non connectés qui ne font que lire (catalogue) ne sont pas
  limités par la base : Supabase ne propose pas de limite par adresse IP
  sur la lecture. Les pages de 30 et le plafond « Max rows » de l'API
  (Settings → API, 1000 par défaut) limitent ce qu'une requête renvoie.
