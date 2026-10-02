// Synchronisation vers Google Sheets (miroir + stats).
// Non bloquant : si le webhook est absent ou en erreur, l'appli continue.

const REPLI_URL = "https://script.google.com/macros/s/AKfycbyEpVu0s483UWpc_MIYf3PKYZwYeY4HpJ0-FnRTpqtVCrt8qW3JrSsrf37RaROfixxd/exec";
const REPLI_SECRET = "MAIRIErecrutement2026!";

const URL = process.env.SHEETS_WEBHOOK_URL || REPLI_URL;
const SECRET = process.env.SHEETS_WEBHOOK_SECRET || REPLI_SECRET;

export function sheetsEnabled() {
  return /^https:\/\//.test(URL) && !URL.includes("COLLE_ICI") && !URL.includes("colle_ton");
}

export async function syncApplication(app, event) {
  if (!sheetsEnabled() || !app) {
    console.log("[sheets] synchronisation désactivée");
    return;
  }

  const payload = {
    secret: SECRET,
    ref: app.public_ref,
    received_at: app.created_at,
    updated_at: new Date().toISOString(),
    status: app.status,
    status_label: app.status_label || app.status,
    civility: app.civility || "",
    last_name: app.last_name || "",
    first_name: app.first_name || "",
    email: app.email || "",
    phone: app.phone || "",
    city: app.city || "",
    offer_title: app.offer_title || "",
    offer_ref: app.offer_reference || "",
    sector: app.sector_name || "",
    direction: app.direction_name || "",
    pole: app.pole_name || "",
    event: event || "",
  };

  try {
    console.log("[sheets] Envoi vers Google Sheets...");
    console.log("[sheets] URL configurée :", URL);
    console.log("[sheets] Référence :", app.public_ref);

    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 10000);

    const response = await fetch(URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
      signal: ctrl.signal,
    });

    clearTimeout(timer);

    const text = await response.text();

    console.log("[sheets] HTTP :", response.status);
    console.log("[sheets] Réponse :", text);

    if (!response.ok) {
      console.error("[sheets] Google Sheets a refusé la requête");
    }
  } catch (e) {
    console.error("[sheets] ERREUR :", e.message);
  }
} 