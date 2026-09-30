import crypto from "crypto";
import { cookies } from "next/headers";
import { dbGet, dbRun } from "./db.js";

export const SESSION_COOKIE = "sjr_rh_session";

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
  const existing = await dbGet("SELECT id FROM users WHERE username = ?", ["rh"]);
  if (!existing) {
    const { hash, salt } = hashPassword("mairie2026");
    await dbRun(
      "INSERT INTO users (username, password_hash, salt, display_name) VALUES (?,?,?,?)",
      ["rh", hash, salt, "Service RH"]
    );
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
    "SELECT u.id, u.username, u.display_name FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token = ?",
    [token]
  );
  return row || null;
}

export async function getCurrentUser() {
  const token = cookies().get(SESSION_COOKIE)?.value;
  return getUserByToken(token);
}
