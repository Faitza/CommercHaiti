# Notifications — mise en place

Ce qui marche après chaque étape :

| Étape | Résultat |
|---|---|
| 1. Migration SQL | Notifications visibles **dans l'app** (cloche + écran Notifications) |
| 2 à 5. Firebase + Edge Function + Webhook | Notifications **push** sur le téléphone, même app fermée |

L'app compile et fonctionne sans Firebase : tant que les étapes 2 à 5 ne
sont pas faites, il n'y a simplement pas de push.

## Quand une notification est créée

| Événement | Qui reçoit | Préférence (Paramètres) |
|---|---|---|
| Nouvelle commande | le vendeur | — |
| Statut de commande change (acceptée, en préparation, en route, livrée, annulée) | le client | « Suivi de commande » |
| Le client annule sa commande | le vendeur | — |
| Un vendeur ajoute un produit disponible | les clients qui ont cette boutique en **favori** | « Nouveaux produits » |

Un produit masqué par l'admin ou une boutique pas encore approuvée
(migration_admin_moderation.sql) ne déclenche pas de notification.

## 1. Migration SQL

Supabase → SQL Editor → coller et exécuter
`supabase/migration_notifications.sql` (après schema.sql et functions.sql).
Le fichier peut être relancé sans erreur.

## 2. Projet Firebase + google-services.json

1. https://console.firebase.google.com → **Ajouter un projet** (Google
   Analytics n'est pas nécessaire).
2. Dans le projet : **Ajouter une application → Android**.
   Nom du package : `com.example.commerchaiti` (doit être identique à
   `applicationId` dans `android/app/build.gradle.kts`).
3. Télécharger **google-services.json** et le placer dans
   `android/app/google-services.json`.
   Ce fichier n'est **pas** envoyé sur GitHub (`.gitignore`) : chaque
   personne qui compile l'app doit l'avoir en local.

## 3. Clé de compte de service → secret Supabase

1. Console Firebase → ⚙️ **Paramètres du projet → Comptes de service →
   Générer une nouvelle clé privée**. Un fichier JSON est téléchargé.
2. Supabase → **Edge Functions → Secrets → Add new secret** :
   - Nom : `FIREBASE_SERVICE_ACCOUNT`
   - Valeur : tout le contenu du fichier JSON.

Cette clé est secrète : ne jamais la mettre dans le code ni sur GitHub.

## 4. Déployer l'Edge Function

Avec la CLI Supabase, à la racine du projet :

```bash
supabase functions deploy send-push
```

Ou sans CLI : Supabase → **Edge Functions → Deploy a new function → Via
Editor**, nom `send-push`, coller le contenu de
`supabase/functions/send-push/index.ts`, puis **Deploy**.

## 5. Database Webhook

Supabase → **Database → Webhooks → Create a new hook** :

- Name : `send_push`
- Table : `notifications`
- Events : **Insert** seulement
- Type : **Supabase Edge Functions** → `send-push`, méthode `POST`
- HTTP Headers : cliquer **Add auth header with service key**

## Tester

1. Installer l'app (avec google-services.json) sur un téléphone, se
   connecter avec un compte client et accepter les notifications.
2. Vérifier qu'une ligne apparaît dans la table `device_tokens`.
3. Avec un compte vendeur, changer le statut d'une commande de ce client :
   le téléphone du client reçoit la notification.
4. En cas de problème : Supabase → Edge Functions → `send-push` → **Logs**.

## iOS

Le code est prêt, mais le push iOS demande en plus un compte Apple
Developer, une clé APNs à téléverser dans Firebase et
`GoogleService-Info.plist` dans `ios/Runner/`. Non fait pour l'instant.
