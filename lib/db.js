import { createClient } from "@libsql/client";
import path from "path";
import fs from "fs";

// Connexion libSQL :
//  - en local (dev/test), fichier local (file:./data/local.db)
//  - en production, TURSO_DATABASE_URL + TURSO_AUTH_TOKEN
const g = globalThis;

function makeClient() {
  const url = process.env.TURSO_DATABASE_URL;
  if (url) return createClient({ url, authToken: process.env.TURSO_AUTH_TOKEN });
  const dir = path.join(process.cwd(), "data");
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  return createClient({ url: "file:" + path.join(dir, "local.db") });
}
function client() {
  if (!g.__sjr_client) g.__sjr_client = makeClient();
  return g.__sjr_client;
}

async function rawAll(sql, args = []) {
  const r = await client().execute({ sql, args });
  return r.rows;
}
async function rawGet(sql, args = []) {
  const r = await client().execute({ sql, args });
  return r.rows[0] ?? null;
}
async function rawRun(sql, args = []) {
  const r = await client().execute({ sql, args });
  return {
    lastInsertRowid: r.lastInsertRowid != null ? Number(r.lastInsertRowid) : null,
    changes: r.rowsAffected ?? 0,
  };
}

const SCHEMA = [
  `CREATE TABLE IF NOT EXISTS sectors (id INTEGER PRIMARY KEY, name TEXT NOT NULL, sort INTEGER DEFAULT 0)`,
  `CREATE TABLE IF NOT EXISTS directions (id INTEGER PRIMARY KEY, sector_id INTEGER NOT NULL, name TEXT NOT NULL)`,
  `CREATE TABLE IF NOT EXISTS poles (id INTEGER PRIMARY KEY, direction_id INTEGER NOT NULL, name TEXT NOT NULL)`,
  `CREATE TABLE IF NOT EXISTS offers (
    id INTEGER PRIMARY KEY, reference TEXT UNIQUE NOT NULL, title TEXT NOT NULL,
    sector_id INTEGER, direction_id INTEGER, pole_id INTEGER,
    contract_type TEXT, work_time TEXT, location TEXT DEFAULT 'Saint-Jean-de-la-Ruelle',
    positions_total INTEGER NOT NULL DEFAULT 1, published_at TEXT, deadline TEXT,
    status TEXT NOT NULL DEFAULT 'brouillon',
    missions TEXT, profile TEXT, conditions TEXT, extra_info TEXT, keywords TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')), updated_at TEXT NOT NULL DEFAULT (datetime('now'))
  )`,
  `CREATE TABLE IF NOT EXISTS applications (
    id INTEGER PRIMARY KEY, public_ref TEXT UNIQUE NOT NULL, offer_id INTEGER NOT NULL,
    civility TEXT, last_name TEXT NOT NULL, first_name TEXT NOT NULL,
    address TEXT, postal_code TEXT, city TEXT, email TEXT, phone TEXT,
    status TEXT NOT NULL DEFAULT 'nouvelle',
    created_at TEXT NOT NULL DEFAULT (datetime('now')), updated_at TEXT NOT NULL DEFAULT (datetime('now'))
  )`,
  `CREATE TABLE IF NOT EXISTS documents (
    id INTEGER PRIMARY KEY, application_id INTEGER NOT NULL, kind TEXT NOT NULL,
    original_name TEXT, stored_path TEXT, content TEXT, mime TEXT, size INTEGER,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )`,
  `CREATE TABLE IF NOT EXISTS notes (
    id INTEGER PRIMARY KEY, application_id INTEGER NOT NULL, body TEXT NOT NULL,
    author TEXT DEFAULT 'RH', created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )`,
  `CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY, application_id INTEGER NOT NULL, type TEXT NOT NULL,
    message TEXT NOT NULL, created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )`,
  `CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY, username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL, salt TEXT NOT NULL, display_name TEXT
  )`,
  `CREATE TABLE IF NOT EXISTS sessions (
    token TEXT PRIMARY KEY, user_id INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )`,
];

async function migrate() {
  // Un seul aller-retour réseau au lieu d'un par table (gain au démarrage à froid).
  await client().batch(SCHEMA, "write");
}
async function seedIfEmpty() {
  // Le jeu de démonstration ne se crée QUE si SEED_DEMO=1 est défini.
  // En production on ne met pas cette variable -> la base reste telle quelle.
  if (process.env.SEED_DEMO !== "1") return;
  const row = await rawGet("SELECT COUNT(*) AS n FROM offers");
  if (row && Number(row.n) === 0) {
    const { seedDatabase } = await import("./seed.js");
    await seedDatabase();
  }
}
function ensureReady() {
  if (!g.__sjr_ready) {
    g.__sjr_ready = (async () => { await migrate(); await seedIfEmpty(); })()
      .catch((e) => { g.__sjr_ready = null; throw e; });
  }
  return g.__sjr_ready;
}

export async function dbAll(sql, args = []) { await ensureReady(); return rawAll(sql, args); }
export async function dbGet(sql, args = []) { await ensureReady(); return rawGet(sql, args); }
export async function dbRun(sql, args = []) { await ensureReady(); return rawRun(sql, args); }
export async function dbBatch(stmts) { await ensureReady(); return client().batch(stmts, "write"); }
export const _raw = { rawAll, rawGet, rawRun };
