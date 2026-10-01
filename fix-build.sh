#!/usr/bin/env bash
# Réécrit proprement les fichiers (à lancer depuis la racine du projet, là où sont app/ et lib/)
set -e

mkdir -p "$(dirname lib/db.js)"
cat > lib/db.js << 'SJREOF'
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
  for (const stmt of SCHEMA) await client().execute(stmt);
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
export const _raw = { rawAll, rawGet, rawRun };
SJREOF

mkdir -p "$(dirname lib/offers.js)"
cat > lib/offers.js << 'SJREOF'
import { dbAll, dbGet, dbRun } from "./db.js";
import { OFFER_STATUS } from "./constants.js";

export function todayISO() {
  return new Date().toISOString().slice(0, 10);
}

const BASE_SELECT = `
  SELECT o.*,
    s.name AS sector_name,
    d.name AS direction_name,
    p.name AS pole_name,
    (SELECT COUNT(*) FROM applications a WHERE a.offer_id = o.id) AS applications_count,
    (SELECT COUNT(*) FROM applications a WHERE a.offer_id = o.id AND a.status = 'recrute') AS positions_filled
  FROM offers o
  LEFT JOIN sectors s ON s.id = o.sector_id
  LEFT JOIN directions d ON d.id = o.direction_id
  LEFT JOIN poles p ON p.id = o.pole_id
`;

function enrich(row) {
  if (!row) return row;
  row.positions_total = Number(row.positions_total);
  row.positions_filled = Number(row.positions_filled) || 0;
  row.positions_remaining = Math.max(0, row.positions_total - row.positions_filled);
  row.is_expired = row.deadline ? row.deadline < todayISO() : false;
  return row;
}

export async function syncOffer(id) {
  const row = enrich(await dbGet(BASE_SELECT + " WHERE o.id = ?", [id]));
  if (!row) return null;
  let newStatus = row.status;
  if (row.status === OFFER_STATUS.PUBLIEE) {
    if (row.positions_remaining <= 0) newStatus = OFFER_STATUS.POURVUE;
    else if (row.is_expired) newStatus = OFFER_STATUS.EXPIREE;
  } else if (row.status === OFFER_STATUS.POURVUE) {
    if (row.positions_remaining > 0 && !row.is_expired) newStatus = OFFER_STATUS.PUBLIEE;
    else if (row.positions_remaining > 0 && row.is_expired) newStatus = OFFER_STATUS.EXPIREE;
  }
  if (newStatus !== row.status) {
    await dbRun("UPDATE offers SET status = ?, updated_at = datetime('now') WHERE id = ?", [newStatus, id]);
    row.status = newStatus;
  }
  return row;
}

export async function syncAll() {
  // Recalcule les statuts automatiques de TOUTES les offres en 4 requêtes SQL
  // (au lieu d'une boucle qui interrogeait la base offre par offre).
  const today = todayISO();
  const filled =
    "(SELECT COUNT(*) FROM applications a WHERE a.offer_id = offers.id AND a.status = 'recrute')";
  // publiée -> pourvue : plus de poste restant
  await dbRun(`UPDATE offers SET status='pourvue', updated_at=datetime('now')
    WHERE status='publiee' AND positions_total - ${filled} <= 0`);
  // publiée -> expirée : échéance passée mais postes encore ouverts
  await dbRun(`UPDATE offers SET status='expiree', updated_at=datetime('now')
    WHERE status='publiee' AND deadline IS NOT NULL AND deadline < ?
      AND positions_total - ${filled} > 0`, [today]);
  // pourvue -> publiée : un poste se libère et l'offre est encore valide
  await dbRun(`UPDATE offers SET status='publiee', updated_at=datetime('now')
    WHERE status='pourvue' AND positions_total - ${filled} > 0
      AND (deadline IS NULL OR deadline >= ?)`, [today]);
  // pourvue -> expirée : un poste se libère mais l'échéance est passée
  await dbRun(`UPDATE offers SET status='expiree', updated_at=datetime('now')
    WHERE status='pourvue' AND deadline IS NOT NULL AND deadline < ?
      AND positions_total - ${filled} > 0`, [today]);
}

export async function getOffer(id) {
  await syncOffer(id);
  return enrich(await dbGet(BASE_SELECT + " WHERE o.id = ?", [id]));
}

export async function listPublicOffers(q = "") {
  await syncAll();
  const rows = (await dbAll(BASE_SELECT + " WHERE o.status = 'publiee' ORDER BY o.published_at DESC, o.id DESC"))
    .map(enrich)
    .filter((o) => !o.is_expired && o.positions_remaining > 0);
  const term = (q || "").trim().toLowerCase();
  if (!term) return rows;
  return rows.filter((o) => {
    const hay = [o.title, o.sector_name, o.direction_name, o.pole_name, o.contract_type, o.location, o.keywords, o.missions, o.profile]
      .filter(Boolean).join(" ").toLowerCase();
    return term.split(/\s+/).every((t) => hay.includes(t));
  });
}

export async function getPublicOffer(id) {
  const o = await getOffer(id);
  if (!o) return null;
  if (o.status !== "publiee" || o.is_expired || o.positions_remaining <= 0) return null;
  return o;
}

export async function listAdminOffers({ status = null, q = "" } = {}) {
  await syncAll();
  let rows = (await dbAll(BASE_SELECT + " ORDER BY o.updated_at DESC, o.id DESC")).map(enrich);
  if (status) rows = rows.filter((o) => o.status === status);
  const term = (q || "").trim().toLowerCase();
  if (term) {
    rows = rows.filter((o) =>
      [o.title, o.reference, o.sector_name, o.direction_name, o.pole_name]
        .filter(Boolean).join(" ").toLowerCase().includes(term)
    );
  }
  return rows;
}

export async function nextReference() {
  const year = new Date().getFullYear();
  const row = await dbGet("SELECT COUNT(*) AS n FROM offers");
  const seq = String(Number(row.n) + 1).padStart(3, "0");
  return `OFF-${year}-${seq}`;
}

const OFFER_FIELDS = ["title","sector_id","direction_id","pole_id","contract_type","work_time","location","positions_total","deadline","missions","profile","conditions","extra_info","keywords"];

export async function createOffer(data, { publish = false } = {}) {
  const reference = data.reference || (await nextReference());
  const status = publish ? "publiee" : "brouillon";
  const published_at = publish ? todayISO() : null;
  const args = [
    reference, data.title || "Sans titre", data.sector_id || null, data.direction_id || null,
    data.pole_id || null, data.contract_type || null, data.work_time || null,
    data.location || "Saint-Jean-de-la-Ruelle", Math.max(1, parseInt(data.positions_total) || 1),
    data.deadline || null, data.missions || null, data.profile || null, data.conditions || null,
    data.extra_info || null, data.keywords || null, status, published_at,
  ];
  const info = await dbRun(`
    INSERT INTO offers (reference, title, sector_id, direction_id, pole_id, contract_type,
      work_time, location, positions_total, deadline, missions, profile, conditions,
      extra_info, keywords, status, published_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`, args);
  return getOffer(info.lastInsertRowid);
}

export async function updateOffer(id, data) {
  const current = await dbGet("SELECT * FROM offers WHERE id = ?", [id]);
  if (!current) return null;
  const merged = { ...current };
  for (const f of OFFER_FIELDS) if (f in data && data[f] !== undefined) merged[f] = data[f];
  merged.positions_total = Math.max(1, parseInt(merged.positions_total) || 1);
  await dbRun(`
    UPDATE offers SET title=?, sector_id=?, direction_id=?, pole_id=?, contract_type=?, work_time=?,
      location=?, positions_total=?, deadline=?, missions=?, profile=?, conditions=?, extra_info=?,
      keywords=?, updated_at=datetime('now') WHERE id=?`,
    [merged.title, merged.sector_id, merged.direction_id, merged.pole_id, merged.contract_type,
     merged.work_time, merged.location, merged.positions_total, merged.deadline, merged.missions,
     merged.profile, merged.conditions, merged.extra_info, merged.keywords, id]);
  return getOffer(id);
}

export async function setOfferStatus(id, status, { setPublishedAt = false } = {}) {
  if (setPublishedAt) {
    await dbRun("UPDATE offers SET status=?, published_at=?, updated_at=datetime('now') WHERE id=?", [status, todayISO(), id]);
  } else {
    await dbRun("UPDATE offers SET status=?, updated_at=datetime('now') WHERE id=?", [status, id]);
  }
  return getOffer(id);
}

export async function publishOffer(id) {
  const o = await dbGet("SELECT published_at FROM offers WHERE id=?", [id]);
  return setOfferStatus(id, "publiee", { setPublishedAt: !o?.published_at });
}
export async function unpublishOffer(id) {
  return setOfferStatus(id, "brouillon");
}

export async function getMetaTree() {
  const sectors = await dbAll("SELECT * FROM sectors ORDER BY sort, name");
  const directions = await dbAll("SELECT * FROM directions ORDER BY name");
  const poles = await dbAll("SELECT * FROM poles ORDER BY name");
  return sectors.map((s) => ({
    ...s,
    directions: directions.filter((d) => d.sector_id === s.id).map((d) => ({
      ...d, poles: poles.filter((p) => p.direction_id === d.id),
    })),
  }));
}

export async function dashboardStats() {
  await syncAll();
  const c = await dbGet(`SELECT
      (SELECT COUNT(*) FROM applications WHERE status='nouvelle') AS newApps,
      (SELECT COUNT(*) FROM applications WHERE status IN ('a_etudier','preselectionnee','entretien','retenue')) AS inProgress,
      (SELECT COUNT(*) FROM offers WHERE status='publiee') AS published,
      (SELECT COUNT(*) FROM offers) AS totalOffers,
      (SELECT COUNT(*) FROM applications WHERE status='recrute') AS recruited`);
  const soon = (await listAdminOffers({ status: "publiee" })).filter((o) => {
    if (!o.deadline) return false;
    const d = Math.ceil((new Date(o.deadline + "T23:59:59") - new Date()) / 86400000);
    return d >= 0 && d <= 14;
  });
  return {
    newApps: Number(c.newApps), inProgress: Number(c.inProgress), published: Number(c.published),
    soon, totalOffers: Number(c.totalOffers), recruited: Number(c.recruited),
  };
}
SJREOF

mkdir -p "$(dirname app/components/OfferForm.js)"
cat > app/components/OfferForm.js << 'SJREOF'
"use client";
import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { CONTRACT_TYPES, WORK_TIMES } from "@/lib/constants";

const empty = {
  title: "", sector_id: "", direction_id: "", pole_id: "", contract_type: "",
  work_time: "", positions_total: 1, deadline: "", keywords: "",
  missions: "", profile: "", conditions: "", extra_info: "",
};

// Défini au niveau module : sinon il serait recréé à chaque frappe,
// ce qui remonterait les <input> et ferait "sauter" les lettres saisies.
function Field({ label, children, required, full }) {
  return (
    <div className={full ? "sm:col-span-2" : ""}>
      <label className="field-label">{label}{required && <span className="text-rose-500"> *</span>}</label>
      {children}
    </div>
  );
}

export default function OfferForm({ tree, initial, offerId, status }) {
  const router = useRouter();
  const [f, setF] = useState({ ...empty, ...(initial || {}) });
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState("");

  const set = (k, v) => setF((s) => ({ ...s, [k]: v }));

  const directions = useMemo(() => tree.find((s) => String(s.id) === String(f.sector_id))?.directions || [], [tree, f.sector_id]);
  const poles = useMemo(() => directions.find((d) => String(d.id) === String(f.direction_id))?.poles || [], [directions, f.direction_id]);

  function payload() {
    return {
      title: f.title.trim(), sector_id: f.sector_id || null, direction_id: f.direction_id || null,
      pole_id: f.pole_id || null, contract_type: f.contract_type || null, work_time: f.work_time || null,
      positions_total: Number(f.positions_total) || 1, deadline: f.deadline || null, keywords: f.keywords,
      missions: f.missions, profile: f.profile, conditions: f.conditions, extra_info: f.extra_info,
    };
  }
  function validate(forPublish) {
    if (!f.title.trim()) return "Le titre du poste est obligatoire.";
    if (forPublish) {
      if (!f.sector_id || !f.direction_id || !f.pole_id) return "Secteur, direction et pôle sont requis pour publier.";
      if (!f.contract_type || !f.work_time) return "Type de contrat et temps de travail requis pour publier.";
      if (!f.deadline) return "La date limite de candidature est requise pour publier.";
    }
    return "";
  }

  async function save(action) {
    const forPublish = action === "publish";
    const v = validate(forPublish);
    if (v) { setErr(v); return; }
    setErr(""); setBusy(action);
    try {
      let id = offerId;
      if (!offerId) {
        const res = await fetch("/api/admin/offres", {
          method: "POST", headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ ...payload(), action: forPublish ? "publish" : "draft" }),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || "Erreur");
        id = data.id;
      } else {
        const res = await fetch(`/api/admin/offres/${offerId}`, {
          method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload()),
        });
        if (!res.ok) throw new Error((await res.json()).error || "Erreur");
        if (action === "publish" || action === "unpublish") {
          await fetch(`/api/admin/offres/${offerId}`, {
            method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ action }),
          });
        }
      }
      router.push(`/admin/offres/${id}`);
      router.refresh();
    } catch (e) { setErr(e.message); setBusy(""); }
  }

  return (
    <div className="space-y-6">
      <div className="card p-6">
        <h2 className="mb-4 font-semibold" style={{ color: "var(--sjr-ink)" }}>Informations générales</h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <Field label="Intitulé du poste" required full>
            <input className="field" value={f.title} onChange={(e) => set("title", e.target.value)} placeholder="ex. Agent technique polyvalent" />
          </Field>
          <Field label="Secteur">
            <select className="field" value={f.sector_id} onChange={(e) => setF((s) => ({ ...s, sector_id: e.target.value, direction_id: "", pole_id: "" }))}>
              <option value="">— Choisir —</option>
              {tree.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
            </select>
          </Field>
          <Field label="Direction">
            <select className="field" value={f.direction_id} onChange={(e) => setF((s) => ({ ...s, direction_id: e.target.value, pole_id: "" }))} disabled={!f.sector_id}>
              <option value="">— Choisir —</option>
              {directions.map((d) => <option key={d.id} value={d.id}>{d.name}</option>)}
            </select>
          </Field>
          <Field label="Pôle">
            <select className="field" value={f.pole_id} onChange={(e) => set("pole_id", e.target.value)} disabled={!f.direction_id}>
              <option value="">— Choisir —</option>
              {poles.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
            </select>
          </Field>
          <Field label="Type de contrat">
            <select className="field" value={f.contract_type} onChange={(e) => set("contract_type", e.target.value)}>
              <option value="">— Choisir —</option>
              {CONTRACT_TYPES.map((c) => <option key={c}>{c}</option>)}
            </select>
          </Field>
          <Field label="Temps de travail">
            <select className="field" value={f.work_time} onChange={(e) => set("work_time", e.target.value)}>
              <option value="">— Choisir —</option>
              {WORK_TIMES.map((w) => <option key={w}>{w}</option>)}
            </select>
          </Field>
          <Field label="Nombre de postes à pourvoir" required>
            <input className="field" type="number" min="1" value={f.positions_total} onChange={(e) => set("positions_total", e.target.value)} />
          </Field>
          <Field label="Date limite de candidature">
            <input className="field" type="date" value={f.deadline || ""} onChange={(e) => set("deadline", e.target.value)} />
          </Field>
          <Field label="Mots-clés (aident la recherche des candidats)" full>
            <input className="field" value={f.keywords} onChange={(e) => set("keywords", e.target.value)} placeholder="ex. maintenance, bâtiment, plomberie" />
          </Field>
        </div>
      </div>

      <div className="card p-6">
        <h2 className="mb-4 font-semibold" style={{ color: "var(--sjr-ink)" }}>Contenu de l'offre</h2>
        <div className="space-y-4">
          {[["missions", "Missions"], ["profile", "Profil recherché"], ["conditions", "Conditions"], ["extra_info", "Informations complémentaires"]].map(([k, label]) => (
            <div key={k}>
              <label className="field-label">{label}</label>
              <textarea className="field" value={f[k]} onChange={(e) => set(k, e.target.value)} placeholder={`Saisir ${label.toLowerCase()}…`} />
            </div>
          ))}
        </div>
      </div>

      {err && <p className="rounded-lg bg-rose-50 px-4 py-3 text-sm text-rose-700">{err}</p>}

      <div className="sticky bottom-4 flex flex-wrap items-center justify-end gap-3 rounded-xl2 border bg-white/95 p-3 shadow-card backdrop-blur" style={{ borderColor: "var(--sjr-line)" }}>
        <button className="btn-ghost" onClick={() => router.back()} disabled={!!busy}>Annuler</button>
        <button className="btn-outline" onClick={() => save("save")} disabled={!!busy}>
          {busy === "save" ? "Enregistrement…" : offerId ? "Enregistrer les modifications" : "Enregistrer en brouillon"}
        </button>
        {status === "publiee" ? (
          <button className="btn-outline" onClick={() => save("unpublish")} disabled={!!busy}>{busy === "unpublish" ? "…" : "Dépublier"}</button>
        ) : (
          <button className="btn-accent" onClick={() => save("publish")} disabled={!!busy}>
            {busy === "publish" ? "Publication…" : offerId ? "Enregistrer et publier" : "Publier"}
          </button>
        )}
      </div>
    </div>
  );
}
SJREOF

echo "=== 3 fichiers reecrits proprement ==="
