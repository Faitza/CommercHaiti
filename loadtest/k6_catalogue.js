// ════════════════════════════════════════════════════════════════
// Test de charge — checklist production (point 19)
// « teste avec plusieurs visiteurs en même temps »
//
// Simule des visiteurs qui ouvrent l'accueil, cherchent un produit et
// parcourent le catalogue page par page (les mêmes requêtes que l'app).
// Lecture seule : ne crée aucune commande ni aucun compte.
//
// Lancer (voir docs/PRODUCTION.md) :
//   k6 run -e SUPABASE_URL=https://xxxx.supabase.co \
//          -e SUPABASE_ANON_KEY=sb_publishable_xxx loadtest/k6_catalogue.js
//
// ⚠ À lancer de préférence sur une copie du projet (branche Supabase ou
// projet de test), pas aux heures où de vrais clients utilisent l'app.
// ════════════════════════════════════════════════════════════════
import http from "k6/http";
import { check, sleep } from "k6";

const URL = __ENV.SUPABASE_URL;
const CLE = __ENV.SUPABASE_ANON_KEY;
const entetes = { headers: { apikey: CLE, Authorization: `Bearer ${CLE}` } };

export const options = {
  // Monte à 50 visiteurs simultanés, reste 2 minutes, redescend.
  stages: [
    { duration: "1m", target: 50 },
    { duration: "2m", target: 50 },
    { duration: "30s", target: 0 },
  ],
  // Le test échoue si plus de 1 % d'erreurs ou si 95 % des requêtes ne
  // répondent pas en moins de 1,5 s.
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<1500"],
  },
};

const recherches = ["robe", "riz", "savon", "tel", "chaussure", "sac"];

export default function () {
  // Accueil : produits populaires + boutiques ouvertes.
  let r = http.get(
    `${URL}/rest/v1/products?select=*&disponible=eq.true&order=total_commandes.desc&limit=10`,
    entetes,
  );
  check(r, { "accueil produits 200": (x) => x.status === 200 });
  r = http.get(`${URL}/rest/v1/shops?select=*&is_open=eq.true&order=created_at.desc`, entetes);
  check(r, { "accueil boutiques 200": (x) => x.status === 200 });
  sleep(1);

  // Recherche.
  const mot = recherches[Math.floor(Math.random() * recherches.length)];
  r = http.get(
    `${URL}/rest/v1/products?select=*&nom=ilike.*${mot}*&disponible=eq.true&limit=20`,
    entetes,
  );
  check(r, { "recherche 200": (x) => x.status === 200 });
  sleep(1);

  // Catalogue, 2 pages de 30.
  for (const debut of [0, 30]) {
    r = http.get(
      `${URL}/rest/v1/products?select=*&disponible=eq.true&order=total_commandes.desc,id.asc&offset=${debut}&limit=30`,
      entetes,
    );
    check(r, { "catalogue 200": (x) => x.status === 200 });
    sleep(1);
  }
}
