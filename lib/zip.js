import JSZip from "jszip";
import { getApplication, listDocumentsWithContent } from "./applications.js";
import { buildDossierPdf } from "./dossier.js";

// Nom de fichier sûr : lettres (accents ok), chiffres, espace, _ et -
function safeName(s) {
  return String(s || "").replace(/[^\p{L}\p{N} _-]/gu, "").replace(/\s+/g, " ").trim();
}

// Construit un ZIP : un dossier PDF fusionné (page de garde + pièces) par candidat,
// nommé "NOM Prénom.pdf".
export async function buildApplicationsZip(apps) {
  const zip = new JSZip();
  const used = {};
  let count = 0;
  for (const a of apps) {
    const full = await getApplication(a.id);
    if (!full) continue;
    const docs = await listDocumentsWithContent(a.id);
    const pdf = await buildDossierPdf(full, docs);
    let base = safeName(`${a.last_name || ""} ${a.first_name || ""}`) || `candidat_${a.id}`;
    let name = base, i = 2;
    while (used[name]) name = `${base} (${i++})`; // évite les écrasements (homonymes)
    used[name] = true;
    zip.file(`${name}.pdf`, pdf);
    count++;
  }
  if (count === 0) {
    zip.file("AUCUNE_CANDIDATURE.txt", "Aucune candidature à télécharger pour ce filtre.");
  }
  return zip.generateAsync({ type: "nodebuffer" });
}
