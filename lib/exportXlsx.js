import * as XLSX from "xlsx";
import { APP_STATUS_LABEL, DOC_KINDS } from "./constants.js";
import { fmtDateTime } from "./format.js";

export function buildApplicationsWorkbook(rows, history = []) {
  const wb = XLSX.utils.book_new();

  const EVENT_TYPE = { creation: "Création", statut: "Changement d'étape", email: "E-mail (simulé)", note: "Note interne" };

  // Feuille 1 : liste détaillée
  const data = rows.map((a) => ({
    "Réf. candidature": a.public_ref,
    "Date de réception": fmtDateTime(a.created_at),
    "Statut": APP_STATUS_LABEL[a.status] || a.status,
    "Civilité": a.civility || "",
    "Nom": a.last_name,
    "Prénom": a.first_name,
    "E-mail": a.email || "",
    "Téléphone": a.phone || "",
    "Adresse": a.address || "",
    "Code postal": a.postal_code || "",
    "Ville": a.city || "",
    "Offre": a.offer_title,
    "Réf. offre": a.offer_reference,
    "Secteur": a.sector_name || "",
    "Direction": a.direction_name || "",
    "Pôle": a.pole_name || "",
    "Documents fournis": (a.doc_kinds || []).map((k) => DOC_KINDS[k]?.label || k).join(", "),
  }));
  const ws = XLSX.utils.json_to_sheet(data);
  ws["!cols"] = [
    { wch: 18 }, { wch: 18 }, { wch: 16 }, { wch: 9 }, { wch: 16 }, { wch: 14 },
    { wch: 26 }, { wch: 15 }, { wch: 28 }, { wch: 11 }, { wch: 16 }, { wch: 30 },
    { wch: 14 }, { wch: 20 }, { wch: 22 }, { wch: 22 }, { wch: 30 },
  ];
  if (data.length) ws["!autofilter"] = { ref: XLSX.utils.encode_range({ s: { r: 0, c: 0 }, e: { r: data.length, c: 16 } }) };
  XLSX.utils.book_append_sheet(wb, ws, "Candidatures");

  // Feuille 2 : historique détaillé (une ligne par étape/événement horodaté)
  const histData = history.map((h) => ({
    "Horodatage": fmtDateTime(h.created_at),
    "Réf candidature": h.ref,
    "Nom": h.last_name,
    "Prénom": h.first_name,
    "Offre": h.offer_title,
    "Événement": h.message,
    "Type": EVENT_TYPE[h.type] || h.type || "",
  }));
  const wsH = XLSX.utils.json_to_sheet(histData.length ? histData : [{ "Horodatage": "", "Réf candidature": "", "Nom": "", "Prénom": "", "Offre": "", "Événement": "", "Type": "" }]);
  wsH["!cols"] = [{ wch: 18 }, { wch: 18 }, { wch: 16 }, { wch: 14 }, { wch: 30 }, { wch: 40 }, { wch: 20 }];
  if (histData.length) wsH["!autofilter"] = { ref: XLSX.utils.encode_range({ s: { r: 0, c: 0 }, e: { r: histData.length, c: 6 } }) };
  XLSX.utils.book_append_sheet(wb, wsH, "Historique");

  // Feuille 2 : synthèse
  const byStatus = {};
  const byOffer = {};
  for (const a of rows) {
    const sl = APP_STATUS_LABEL[a.status] || a.status;
    byStatus[sl] = (byStatus[sl] || 0) + 1;
    byOffer[a.offer_title] = (byOffer[a.offer_title] || 0) + 1;
  }
  const synth = [
    ["Synthèse des candidatures", ""],
    ["Total", rows.length],
    ["", ""],
    ["Par statut", ""],
    ...Object.entries(byStatus).map(([k, v]) => [k, v]),
    ["", ""],
    ["Par offre", ""],
    ...Object.entries(byOffer).map(([k, v]) => [k, v]),
    ["", ""],
    ["Export généré le", fmtDateTime(new Date().toISOString())],
  ];
  const ws2 = XLSX.utils.aoa_to_sheet(synth);
  ws2["!cols"] = [{ wch: 40 }, { wch: 12 }];
  XLSX.utils.book_append_sheet(wb, ws2, "Synthèse");

  return XLSX.write(wb, { type: "buffer", bookType: "xlsx" });
}
