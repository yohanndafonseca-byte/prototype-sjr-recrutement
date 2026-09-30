/**
 * Recrutement SJR — réception des données du site dans Google Sheets.
 *
 * INSTALLATION (5 min) :
 * 1. Crée un Google Sheet vierge.
 * 2. Menu  Extensions ▸ Apps Script.
 * 3. Efface le contenu par défaut, colle CE fichier entièrement.
 * 4. Remplace la valeur de SECRET ci-dessous par un mot de passe à toi.
 * 5. Clique  Déployer ▸ Nouveau déploiement ▸ type "Application Web".
 *      - Exécuter en tant que : Moi
 *      - Qui a accès : Tout le monde
 *    Autorise, puis COPIE l'URL qui finit par /exec.
 * 6. Reporte cette URL et le MÊME secret dans le fichier .env.local du projet.
 *
 * Deux onglets sont alimentés automatiquement :
 *   - "Candidatures" : une ligne par candidat, mise à jour à chaque étape (pour les stats).
 *   - "Journal"      : une ligne par événement horodaté (traçabilité complète).
 */

var SECRET = "change_moi"; // <-- doit être identique à SHEETS_WEBHOOK_SECRET

var HEAD_CANDIDATURES = [
  "Réf", "Date réception", "Statut", "Dernière MAJ",
  "Civilité", "Nom", "Prénom", "E-mail", "Téléphone", "Ville",
  "Offre", "Réf offre", "Secteur", "Direction", "Pôle"
];
var HEAD_JOURNAL = ["Horodatage", "Réf candidature", "Nom", "Prénom", "Offre", "Événement", "Statut"];

function doPost(e) {
  try {
    var body = JSON.parse(e.postData.contents);
    if (SECRET && body.secret !== SECRET) return json({ ok: false, error: "unauthorized" });
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    upsertCandidature(ss, body);
    appendJournal(ss, body);
    return json({ ok: true });
  } catch (err) {
    return json({ ok: false, error: String(err) });
  }
}

function sheet(ss, name, headers) {
  var sh = ss.getSheetByName(name);
  if (!sh) { sh = ss.insertSheet(name); }
  if (sh.getLastRow() === 0) {
    sh.getRange(1, 1, 1, headers.length).setValues([headers]).setFontWeight("bold");
    sh.setFrozenRows(1);
  }
  return sh;
}

function upsertCandidature(ss, b) {
  var sh = sheet(ss, "Candidatures", HEAD_CANDIDATURES);
  var row = [
    b.ref, b.received_at, b.status_label, b.updated_at,
    b.civility, b.last_name, b.first_name, b.email, b.phone, b.city,
    b.offer_title, b.offer_ref, b.sector, b.direction, b.pole
  ];
  var refs = sh.getRange(2, 1, Math.max(sh.getLastRow() - 1, 0), 1).getValues();
  for (var i = 0; i < refs.length; i++) {
    if (refs[i][0] === b.ref) { // déjà présente -> mise à jour en place
      sh.getRange(i + 2, 1, 1, row.length).setValues([row]);
      return;
    }
  }
  sh.appendRow(row); // nouvelle candidature
}

function appendJournal(ss, b) {
  var sh = sheet(ss, "Journal", HEAD_JOURNAL);
  sh.appendRow([b.updated_at, b.ref, b.last_name, b.first_name, b.offer_title, b.event, b.status_label]);
}

function json(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
