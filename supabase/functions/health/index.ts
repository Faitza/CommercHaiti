// ════════════════════════════════════════════════════════════════
// Edge Function « health » — checklist production (point 17)
//
// Adresse à surveiller avec un service d'alerte (UptimeRobot, Better
// Stack…) : https://<projet>.supabase.co/functions/v1/health
// Répond 200 si la base répond, 503 sinon. Voir docs/PRODUCTION.md.
//
// Déploiement (une fois) :
//   supabase functions deploy health --no-verify-jwt
// (--no-verify-jwt : le service de surveillance n'a pas de compte.)
// ════════════════════════════════════════════════════════════════

Deno.serve(async () => {
  const debut = Date.now();
  try {
    const url = Deno.env.get("SUPABASE_URL");
    const cle = Deno.env.get("SUPABASE_ANON_KEY");
    // Petite lecture publique (1 ligne, 1 colonne) : prouve que l'API et
    // la base répondent, sans rien exposer.
    const reponse = await fetch(`${url}/rest/v1/shops?select=id&limit=1`, {
      headers: { apikey: cle!, Authorization: `Bearer ${cle}` },
      signal: AbortSignal.timeout(8000),
    });
    if (!reponse.ok) throw new Error(`base: HTTP ${reponse.status}`);
    await reponse.body?.cancel();
    return Response.json({ ok: true, ms: Date.now() - debut });
  } catch (e) {
    return Response.json(
      { ok: false, erreur: String(e), ms: Date.now() - debut },
      { status: 503 },
    );
  }
});
