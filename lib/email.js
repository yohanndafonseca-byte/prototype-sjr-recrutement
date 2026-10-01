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

