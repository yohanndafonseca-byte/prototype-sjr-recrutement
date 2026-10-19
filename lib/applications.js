import crypto from "crypto";
import { dbAll, dbGet, dbRun } from "./db.js";
import { getOffer, syncOffer } from "./offers.js";
import { APP_STATUS_LABEL, allowedTransitions, EDITABLE_STATUSES } from "./constants.js";
import { sendAccuseReception, sendReponsePositive, sendReponseNegative } from "./email.js";

export function publicRef() {
  const y = new Date().getFullYear();
  const r = crypto.randomBytes(3).toString("hex").toUpperCase();
  return `CAND-${y}-${r}`;
}

// Jeton privé non devinable pour le lien de modification candidat.
export function editToken() {
  return crypto.randomBytes(16).toString("hex");
}

// URL publique du site (sert à construire le lien de modification dans l'e-mail).
export function siteUrl() {
  return (process.env.SITE_URL || process.env.NEXT_PUBLIC_SITE_URL || "https://recrutement-sjr.vercel.app").replace(/\/+$/, "");
}
export function editUrlFor(token) {
  return `${siteUrl()}/ma-candidature/${token}`;
}

function todayISO() {
  return new Date().toISOString().slice(0, 10);
}
// Le candidat peut-il encore modifier sa candidature ?
export function isApplicationEditable(app) {
  if (!app) return false;
  if (!EDITABLE_STATUSES.includes(app.status)) return false;
  if (app.offer_deadline && String(app.offer_deadline) < todayISO()) return false;
  return true;
}

const APP_SELECT = `
  SELECT a.*, o.title AS offer_title, o.reference AS offer_reference,
    o.positions_total, o.deadline AS offer_deadline, o.contract_type AS offer_contract_type,
    o.location AS offer_location, o.status AS offer_status,
    o.diploma_label AS offer_diploma_label, o.diploma_required AS offer_diploma_required,
    s.name AS sector_name, d.name AS direction_name, p.name AS pole_name,
    (SELECT COUNT(*) FROM applications x WHERE x.offer_id=o.id AND x.status='recrute') AS positions_filled
  FROM applications a
  JOIN offers o ON o.id = a.offer_id
  LEFT JOIN sectors s ON s.id = o.sector_id
  LEFT JOIN directions d ON d.id = o.direction_id
  LEFT JOIN poles p ON p.id = o.pole_id
`;
const DOC_COLS = "id, application_id, kind, original_name, mime, size, created_at";

export async function addEvent(applicationId, type, message) {
  await dbRun("INSERT INTO events (application_id, type, message) VALUES (?,?,?)", [applicationId, type, message]);
}

export async function createApplication(offerId, data) {
  const offer = await getOffer(offerId);
  if (!offer) throw new Error("Offre introuvable");
  const ref = publicRef();
  const token = editToken();
  const info = await dbRun(`
    INSERT INTO applications (public_ref, offer_id, civility, last_name, first_name,
      address, postal_code, city, email, phone, consent_processing, consent_vivier, status, edit_token)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?, 'nouvelle', ?)`,
    [ref, offerId, data.civility || null, data.last_name || "", data.first_name || "",
     data.address || null, data.postal_code || null, data.city || null,
     data.email || null, data.phone || null,
     data.consent_processing ? 1 : 0, data.consent_vivier ? 1 : 0, token]);
  const id = info.lastInsertRowid;
  await addEvent(id, "creation", "Candidature reçue — statut initial : Nouvelle candidature.");
  const arSent = await sendAccuseReception({ to: data.email, firstName: data.first_name, offerTitle: offer.title, ref, editUrl: editUrlFor(token) });
  await addEvent(id, "email", arSent ? "Accusé de réception envoyé au candidat." : "Accusé de réception — e-mail non envoyé (service non configuré).");
  return { id, public_ref: ref, edit_token: token, offer };
}

// Récupère une candidature complète à partir de son jeton de modification.
export async function getByEditToken(token) {
  if (!token) return null;
  const row = await dbGet("SELECT id FROM applications WHERE edit_token = ?", [String(token)]);
  if (!row) return null;
  return getApplication(row.id);
}

// Met à jour les informations personnelles (modification par le candidat).
export async function updateApplicationFields(id, data) {
  await dbRun(`
    UPDATE applications SET civility=?, last_name=?, first_name=?, address=?,
      postal_code=?, city=?, email=?, phone=?, consent_vivier=?, updated_at=datetime('now')
    WHERE id=?`,
    [data.civility || null, data.last_name || "", data.first_name || "",
     data.address || null, data.postal_code || null, data.city || null,
     data.email || null, data.phone || null, data.consent_vivier ? 1 : 0, id]);
}

// Supprime une pièce — uniquement si elle appartient bien à la candidature.
export async function deleteDocumentOfApp(docId, applicationId) {
  await dbRun("DELETE FROM documents WHERE id=? AND application_id=?", [Number(docId), applicationId]);
}

// Les pièces sont stockées EN BASE (content = base64).
export async function saveDocument(app, kind, originalName, buffer, mime) {
  await dbRun(`
    INSERT INTO documents (application_id, kind, original_name, stored_path, content, mime, size)
    VALUES (?,?,?,?,?,?,?)`,
    [app.id, kind, originalName || kind, null, buffer.toString("base64"),
     mime || "application/octet-stream", buffer.length]);
}

export async function getApplication(id) {
  const app = await dbGet(APP_SELECT + " WHERE a.id = ?", [id]);
  if (!app) return null;
  app.positions_filled = Number(app.positions_filled) || 0;
  app.positions_remaining = Math.max(0, Number(app.positions_total) - app.positions_filled);
  app.documents = await dbAll(`SELECT ${DOC_COLS} FROM documents WHERE application_id=? ORDER BY id`, [id]);
  app.notes = await dbAll("SELECT * FROM notes WHERE application_id=? ORDER BY created_at DESC", [id]);
  app.events = await dbAll("SELECT * FROM events WHERE application_id=? ORDER BY created_at DESC, id DESC", [id]);
  app.status_label = APP_STATUS_LABEL[app.status];
  app.transitions = allowedTransitions(app.status);
  return app;
}

// Métadonnées seules (sans contenu) — pour l'affichage
export async function getDocument(docId) {
  return dbGet(`SELECT ${DOC_COLS} FROM documents WHERE id=?`, [docId]);
}
// Contenu binaire d'une pièce (téléchargement)
export async function getDocumentContent(docId) {
  const row = await dbGet("SELECT id, kind, original_name, mime, size, content FROM documents WHERE id=?", [docId]);
  if (!row) return null;
  row.buffer = row.content ? Buffer.from(row.content, "base64") : Buffer.alloc(0);
  return row;
}
// Toutes les pièces d'une candidature AVEC leur contenu (assemblage du dossier PDF)
export async function listDocumentsWithContent(applicationId) {
  const rows = await dbAll("SELECT id, kind, original_name, mime, size, content FROM documents WHERE application_id=? ORDER BY id", [applicationId]);
  return rows.map((d) => ({ ...d, buffer: d.content ? Buffer.from(d.content, "base64") : Buffer.alloc(0) }));
}

export async function listByOffer(offerId) {
  const rows = await dbAll(APP_SELECT + " WHERE a.offer_id=? ORDER BY a.created_at DESC", [offerId]);
  return rows.map((a) => ({ ...a, status_label: APP_STATUS_LABEL[a.status] }));
}

export async function listApplications({ status = null, statusIn = null, q = "" } = {}) {
  let rows = await dbAll(APP_SELECT + " ORDER BY a.created_at DESC");
  if (status) rows = rows.filter((a) => a.status === status);
  if (statusIn) rows = rows.filter((a) => statusIn.includes(a.status));
  const term = (q || "").trim().toLowerCase();
  if (term) rows = rows.filter((a) =>
    [a.first_name, a.last_name, a.offer_title, a.email, a.public_ref]
      .filter(Boolean).join(" ").toLowerCase().includes(term));
  return rows.map((a) => ({ ...a, status_label: APP_STATUS_LABEL[a.status] }));
}

export async function markOpened(id) {
  const app = await dbGet("SELECT status FROM applications WHERE id=?", [id]);
  if (app && app.status === "nouvelle") {
    await dbRun("UPDATE applications SET status='a_etudier', updated_at=datetime('now') WHERE id=?", [id]);
    await addEvent(id, "statut", "Candidature ouverte par la RH — Nouvelle candidature → À étudier.");
  }
}

export async function setStatus(id, newStatus) {
  const app = await dbGet("SELECT * FROM applications WHERE id=?", [id]);
  if (!app) throw new Error("Candidature introuvable");
  if (app.status === newStatus) return getApplication(id);
  if (!allowedTransitions(app.status).includes(newStatus)) {
    throw new Error(`Transition non autorisée : ${app.status} → ${newStatus}`);
  }
  if (newStatus === "recrute") {
    const offer = await getOffer(app.offer_id);
    if (offer.positions_remaining <= 0) throw new Error("Tous les postes de cette offre sont déjà pourvus.");
  }
  await dbRun("UPDATE applications SET status=?, updated_at=datetime('now') WHERE id=?", [newStatus, id]);
  await addEvent(id, "statut", `Statut : ${APP_STATUS_LABEL[app.status]} → ${APP_STATUS_LABEL[newStatus]}.`);
  if (newStatus === "recrute") {
    const off = await getOffer(app.offer_id);
    const sent = await sendReponsePositive({ to: app.email, firstName: app.first_name, offerTitle: off.title });
    await addEvent(id, "email", sent ? "Réponse positive envoyée au candidat." : "Réponse positive — e-mail non envoyé (service non configuré).");
  }
  if (newStatus === "refusee") {
    const off = await getOffer(app.offer_id);
    const sent = await sendReponseNegative({ to: app.email, firstName: app.first_name, offerTitle: off.title });
    await addEvent(id, "email", sent ? "Réponse négative envoyée au candidat." : "Réponse négative — e-mail non envoyé (service non configuré).");
  }
  await syncOffer(app.offer_id);
  return getApplication(id);
}

export async function addNote(id, body) {
  if (!body || !body.trim()) return;
  await dbRun("INSERT INTO notes (application_id, body) VALUES (?,?)", [id, body.trim()]);
  await addEvent(id, "note", "Note interne ajoutée.");
}
