#!/usr/bin/env bash
# Ajoute l'envoi d'e-mails (SMTP générique). À lancer à la racine du projet.
set -e

cat > "lib/email.js" << 'SJREOF'
// Envoi d'e-mails via SMTP générique (nodemailer). Indépendant du fournisseur :
// Brevo pour la démo, SMTP de la mairie en production → on change juste les variables.
// Non bloquant : si non configuré ou en erreur, l'application continue normalement.
//
// Variables d'environnement (Vercel) :
//   SMTP_HOST        ex: smtp-relay.brevo.com
//   SMTP_PORT        ex: 587
//   SMTP_USER        identifiant SMTP (login Brevo, ou compte mairie)
//   SMTP_PASS        mot de passe / clé SMTP
//   SMTP_SECURE      "true" si port 465 (sinon laisser vide → STARTTLS sur 587)
//   SMTP_FROM_EMAIL  adresse expéditeur affichée
//   SMTP_FROM_NAME   nom expéditeur (optionnel)

import nodemailer from "nodemailer";

const HOST = process.env.SMTP_HOST || "";
const PORT = Number(process.env.SMTP_PORT || 587);
const USER = process.env.SMTP_USER || "";
const PASS = process.env.SMTP_PASS || "";
const SECURE = process.env.SMTP_SECURE === "true";
const FROM_EMAIL = process.env.SMTP_FROM_EMAIL || "";
const FROM_NAME = process.env.SMTP_FROM_NAME || "Ville de Saint-Jean-de-la-Ruelle — Recrutement";

export function emailEnabled() {
  return !!HOST && !!USER && !!PASS && !!FROM_EMAIL;
}

async function sendEmail(to, subject, html) {
  if (!emailEnabled() || !to) return false;
  try {
    const transporter = nodemailer.createTransport({
      host: HOST, port: PORT, secure: SECURE,
      auth: { user: USER, pass: PASS },
      connectionTimeout: 7000, greetingTimeout: 7000, socketTimeout: 7000,
    });
    await transporter.sendMail({
      from: `"${FROM_NAME}" <${FROM_EMAIL}>`,
      to, subject, html,
    });
    return true;
  } catch (e) {
    console.error("[email] envoi ignoré :", e.message);
    return false;
  }
}

function layout(innerHtml) {
  return `<!doctype html><html><body style="margin:0;background:#f3f6f7;font-family:Arial,Helvetica,sans-serif;color:#17282c;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f3f6f7;padding:24px 0;">
    <tr><td align="center">
      <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;background:#ffffff;border-radius:12px;overflow:hidden;border:1px solid #e2eaec;">
        <tr><td style="background:#1f7f8c;padding:20px 28px;color:#ffffff;font-size:16px;font-weight:bold;">
          Ville de Saint-Jean-de-la-Ruelle
          <div style="font-size:12px;font-weight:normal;opacity:.9;">Service Ressources Humaines — Recrutement</div>
        </td></tr>
        <tr><td style="padding:28px;font-size:14px;line-height:1.6;">${innerHtml}</td></tr>
        <tr><td style="padding:18px 28px;background:#f3f6f7;color:#5c6b70;font-size:12px;line-height:1.5;">
          Ceci est un message automatique, merci de ne pas y répondre.<br/>
          Conformément au RGPD, vous disposez d'un droit d'accès, de rectification et de suppression de vos données.
        </td></tr>
      </table>
    </td></tr>
  </table></body></html>`;
}

export function sendAccuseReception({ to, firstName, offerTitle, ref }) {
  const html = layout(`
    <p>Bonjour ${firstName || ""},</p>
    <p>Nous avons bien reçu votre candidature au poste suivant :</p>
    <p style="background:#e3f1f3;border-radius:8px;padding:12px 16px;font-weight:bold;">${offerTitle}</p>
    <p>Votre dossier va être étudié par notre service Ressources Humaines. Nous reviendrons vers vous dès que possible.</p>
    <p style="color:#5c6b70;font-size:13px;">Référence de votre candidature : <strong>${ref}</strong></p>
    <p>Cordialement,<br/>Le service Ressources Humaines<br/>Ville de Saint-Jean-de-la-Ruelle</p>
  `);
  return sendEmail(to, `Accusé de réception de votre candidature — ${offerTitle}`, html);
}

export function sendReponsePositive({ to, firstName, offerTitle }) {
  const html = layout(`
    <p>Bonjour ${firstName || ""},</p>
    <p>Nous avons le plaisir de vous informer que votre candidature au poste de
       <strong>${offerTitle}</strong> a été retenue.</p>
    <p>Notre service Ressources Humaines vous recontactera très prochainement pour la suite du processus.</p>
    <p>Félicitations, et à très bientôt.</p>
    <p>Cordialement,<br/>Le service Ressources Humaines<br/>Ville de Saint-Jean-de-la-Ruelle</p>
  `);
  return sendEmail(to, `Votre candidature a été retenue — ${offerTitle}`, html);
}

export function sendReponseNegative({ to, firstName, offerTitle }) {
  const html = layout(`
    <p>Bonjour ${firstName || ""},</p>
    <p>Nous vous remercions de l'intérêt que vous avez porté au poste de
       <strong>${offerTitle}</strong> et du temps consacré à votre candidature.</p>
    <p>Après étude attentive, nous ne sommes pas en mesure de donner une suite favorable à votre demande pour ce poste.</p>
    <p>Nous vous souhaitons une pleine réussite dans vos recherches et démarches professionnelles.</p>
    <p>Cordialement,<br/>Le service Ressources Humaines<br/>Ville de Saint-Jean-de-la-Ruelle</p>
  `);
  return sendEmail(to, `Suite donnée à votre candidature — ${offerTitle}`, html);
}

SJREOF

cat > "lib/applications.js" << 'SJREOF'
import crypto from "crypto";
import { dbAll, dbGet, dbRun } from "./db.js";
import { getOffer, syncOffer } from "./offers.js";
import { APP_STATUS_LABEL, allowedTransitions } from "./constants.js";
import { sendAccuseReception, sendReponsePositive, sendReponseNegative } from "./email.js";

export function publicRef() {
  const y = new Date().getFullYear();
  const r = crypto.randomBytes(3).toString("hex").toUpperCase();
  return `CAND-${y}-${r}`;
}

const APP_SELECT = `
  SELECT a.*, o.title AS offer_title, o.reference AS offer_reference,
    o.positions_total,
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
  const info = await dbRun(`
    INSERT INTO applications (public_ref, offer_id, civility, last_name, first_name,
      address, postal_code, city, email, phone, consent_processing, consent_vivier, status)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?, 'nouvelle')`,
    [ref, offerId, data.civility || null, data.last_name || "", data.first_name || "",
     data.address || null, data.postal_code || null, data.city || null,
     data.email || null, data.phone || null,
     data.consent_processing ? 1 : 0, data.consent_vivier ? 1 : 0]);
  const id = info.lastInsertRowid;
  await addEvent(id, "creation", "Candidature reçue — statut initial : Nouvelle candidature.");
  const arSent = await sendAccuseReception({ to: data.email, firstName: data.first_name, offerTitle: offer.title, ref });
  await addEvent(id, "email", arSent ? "Accusé de réception envoyé au candidat." : "Accusé de réception — e-mail non envoyé (service non configuré).");
  return { id, public_ref: ref, offer };
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

SJREOF

echo "=== Code e-mail installé. Lance : npm install nodemailer && npm run build ==="
