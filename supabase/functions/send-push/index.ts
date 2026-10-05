// ════════════════════════════════════════════════════════════════
// CommercHaiti — Edge Function "send-push"
//
// Appelée par un Database Webhook Supabase sur INSERT dans
// public.notifications (voir supabase/NOTIFICATIONS.md). Elle envoie la
// notification en push (Firebase Cloud Messaging, API HTTP v1) à tous les
// téléphones enregistrés de l'utilisateur (table public.device_tokens).
//
// Secret requis (Supabase → Edge Functions → Secrets) :
//   FIREBASE_SERVICE_ACCOUNT = contenu JSON complet de la clé de compte de
//   service Firebase (Console Firebase → Paramètres du projet → Comptes de
//   service → Générer une nouvelle clé privée).
// SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY sont fournis automatiquement.
//
// Sécurité : le contenu reçu n'est pas utilisé tel quel. On relit la
// notification en base à partir de son id ; un appel forgé ne peut donc
// que renvoyer une notification qui existe déjà, à son vrai destinataire.
// ════════════════════════════════════════════════════════════════

import { createClient } from "npm:@supabase/supabase-js@2";

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

let cachedToken: { value: string; expiresAt: number } | null = null;

function base64url(input: ArrayBuffer | string): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : new Uint8Array(input);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// Échange une assertion JWT signée (RS256) contre un jeton OAuth Google
// valable 1 h, gardé en cache tant que l'instance de la fonction vit.
async function getAccessToken(sa: ServiceAccount): Promise<string> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) {
    return cachedToken.value;
  }
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key
    .replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  const assertion = `${header}.${claims}.${base64url(signature)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!res.ok) throw new Error(`oauth ${res.status}: ${await res.text()}`);
  const json = await res.json();
  cachedToken = {
    value: json.access_token,
    expiresAt: Date.now() + json.expires_in * 1000,
  };
  return cachedToken.value;
}

Deno.serve(async (req) => {
  try {
    const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!raw) {
      return new Response("FIREBASE_SERVICE_ACCOUNT manquant", { status: 500 });
    }
    const sa = JSON.parse(raw) as ServiceAccount;

    const payload = await req.json();
    const id = payload?.record?.id;
    if (!id) return new Response("record.id manquant", { status: 400 });

    const { data: notif, error } = await supabase
      .from("notifications")
      .select("id, user_id, type, titre, message, data")
      .eq("id", id)
      .maybeSingle();
    if (error) throw error;
    if (!notif) return new Response("notification introuvable", { status: 404 });

    const { data: tokens, error: tokErr } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", notif.user_id);
    if (tokErr) throw tokErr;
    if (!tokens || tokens.length === 0) {
      return Response.json({ envoyes: 0, raison: "aucun téléphone" });
    }

    // FCM exige des valeurs string dans `data`.
    const data: Record<string, string> = {
      type: notif.type,
      notification_id: notif.id,
    };
    for (const [k, v] of Object.entries(notif.data ?? {})) {
      if (v !== null && v !== undefined) data[k] = String(v);
    }

    const accessToken = await getAccessToken(sa);
    const url =
      `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    let envoyes = 0;
    const invalides: string[] = [];
    await Promise.all(tokens.map(async ({ token }) => {
      const res = await fetch(url, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: notif.titre, body: notif.message },
            data,
            android: { priority: "high" },
          },
        }),
      });
      if (res.ok) {
        envoyes++;
        return;
      }
      const body = await res.text();
      // Jeton expiré ou app désinstallée : on le supprime.
      if (
        res.status === 404 || body.includes("UNREGISTERED") ||
        (body.includes("INVALID_ARGUMENT") && body.includes("registration"))
      ) {
        invalides.push(token);
      } else {
        console.error(`FCM ${res.status}: ${body}`);
      }
    }));

    if (invalides.length > 0) {
      await supabase.from("device_tokens").delete().in("token", invalides);
    }

    return Response.json({ envoyes, supprimes: invalides.length });
  } catch (e) {
    console.error(e);
    return new Response(String(e), { status: 500 });
  }
});
