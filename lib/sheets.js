// Synchronisation vers Google Sheets (miroir + stats).
// Non bloquant : si le webhook est absent ou en erreur, l'appli continue.
// Configuré via .env.local : SHEETS_WEBHOOK_URL + SHEETS_WEBHOOK_SECRET.

const URL = process.env.SHEETS_WEBHOOK_URL || "";
const SECRET = process.env.SHEETS_WEBHOOK_SECRET || "";

export function sheetsEnabled() {
  return /^https:\/\//.test(URL) && !URL.includes("colle_ton");
}

// Envoie l'état courant d'une candidature + l'événement qui vient de se produire.
// `app` = objet retourné par getApplication() (contient les libellés et l'arbre secteur/dir/pôle).
export async function syncApplication(app, event) {
  if (!sheetsEnabled() || !app) return;
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
    const timer = setTimeout(() => ctrl.abort(), 4000);
    await fetch(URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: ctrl.signal,
    });
    clearTimeout(timer);
  } catch (e) {
    // On n'interrompt jamais le parcours candidat/RH pour un souci de sync.
    console.error("[sheets] synchronisation ignorée :", e.message);
  }
}
