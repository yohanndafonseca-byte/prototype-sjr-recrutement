// Synchronisation vers Google Sheets (miroir + stats).
// Non bloquant : si le webhook est absent ou en erreur, l'appli continue.

// URL et secret du webhook Google Sheets : UNIQUEMENT via variables d'environnement
// (SHEETS_WEBHOOK_URL / SHEETS_WEBHOOK_SECRET sur Vercel). Aucune valeur en dur ici.
const WEBHOOK_URL = process.env.SHEETS_WEBHOOK_URL || "";
const SECRET = process.env.SHEETS_WEBHOOK_SECRET || "";

export function sheetsEnabled() {
  return /^https:\/\//.test(WEBHOOK_URL);
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
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 10000);

    const response = await fetch(WEBHOOK_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: ctrl.signal,
    });

    clearTimeout(timer);

    if (!response.ok) {
      console.error("[sheets] Google Sheets a refusé la requête (HTTP " + response.status + ")");
    }
  } catch (e) {
    console.error("[sheets] Erreur de synchronisation :", e.message);
  }
} 
