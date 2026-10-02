import { dbAll, dbRun } from "./db.js";

// Durée de conservation (en années), réglable via la variable PURGE_YEARS. Défaut : 2 ans.
const YEARS = Number(process.env.PURGE_YEARS || 2);

// Date limite au format "YYYY-MM-DD HH:MM:SS" (même format que updated_at en base).
function cutoffDate() {
  const d = new Date();
  d.setFullYear(d.getFullYear() - YEARS);
  return d.toISOString().slice(0, 19).replace("T", " ");
}

// Règle : candidatures NON recrutées dont le dernier changement date de plus de PURGE_YEARS ans.
// Les candidats recrutés (devenus agents) ne sont jamais purgés.
const CRITERE = "status != 'recrute' AND updated_at < ?";

// Aperçu (pour l'écran RH) : liste ce qui serait supprimé, sans rien supprimer.
export async function listPurgeable() {
  const cutoff = cutoffDate();
  const rows = await dbAll(
    `SELECT a.id, a.public_ref, a.last_name, a.first_name, a.updated_at, a.status,
            o.title AS offer_title
       FROM applications a JOIN offers o ON o.id = a.offer_id
      WHERE a.status != 'recrute' AND a.updated_at < ?
      ORDER BY a.updated_at ASC`, [cutoff]);
  return { years: YEARS, cutoff, count: rows.length, rows };
}

async function deleteIn(table, col, ids) {
  const B = 400;
  for (let i = 0; i < ids.length; i += B) {
    const slice = ids.slice(i, i + B);
    const ph = slice.map(() => "?").join(",");
    await dbRun(`DELETE FROM ${table} WHERE ${col} IN (${ph})`, slice);
  }
}

// Purge réelle : supprime définitivement candidatures + pièces + notes + historique.
export async function purgeExpired() {
  const cutoff = cutoffDate();
  const ids = (await dbAll(`SELECT id FROM applications WHERE ${CRITERE}`, [cutoff])).map((r) => r.id);
  if (ids.length === 0) return { deleted: 0, years: YEARS };
  await deleteIn("documents", "application_id", ids);
  await deleteIn("notes", "application_id", ids);
  await deleteIn("events", "application_id", ids);
  await deleteIn("applications", "id", ids);
  return { deleted: ids.length, years: YEARS };
}

