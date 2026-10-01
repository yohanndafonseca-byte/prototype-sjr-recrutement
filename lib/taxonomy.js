import { dbGet, dbRun } from "./db.js";

const clean = (s) => String(s || "").trim();

async function count(sql, args) {
  const r = await dbGet(sql, args);
  return Number(r.n) || 0;
}

/* ---------- SECTEURS ---------- */
export async function createSector(name) {
  name = clean(name);
  if (!name) throw new Error("Le nom est obligatoire.");
  const r = await dbGet("SELECT COALESCE(MAX(sort),0)+1 AS s FROM sectors");
  const info = await dbRun("INSERT INTO sectors (name, sort) VALUES (?,?)", [name, Number(r.s)]);
  return info.lastInsertRowid;
}
export async function renameSector(id, name) {
  name = clean(name);
  if (!name) throw new Error("Le nom est obligatoire.");
  await dbRun("UPDATE sectors SET name=? WHERE id=?", [name, id]);
}
export async function deleteSector(id) {
  const dirs = await count("SELECT COUNT(*) AS n FROM directions WHERE sector_id=?", [id]);
  if (dirs > 0) throw new Error("Ce secteur contient des directions. Supprimez-les d'abord.");
  const used = await count("SELECT COUNT(*) AS n FROM offers WHERE sector_id=?", [id]);
  if (used > 0) throw new Error(`Impossible : ${used} offre(s) utilisent ce secteur.`);
  await dbRun("DELETE FROM sectors WHERE id=?", [id]);
}

/* ---------- DIRECTIONS ---------- */
export async function createDirection(sectorId, name) {
  name = clean(name);
  if (!sectorId) throw new Error("Secteur manquant.");
  if (!name) throw new Error("Le nom est obligatoire.");
  const info = await dbRun("INSERT INTO directions (sector_id, name) VALUES (?,?)", [sectorId, name]);
  return info.lastInsertRowid;
}
export async function renameDirection(id, name) {
  name = clean(name);
  if (!name) throw new Error("Le nom est obligatoire.");
  await dbRun("UPDATE directions SET name=? WHERE id=?", [name, id]);
}
export async function deleteDirection(id) {
  const poles = await count("SELECT COUNT(*) AS n FROM poles WHERE direction_id=?", [id]);
  if (poles > 0) throw new Error("Cette direction contient des pôles. Supprimez-les d'abord.");
  const used = await count("SELECT COUNT(*) AS n FROM offers WHERE direction_id=?", [id]);
  if (used > 0) throw new Error(`Impossible : ${used} offre(s) utilisent cette direction.`);
  await dbRun("DELETE FROM directions WHERE id=?", [id]);
}

/* ---------- PÔLES ---------- */
export async function createPole(directionId, name) {
  name = clean(name);
  if (!directionId) throw new Error("Direction manquante.");
  if (!name) throw new Error("Le nom est obligatoire.");
  const info = await dbRun("INSERT INTO poles (direction_id, name) VALUES (?,?)", [directionId, name]);
  return info.lastInsertRowid;
}
export async function renamePole(id, name) {
  name = clean(name);
  if (!name) throw new Error("Le nom est obligatoire.");
  await dbRun("UPDATE poles SET name=? WHERE id=?", [name, id]);
}
export async function deletePole(id) {
  const used = await count("SELECT COUNT(*) AS n FROM offers WHERE pole_id=?", [id]);
  if (used > 0) throw new Error(`Impossible : ${used} offre(s) utilisent ce pôle.`);
  await dbRun("DELETE FROM poles WHERE id=?", [id]);
}
