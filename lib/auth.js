import crypto from "crypto";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { dbGet, dbRun } from "./db.js";

export const SESSION_COOKIE = "sjr_rh_session";

// Durée de validité d'une session (en jours).
export const SESSION_DAYS = 30;

export function hashPassword(password, salt) {
  const s = salt || crypto.randomBytes(16).toString("hex");
  const hash = crypto.scryptSync(password, s, 64).toString("hex");
  return { hash, salt: s };
}

export function verifyPassword(password, salt, expectedHash) {
  const { hash } = hashPassword(password, salt);
  const a = Buffer.from(hash, "hex");
  const b = Buffer.from(expectedHash, "hex");
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

export async function ensureDefaultUser() {
  const username = process.env.ADMIN_USERNAME || "rh";
  const password = process.env.ADMIN_PASSWORD;
  // Pas de mot de passe par défaut : tant que ADMIN_PASSWORD n'est pas défini
  // (variable d'environnement), aucun compte n'est créé/mis à jour.
  if (!password) return;
  const existing = await dbGet("SELECT id FROM users WHERE username = ?", [username]);
  if (!existing) {
    const { hash, salt } = hashPassword(password);
    await dbRun(
      "INSERT INTO users (username, password_hash, salt, display_name) VALUES (?,?,?,?)",
      [username, hash, salt, "Service RH"]
    );
  } else if (process.env.ADMIN_PASSWORD) {
    // Un mot de passe défini en variable d'environnement est appliqué au compte existant
    // (permet de changer le mot de passe sans modifier la base manuellement).
    const { hash, salt } = hashPassword(password);
    await dbRun("UPDATE users SET password_hash=?, salt=? WHERE id=?", [hash, salt, existing.id]);
  }
}

export async function login(username, password) {
  await ensureDefaultUser();
  const user = await dbGet("SELECT * FROM users WHERE username = ?", [username]);
  if (!user) return null;
  if (!verifyPassword(password, user.salt, user.password_hash)) return null;
  const token = crypto.randomBytes(24).toString("hex");
  await dbRun("INSERT INTO sessions (token, user_id) VALUES (?,?)", [token, user.id]);
  return { token, user };
}

export async function destroySession(token) {
  if (!token) return;
  await dbRun("DELETE FROM sessions WHERE token = ?", [token]);
}

export async function getUserByToken(token) {
  if (!token) return null;
  const row = await dbGet(
    `SELECT u.id, u.username, u.display_name
       FROM sessions s JOIN users u ON u.id = s.user_id
      WHERE s.token = ? AND s.created_at > datetime('now', '-${SESSION_DAYS} days')`,
    [token]
  );
  return row || null;
}

// Garde d'authentification pour les routes API /api/admin/* :
//   const deny = await unauthorized(); if (deny) return deny;
// Renvoie une réponse 401 si la session est absente/invalide, sinon null.
export async function unauthorized() {
  const user = await getCurrentUser();
  return user ? null : NextResponse.json({ error: "Non authentifié" }, { status: 401 });
}

export async function getCurrentUser() {
  const token = cookies().get(SESSION_COOKIE)?.value;
  return getUserByToken(token);
}
