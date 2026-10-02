#!/usr/bin/env bash
# Sécurise l'accès admin : masque les identifiants + mot de passe pilotable par variable. À lancer à la racine.
set -e

cat > "app/components/LoginForm.js" << 'SJREOF'
"use client";
import { useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";

export default function LoginForm() {
  const router = useRouter();
  const sp = useSearchParams();
  const [username, setU] = useState("");
  const [password, setP] = useState("");
  const [err, setErr] = useState("");
  const [loading, setLoading] = useState(false);

  async function submit(e) {
    e.preventDefault();
    setLoading(true); setErr("");
    try {
      const res = await fetch("/api/auth/login", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username, password }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Connexion impossible.");
      router.push(sp.get("next") || "/admin");
      router.refresh();
    } catch (e) { setErr(e.message); setLoading(false); }
  }

  return (
    <form onSubmit={submit} className="space-y-4">
      <div>
        <label className="field-label">Identifiant</label>
        <input className="field" placeholder="Identifiant" value={username} onChange={(e) => setU(e.target.value)} autoComplete="username" />
      </div>
      <div>
        <label className="field-label">Mot de passe</label>
        <input className="field" type="password" placeholder="Mot de passe" value={password} onChange={(e) => setP(e.target.value)} autoComplete="current-password" />
      </div>
      {err && <p className="rounded-lg bg-rose-50 px-3 py-2 text-sm text-rose-700">{err}</p>}
      <button className="btn-primary w-full" disabled={loading}>{loading ? "Connexion…" : "Se connecter"}</button>
    </form>
  );
}

SJREOF

cat > "lib/auth.js" << 'SJREOF'
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
  const username = process.env.ADMIN_USERNAME || "rh";
  const password = process.env.ADMIN_PASSWORD || "mairie2026";
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
    "SELECT u.id, u.username, u.display_name FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token = ?",
    [token]
  );
  return row || null;
}

export async function getCurrentUser() {
  const token = cookies().get(SESSION_COOKIE)?.value;
  return getUserByToken(token);
}

SJREOF

echo "=== Login sécurisé installé. Lance : npm run build ==="
