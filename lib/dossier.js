import path from "path";
import { PDFDocument, StandardFonts, rgb } from "pdf-lib";
import { DOC_KINDS } from "./constants.js";

const A4 = [595.28, 841.89];
const MARGIN = 48;
const PRIMARY = rgb(0.043, 0.31, 0.541);
const INK = rgb(0.12, 0.16, 0.22);
const MUTED = rgb(0.42, 0.47, 0.53);
const LINE = rgb(0.85, 0.88, 0.91);

// pdf-lib fonts sont encodées WinAnsi (cp1252) : on neutralise les rares
// caractères hors jeu pour éviter toute erreur d'encodage.
function safe(s) {
  return String(s == null ? "" : s)
    .replace(/[\u2018\u2019]/g, "'").replace(/[\u201C\u201D]/g, '"')
    .replace(/\u2026/g, "...").replace(/[\u2013\u2014]/g, "-")
    .replace(/[^\x00-\xFF]/g, "?");
}
function extOf(p) { return (path.extname(p || "") || "").toLowerCase(); }

export async function buildDossierPdf(app, docs = []) {
  const out = await PDFDocument.create();
  out.setTitle(safe(`Dossier de candidature - ${app.first_name} ${app.last_name}`));
  const font = await out.embedFont(StandardFonts.Helvetica);
  const bold = await out.embedFont(StandardFonts.HelveticaBold);

  // ---------- Page de garde ----------
  const cover = out.addPage(A4);
  let y = A4[1] - MARGIN;
  cover.drawText("Ville de Saint-Jean-de-la-Ruelle", { x: MARGIN, y, size: 10, font, color: MUTED });
  y -= 26;
  cover.drawText("Dossier de candidature", { x: MARGIN, y, size: 22, font: bold, color: PRIMARY });
  y -= 14;
  cover.drawLine({ start: { x: MARGIN, y }, end: { x: A4[0] - MARGIN, y }, thickness: 1, color: LINE });
  y -= 30;

  const row = (label, value) => {
    cover.drawText(safe(label), { x: MARGIN, y, size: 9, font, color: MUTED });
    cover.drawText(safe(value || "-"), { x: MARGIN + 150, y, size: 11, font: bold, color: INK });
    y -= 22;
  };
  const section = (t) => { y -= 6; cover.drawText(safe(t), { x: MARGIN, y, size: 12, font: bold, color: PRIMARY }); y -= 20; };

  section("Candidat");
  row("Identité", `${app.civility || ""} ${app.first_name} ${app.last_name}`.trim());
  row("E-mail", app.email);
  row("Téléphone", app.phone);
  row("Adresse", [app.address, app.postal_code, app.city].filter(Boolean).join(", "));

  section("Poste");
  row("Intitulé", app.offer_title);
  row("Référence offre", app.offer_reference);
  row("Secteur", app.sector_name);
  row("Direction", app.direction_name);
  row("Pôle", app.pole_name);

  section("Suivi");
  row("Référence candidature", app.public_ref);
  row("Statut actuel", app.status_label || app.status);
  row("Reçue le", app.created_at);

  section("Pièces incluses dans ce dossier");
  for (const d of app.documents) {
    const label = DOC_KINDS[d.kind]?.label || d.kind;
    cover.drawText(safe(`• ${label} — ${d.original_name}`), { x: MARGIN, y, size: 10, font, color: INK });
    y -= 16;
    if (y < MARGIN + 40) break;
  }

  cover.drawText(safe(`Document généré automatiquement — ${new Date().toLocaleString("fr-FR")}`),
    { x: MARGIN, y: MARGIN - 14, size: 8, font, color: MUTED });

  // ---------- Pièces jointes ----------
  for (const d of docs) {
    const buf = d.buffer;
    if (!buf || !buf.length) continue;
    const ext = extOf(d.original_name) || (d.mime === "application/pdf" ? ".pdf" : "");
    const label = `${DOC_KINDS[d.kind]?.label || d.kind} — ${d.original_name}`;

    if (ext === ".pdf") {
      try {
        const src = await PDFDocument.load(buf, { ignoreEncryption: true });
        const pages = await out.copyPages(src, src.getPageIndices());
        pages.forEach((p) => out.addPage(p));
        continue;
      } catch { /* pdf illisible -> page d'info ci-dessous */ }
    }

    if (ext === ".png" || ext === ".jpg" || ext === ".jpeg") {
      try {
        const img = ext === ".png" ? await out.embedPng(buf) : await out.embedJpg(buf);
        const page = out.addPage(A4);
        page.drawText(safe(label), { x: MARGIN, y: A4[1] - MARGIN, size: 10, font: bold, color: PRIMARY });
        const maxW = A4[0] - 2 * MARGIN, maxH = A4[1] - 2 * MARGIN - 30;
        const s = Math.min(maxW / img.width, maxH / img.height, 1);
        const w = img.width * s, h = img.height * s;
        page.drawImage(img, { x: (A4[0] - w) / 2, y: (A4[1] - h) / 2 - 15, width: w, height: h });
        continue;
      } catch { /* image illisible -> page d'info */ }
    }

    // Formats non fusionnables (doc/docx/…)
    const page = out.addPage(A4);
    page.drawText(safe(label), { x: MARGIN, y: A4[1] - MARGIN, size: 12, font: bold, color: PRIMARY });
    page.drawText(safe(`Format ${ext || "inconnu"} non fusionnable dans le PDF.`),
      { x: MARGIN, y: A4[1] - MARGIN - 26, size: 11, font, color: INK });
    page.drawText(safe("Cette pièce reste téléchargeable individuellement depuis la fiche candidature."),
      { x: MARGIN, y: A4[1] - MARGIN - 44, size: 10, font, color: MUTED });
  }

  return Buffer.from(await out.save());
}
