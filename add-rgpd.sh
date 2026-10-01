#!/usr/bin/env bash
# Ajoute les cases de consentement RGPD (formulaire + stockage + vue RH). À lancer à la racine du projet.
set -e

cat > "lib/db.js" << 'SJREOF'
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
    consent_processing INTEGER DEFAULT 0, consent_vivier INTEGER DEFAULT 0,
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
  // Colonnes ajoutées après coup (pour les bases déjà créées) : on ignore si déjà présentes.
  for (const sql of [
    "ALTER TABLE applications ADD COLUMN consent_processing INTEGER DEFAULT 0",
    "ALTER TABLE applications ADD COLUMN consent_vivier INTEGER DEFAULT 0",
  ]) {
    try { await client().execute(sql); } catch (e) { /* colonne déjà présente */ }
  }
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

cat > "lib/applications.js" << 'SJREOF'
import crypto from "crypto";
import { dbAll, dbGet, dbRun } from "./db.js";
import { getOffer, syncOffer } from "./offers.js";
import { APP_STATUS_LABEL, allowedTransitions } from "./constants.js";

export function publicRef() {
  const y = new Date().getFullYear();
  const r = crypto.randomBytes(3).toString("hex").toUpperCase();
  return `CAND-${y}-${r}`;
}

const APP_SELECT = `
  SELECT a.*, o.title AS offer_title, o.reference AS offer_reference,
    o.positions_total,
    s.name AS sector_name, d.name AS direction_name, p.name AS pole_name,
    (SELECT COUNT(*) FROM applications x WHERE x.offer_id=o.id AND x.status='recrute') AS positions_filled
  FROM applications a
  JOIN offers o ON o.id = a.offer_id
  LEFT JOIN sectors s ON s.id = o.sector_id
  LEFT JOIN directions d ON d.id = o.direction_id
  LEFT JOIN poles p ON p.id = o.pole_id
`;
const DOC_COLS = "id, application_id, kind, original_name, mime, size, created_at";

export async function addEvent(applicationId, type, message) {
  await dbRun("INSERT INTO events (application_id, type, message) VALUES (?,?,?)", [applicationId, type, message]);
}

export async function createApplication(offerId, data) {
  const offer = await getOffer(offerId);
  if (!offer) throw new Error("Offre introuvable");
  const ref = publicRef();
  const info = await dbRun(`
    INSERT INTO applications (public_ref, offer_id, civility, last_name, first_name,
      address, postal_code, city, email, phone, consent_processing, consent_vivier, status)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?, 'nouvelle')`,
    [ref, offerId, data.civility || null, data.last_name || "", data.first_name || "",
     data.address || null, data.postal_code || null, data.city || null,
     data.email || null, data.phone || null,
     data.consent_processing ? 1 : 0, data.consent_vivier ? 1 : 0]);
  const id = info.lastInsertRowid;
  await addEvent(id, "creation", "Candidature reçue — statut initial : Nouvelle candidature.");
  await addEvent(id, "email", "Accusé de réception envoyé au candidat (simulé).");
  return { id, public_ref: ref, offer };
}

// Les pièces sont stockées EN BASE (content = base64).
export async function saveDocument(app, kind, originalName, buffer, mime) {
  await dbRun(`
    INSERT INTO documents (application_id, kind, original_name, stored_path, content, mime, size)
    VALUES (?,?,?,?,?,?,?)`,
    [app.id, kind, originalName || kind, null, buffer.toString("base64"),
     mime || "application/octet-stream", buffer.length]);
}

export async function getApplication(id) {
  const app = await dbGet(APP_SELECT + " WHERE a.id = ?", [id]);
  if (!app) return null;
  app.positions_filled = Number(app.positions_filled) || 0;
  app.positions_remaining = Math.max(0, Number(app.positions_total) - app.positions_filled);
  app.documents = await dbAll(`SELECT ${DOC_COLS} FROM documents WHERE application_id=? ORDER BY id`, [id]);
  app.notes = await dbAll("SELECT * FROM notes WHERE application_id=? ORDER BY created_at DESC", [id]);
  app.events = await dbAll("SELECT * FROM events WHERE application_id=? ORDER BY created_at DESC, id DESC", [id]);
  app.status_label = APP_STATUS_LABEL[app.status];
  app.transitions = allowedTransitions(app.status);
  return app;
}

// Métadonnées seules (sans contenu) — pour l'affichage
export async function getDocument(docId) {
  return dbGet(`SELECT ${DOC_COLS} FROM documents WHERE id=?`, [docId]);
}
// Contenu binaire d'une pièce (téléchargement)
export async function getDocumentContent(docId) {
  const row = await dbGet("SELECT id, kind, original_name, mime, size, content FROM documents WHERE id=?", [docId]);
  if (!row) return null;
  row.buffer = row.content ? Buffer.from(row.content, "base64") : Buffer.alloc(0);
  return row;
}
// Toutes les pièces d'une candidature AVEC leur contenu (assemblage du dossier PDF)
export async function listDocumentsWithContent(applicationId) {
  const rows = await dbAll("SELECT id, kind, original_name, mime, size, content FROM documents WHERE application_id=? ORDER BY id", [applicationId]);
  return rows.map((d) => ({ ...d, buffer: d.content ? Buffer.from(d.content, "base64") : Buffer.alloc(0) }));
}

export async function listByOffer(offerId) {
  const rows = await dbAll(APP_SELECT + " WHERE a.offer_id=? ORDER BY a.created_at DESC", [offerId]);
  return rows.map((a) => ({ ...a, status_label: APP_STATUS_LABEL[a.status] }));
}

export async function listApplications({ status = null, statusIn = null, q = "" } = {}) {
  let rows = await dbAll(APP_SELECT + " ORDER BY a.created_at DESC");
  if (status) rows = rows.filter((a) => a.status === status);
  if (statusIn) rows = rows.filter((a) => statusIn.includes(a.status));
  const term = (q || "").trim().toLowerCase();
  if (term) rows = rows.filter((a) =>
    [a.first_name, a.last_name, a.offer_title, a.email, a.public_ref]
      .filter(Boolean).join(" ").toLowerCase().includes(term));
  return rows.map((a) => ({ ...a, status_label: APP_STATUS_LABEL[a.status] }));
}

export async function markOpened(id) {
  const app = await dbGet("SELECT status FROM applications WHERE id=?", [id]);
  if (app && app.status === "nouvelle") {
    await dbRun("UPDATE applications SET status='a_etudier', updated_at=datetime('now') WHERE id=?", [id]);
    await addEvent(id, "statut", "Candidature ouverte par la RH — Nouvelle candidature → À étudier.");
  }
}

export async function setStatus(id, newStatus) {
  const app = await dbGet("SELECT * FROM applications WHERE id=?", [id]);
  if (!app) throw new Error("Candidature introuvable");
  if (app.status === newStatus) return getApplication(id);
  if (!allowedTransitions(app.status).includes(newStatus)) {
    throw new Error(`Transition non autorisée : ${app.status} → ${newStatus}`);
  }
  if (newStatus === "recrute") {
    const offer = await getOffer(app.offer_id);
    if (offer.positions_remaining <= 0) throw new Error("Tous les postes de cette offre sont déjà pourvus.");
  }
  await dbRun("UPDATE applications SET status=?, updated_at=datetime('now') WHERE id=?", [newStatus, id]);
  await addEvent(id, "statut", `Statut : ${APP_STATUS_LABEL[app.status]} → ${APP_STATUS_LABEL[newStatus]}.`);
  if (newStatus === "recrute") await addEvent(id, "email", "Réponse positive envoyée au candidat (simulé).");
  if (newStatus === "refusee") await addEvent(id, "email", "Réponse négative envoyée au candidat (simulé).");
  await syncOffer(app.offer_id);
  return getApplication(id);
}

export async function addNote(id, body) {
  if (!body || !body.trim()) return;
  await dbRun("INSERT INTO notes (application_id, body) VALUES (?,?)", [id, body.trim()]);
  await addEvent(id, "note", "Note interne ajoutée.");
}
SJREOF

cat > "app/api/candidatures/route.js" << 'SJREOF'
import { NextResponse } from "next/server";
import { createApplication, getApplication, saveDocument } from "@/lib/applications";
import { getPublicOffer } from "@/lib/offers";
import { DOC_KINDS, MAX_FILE_MB, ACCEPTED_EXT } from "@/lib/constants";
import { syncApplication } from "@/lib/sheets";

export const runtime = "nodejs";

function extOk(name) {
  const i = (name || "").lastIndexOf(".");
  return i >= 0 && ACCEPTED_EXT.includes(name.slice(i).toLowerCase());
}

export async function POST(req) {
  try {
    const fd = await req.formData();
    const offerId = Number(fd.get("offer_id"));
    const offer = await getPublicOffer(offerId);
    if (!offer) return NextResponse.json({ error: "Cette offre n'est plus disponible." }, { status: 400 });

    const cv = fd.get("cv");
    if (!cv || typeof cv === "string" || cv.size === 0) {
      return NextResponse.json({ error: "Le CV est obligatoire." }, { status: 400 });
    }

    const consentProcessing = fd.get("consent_processing") === "1";
    if (!consentProcessing) {
      return NextResponse.json({ error: "Vous devez accepter le traitement de vos données pour postuler." }, { status: 400 });
    }
    const data = {
      civility: fd.get("civility"), last_name: fd.get("last_name"), first_name: fd.get("first_name"),
      address: fd.get("address"), postal_code: fd.get("postal_code"), city: fd.get("city"),
      email: fd.get("email"), phone: fd.get("phone"),
      consent_processing: consentProcessing,
      consent_vivier: fd.get("consent_vivier") === "1",
    };
    if (!data.last_name || !data.first_name) {
      return NextResponse.json({ error: "Nom et prénom obligatoires." }, { status: 400 });
    }

    const created = await createApplication(offerId, data);
    const app = await getApplication(created.id);

    for (const kind of Object.keys(DOC_KINDS)) {
      const file = fd.get(kind);
      if (!file || typeof file === "string" || file.size === 0) continue;
      if (!extOk(file.name)) return NextResponse.json({ error: `Format non accepté pour ${DOC_KINDS[kind].label}.` }, { status: 400 });
      if (file.size > MAX_FILE_MB * 1024 * 1024) return NextResponse.json({ error: `${DOC_KINDS[kind].label} : fichier trop volumineux.` }, { status: 400 });
      const buf = Buffer.from(await file.arrayBuffer());
      await saveDocument(app, kind, file.name, buf, file.type);
    }

    await syncApplication(await getApplication(created.id), "Candidature reçue");
    return NextResponse.json({ ok: true, public_ref: created.public_ref, id: created.id });
  } catch (e) {
    console.error("[candidatures POST]", e);
    return NextResponse.json({ error: "Une erreur est survenue lors de l'envoi." }, { status: 500 });
  }
}
SJREOF

cat > "app/components/ApplyForm.js" << 'SJREOF'
"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { IconCheck, IconDoc, IconArrowLeft } from "./Icons";
import { DOC_KINDS, MAX_FILE_MB, ACCEPTED_EXT } from "@/lib/constants";

const STEPS = ["Informations", "Documents", "Vérification"];
const FIELDS = [
  { name: "civility", label: "Civilité", type: "select", options: ["Madame", "Monsieur", "Autre"], required: true, half: true },
  { name: "last_name", label: "Nom", required: true, half: true },
  { name: "first_name", label: "Prénom", required: true, half: true },
  { name: "phone", label: "Téléphone", required: true, half: true },
  { name: "email", label: "Adresse e-mail", type: "email", required: true },
  { name: "address", label: "Adresse", required: true },
  { name: "postal_code", label: "Code postal", required: true, half: true },
  { name: "city", label: "Ville", required: true, half: true },
];

function extOk(name) {
  const dot = name.lastIndexOf(".");
  return dot >= 0 && ACCEPTED_EXT.includes(name.slice(dot).toLowerCase());
}

export default function ApplyForm({ offer }) {
  const router = useRouter();
  const [step, setStep] = useState(0);
  const [form, setForm] = useState({ civility: "Madame", last_name: "", first_name: "", phone: "", email: "", address: "", postal_code: "", city: "" });
  const [files, setFiles] = useState({});
  const [errors, setErrors] = useState({});
  const [certified, setCertified] = useState(false);
  const [consentProcessing, setConsentProcessing] = useState(false);
  const [consentVivier, setConsentVivier] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [serverError, setServerError] = useState("");

  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }));

  function validateStep1() {
    const e = {};
    for (const f of FIELDS) if (f.required && !form[f.name]?.trim()) e[f.name] = "Champ obligatoire";
    if (form.email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(form.email)) e.email = "E-mail invalide";
    if (form.postal_code && !/^\d{5}$/.test(form.postal_code)) e.postal_code = "5 chiffres attendus";
    setErrors(e);
    return Object.keys(e).length === 0;
  }
  function validateStep2() {
    const e = {};
    if (!files.cv) e.cv = "Le CV est obligatoire";
    for (const [kind, file] of Object.entries(files)) {
      if (!file) continue;
      if (!extOk(file.name)) e[kind] = "Format non accepté";
      else if (file.size > MAX_FILE_MB * 1024 * 1024) e[kind] = `Fichier trop volumineux (max ${MAX_FILE_MB} Mo)`;
    }
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  function next() {
    if (step === 0 && !validateStep1()) return;
    if (step === 1 && !validateStep2()) return;
    setStep((s) => Math.min(s + 1, 2));
  }
  function onFile(kind, file) {
    setFiles((prev) => ({ ...prev, [kind]: file || undefined }));
    setErrors((e) => ({ ...e, [kind]: undefined }));
  }

  async function submit() {
    if (!certified) { setServerError("Veuillez certifier l'exactitude des informations."); return; }
    if (!consentProcessing) { setServerError("Vous devez accepter le traitement de vos données pour postuler."); return; }
    setSubmitting(true); setServerError("");
    try {
      const fd = new FormData();
      fd.append("offer_id", String(offer.id));
      fd.append("consent_processing", consentProcessing ? "1" : "0");
      fd.append("consent_vivier", consentVivier ? "1" : "0");
      Object.entries(form).forEach(([k, v]) => fd.append(k, v));
      Object.entries(files).forEach(([kind, file]) => { if (file) fd.append(kind, file); });
      const res = await fetch("/api/candidatures", { method: "POST", body: fd });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Erreur lors de l'envoi.");
      router.push(`/candidature-envoyee?ref=${encodeURIComponent(data.public_ref)}`);
    } catch (err) {
      setServerError(err.message); setSubmitting(false);
    }
  }

  return (
    <div>
      {/* Progression */}
      <ol className="mb-6 flex items-center gap-2">
        {STEPS.map((label, i) => (
          <li key={label} className="flex flex-1 items-center gap-2">
            <span className={`grid h-8 w-8 shrink-0 place-items-center rounded-full text-sm font-semibold ${i < step ? "text-white" : i === step ? "text-white" : "bg-slate-100 text-slate-500"}`}
              style={i <= step ? { background: i < step ? "var(--sjr-accent)" : "var(--sjr-primary)" } : {}}>
              {i < step ? <IconCheck className="h-4 w-4" /> : i + 1}
            </span>
            <span className={`hidden text-sm sm:inline ${i === step ? "font-semibold" : ""}`} style={{ color: i <= step ? "var(--sjr-ink)" : "var(--sjr-muted)" }}>{label}</span>
            {i < STEPS.length - 1 && <span className="mx-1 h-px flex-1" style={{ background: "var(--sjr-line)" }} />}
          </li>
        ))}
      </ol>

      <div className="card p-6 md:p-8">
        {/* Étape 1 */}
        {step === 0 && (
          <div>
            <h2 className="text-lg font-semibold" style={{ color: "var(--sjr-ink)" }}>Vos informations personnelles</h2>
            <p className="mt-1 text-sm" style={{ color: "var(--sjr-muted)" }}>Le poste concerné est déjà associé à votre candidature.</p>
            <div className="mt-5 grid grid-cols-1 gap-4 sm:grid-cols-2">
              {FIELDS.map((f) => (
                <div key={f.name} className={f.half ? "" : "sm:col-span-2"}>
                  <label className="field-label">{f.label}{f.required && <span className="text-rose-500"> *</span>}</label>
                  {f.type === "select" ? (
                    <select className="field" value={form[f.name]} onChange={(e) => set(f.name, e.target.value)}>
                      {f.options.map((o) => <option key={o}>{o}</option>)}
                    </select>
                  ) : (
                    <input className="field" type={f.type || "text"} value={form[f.name]} onChange={(e) => set(f.name, e.target.value)} />
                  )}
                  {errors[f.name] && <p className="mt-1 text-xs text-rose-600">{errors[f.name]}</p>}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Étape 2 */}
        {step === 1 && (
          <div>
            <h2 className="text-lg font-semibold" style={{ color: "var(--sjr-ink)" }}>Vos documents</h2>
            <p className="mt-1 text-sm" style={{ color: "var(--sjr-muted)" }}>Formats acceptés : PDF, Word, image — {MAX_FILE_MB} Mo maximum par fichier.</p>
            <div className="mt-5 space-y-3">
              {Object.entries(DOC_KINDS).map(([kind, meta]) => (
                <div key={kind} className="rounded-lg border p-4" style={{ borderColor: errors[kind] ? "#f43f5e" : "var(--sjr-line)" }}>
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div className="flex items-center gap-3">
                      <IconDoc className="h-5 w-5" style={{ color: "var(--sjr-primary)" }} />
                      <div>
                        <div className="text-sm font-medium" style={{ color: "var(--sjr-ink)" }}>
                          {meta.label} <span className="text-xs font-normal" style={{ color: meta.required ? "#e11d48" : "var(--sjr-muted)" }}>({meta.hint})</span>
                        </div>
                        {files[kind] && <div className="text-xs text-emerald-600">✓ {files[kind].name}</div>}
                      </div>
                    </div>
                    <label className="btn-outline cursor-pointer text-xs">
                      {files[kind] ? "Remplacer" : "Choisir un fichier"}
                      <input type="file" className="hidden" accept={ACCEPTED_EXT.join(",")} onChange={(e) => onFile(kind, e.target.files?.[0])} />
                    </label>
                  </div>
                  {errors[kind] && <p className="mt-2 text-xs text-rose-600">{errors[kind]}</p>}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Étape 3 */}
        {step === 2 && (
          <div>
            <h2 className="text-lg font-semibold" style={{ color: "var(--sjr-ink)" }}>Vérification et envoi</h2>
            <div className="mt-4 rounded-lg p-4" style={{ background: "var(--sjr-primary-soft)" }}>
              <div className="text-xs" style={{ color: "var(--sjr-primary-dark)" }}>Vous candidatez au poste</div>
              <div className="text-base font-semibold" style={{ color: "var(--sjr-ink)" }}>{offer.title}</div>
              <div className="text-sm" style={{ color: "var(--sjr-muted)" }}>{offer.positions_total} poste{offer.positions_total > 1 ? "s" : ""} à pourvoir · {offer.contract_type} · {offer.location}</div>
            </div>

            <dl className="mt-5 grid grid-cols-1 gap-x-6 gap-y-2 text-sm sm:grid-cols-2">
              {FIELDS.map((f) => (
                <div key={f.name} className="flex justify-between gap-4 border-b py-1.5" style={{ borderColor: "var(--sjr-line)" }}>
                  <dt style={{ color: "var(--sjr-muted)" }}>{f.label}</dt>
                  <dd className="text-right font-medium" style={{ color: "var(--sjr-ink)" }}>{form[f.name] || "—"}</dd>
                </div>
              ))}
            </dl>

            <div className="mt-4">
              <div className="text-sm font-medium" style={{ color: "var(--sjr-ink)" }}>Documents joints</div>
              <ul className="mt-1 text-sm" style={{ color: "var(--sjr-muted)" }}>
                {Object.entries(DOC_KINDS).map(([kind, meta]) =>
                  files[kind] ? <li key={kind}>✓ {meta.label} — {files[kind].name}</li> : null
                )}
              </ul>
            </div>

            <label className="mt-5 flex items-start gap-3 rounded-lg border p-4" style={{ borderColor: "var(--sjr-line)" }}>
              <input type="checkbox" checked={certified} onChange={(e) => setCertified(e.target.checked)} className="mt-0.5 h-4 w-4" />
              <span className="text-sm" style={{ color: "var(--sjr-ink)" }}>Je certifie l'exactitude des informations renseignées.</span>
            </label>

            <label className="mt-3 flex items-start gap-3 rounded-lg border p-4" style={{ borderColor: "var(--sjr-line)" }}>
              <input type="checkbox" checked={consentProcessing} onChange={(e) => setConsentProcessing(e.target.checked)} className="mt-0.5 h-4 w-4" />
              <span className="text-sm" style={{ color: "var(--sjr-ink)" }}>
                J'accepte que les informations et documents transmis soient traités par la Ville de Saint-Jean-de-la-Ruelle
                dans le cadre de l'étude de ma candidature. <span className="text-rose-500">*</span>
              </span>
            </label>

            <label className="mt-3 flex items-start gap-3 rounded-lg border p-4" style={{ borderColor: "var(--sjr-line)" }}>
              <input type="checkbox" checked={consentVivier} onChange={(e) => setConsentVivier(e.target.checked)} className="mt-0.5 h-4 w-4" />
              <span className="text-sm" style={{ color: "var(--sjr-ink)" }}>
                J'accepte que ma candidature soit conservée en vivier (CVthèque) pendant 2 ans,
                afin d'être recontacté(e) pour d'autres postes. <span style={{ color: "var(--sjr-muted)" }}>(facultatif)</span>
              </span>
            </label>

            <p className="mt-3 text-xs" style={{ color: "var(--sjr-muted)" }}>
              Conformément au RGPD, vous disposez d'un droit d'accès, de rectification et de suppression de vos données.
              Sans conservation en vivier, votre candidature sera supprimée à l'issue du recrutement.
            </p>
            {serverError && <p className="mt-3 rounded-lg bg-rose-50 px-3 py-2 text-sm text-rose-700">{serverError}</p>}
          </div>
        )}

        {/* Navigation */}
        <div className="mt-6 flex items-center justify-between border-t pt-5" style={{ borderColor: "var(--sjr-line)" }}>
          <button className="btn-ghost" onClick={() => (step === 0 ? router.back() : setStep((s) => s - 1))} disabled={submitting}>
            <IconArrowLeft className="h-4 w-4" /> {step === 0 ? "Annuler" : "Précédent"}
          </button>
          {step < 2 ? (
            <button className="btn-primary" onClick={next}>Continuer</button>
          ) : (
            <button className="btn-accent" onClick={submit} disabled={submitting}>{submitting ? "Envoi…" : "Envoyer ma candidature"}</button>
          )}
        </div>
      </div>
    </div>
  );
}
SJREOF

cat > "app/admin/(dash)/candidatures/[id]/page.js" << 'SJREOF'
import Link from "next/link";
import { notFound } from "next/navigation";
import { AppBadge } from "@/app/components/StatusBadge";
import StatusChanger from "@/app/components/StatusChanger";
import NoteForm from "@/app/components/NoteForm";
import PositionMeter from "@/app/components/PositionMeter";
import { IconArrowLeft, IconDoc, IconDownload } from "@/app/components/Icons";
import { getApplication, markOpened } from "@/lib/applications";
import { DOC_KINDS } from "@/lib/constants";
import { fmtDate, fmtDateTime, fmtBytes, initials } from "@/lib/format";

export const dynamic = "force-dynamic";

function Info({ label, value }) {
  return (
    <div className="flex justify-between gap-4 border-b py-2 text-sm" style={{ borderColor: "var(--sjr-line)" }}>
      <span style={{ color: "var(--sjr-muted)" }}>{label}</span>
      <span className="text-right font-medium" style={{ color: "var(--sjr-ink)" }}>{value || "—"}</span>
    </div>
  );
}

export default async function CandidatureDetail({ params }) {
  const id = Number(params.id);
  await markOpened(id); // ouverture d'une candidature "nouvelle" -> passe en "à étudier"
  const a = await getApplication(id);
  if (!a) notFound();

  return (
    <div>
      <Link href="/admin/candidatures" className="link inline-flex items-center gap-1.5 text-sm"><IconArrowLeft className="h-4 w-4" /> Retour aux candidatures</Link>

      <div className="mt-3 flex flex-wrap items-start justify-between gap-4">
        <div className="flex items-center gap-3">
          <span className="grid h-12 w-12 place-items-center rounded-full text-sm font-bold" style={{ background: "var(--sjr-primary-soft)", color: "var(--sjr-primary-dark)" }}>{initials(a.first_name, a.last_name)}</span>
          <div>
            <h1 className="text-2xl font-bold" style={{ color: "var(--sjr-ink)" }}>{a.civility ? a.civility + " " : ""}{a.first_name} {a.last_name}</h1>
            <p className="text-sm" style={{ color: "var(--sjr-muted)" }}>{a.public_ref} · candidature reçue le {fmtDateTime(a.created_at)}</p>
          </div>
        </div>
        <AppBadge status={a.status} />
      </div>

      <div className="mt-5 grid gap-6 lg:grid-cols-[1fr_320px]">
        {/* Colonne principale */}
        <div className="space-y-6">
          {/* Offre associée (renseignée automatiquement) */}
          <section className="card p-5">
            <h2 className="mb-3 font-semibold" style={{ color: "var(--sjr-ink)" }}>Poste concerné</h2>
            <Link href={`/admin/offres/${a.offer_id}`} className="link text-base font-semibold">{a.offer_title}</Link>
            <div className="mt-3 grid grid-cols-1 sm:grid-cols-2">
              <Info label="Référence de l'offre" value={a.offer_reference} />
              <Info label="Secteur" value={a.sector_name} />
              <Info label="Direction" value={a.direction_name} />
              <Info label="Pôle" value={a.pole_name} />
            </div>
            <div className="mt-3"><PositionMeter total={a.positions_total} filled={a.positions_filled} remaining={a.positions_remaining} size="sm" /></div>
          </section>

          {/* Coordonnées candidat */}
          <section className="card p-5">
            <h2 className="mb-3 font-semibold" style={{ color: "var(--sjr-ink)" }}>Coordonnées du candidat</h2>
            <div className="grid grid-cols-1 sm:grid-cols-2">
              <Info label="E-mail" value={a.email} />
              <Info label="Téléphone" value={a.phone} />
              <Info label="Adresse" value={a.address} />
              <Info label="Code postal / Ville" value={[a.postal_code, a.city].filter(Boolean).join(" ")} />
            </div>
            <div className="mt-3 flex flex-wrap gap-2 border-t pt-3" style={{ borderColor: "var(--sjr-line)" }}>
              <span className="badge" style={{ background: "#e6f4ea", color: "#137333" }}>✓ Traitement accepté</span>
              {a.consent_vivier
                ? <span className="badge" style={{ background: "#e8f0fe", color: "#1967d2" }}>✓ Conservation en vivier (2 ans) acceptée</span>
                : <span className="badge" style={{ background: "#fde8e8", color: "#b4231f" }}>✗ Vivier refusé — à supprimer après recrutement</span>}
            </div>
          </section>

          {/* Documents */}
          <section className="card p-5">
            <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
              <h2 className="font-semibold" style={{ color: "var(--sjr-ink)" }}>Documents transmis</h2>
              {a.documents.length > 0 && (
                <a href={`/api/admin/candidatures/${a.id}/dossier`} className="btn-accent text-xs">
                  <IconDownload className="h-4 w-4" /> Dossier complet (PDF)
                </a>
              )}
            </div>
            <div className="space-y-2">
              {a.documents.length === 0 && <p className="text-sm" style={{ color: "var(--sjr-muted)" }}>Aucun document.</p>}
              {a.documents.map((d) => (
                <div key={d.id} className="flex items-center gap-3 rounded-lg border p-3" style={{ borderColor: "var(--sjr-line)" }}>
                  <IconDoc className="h-5 w-5 shrink-0" style={{ color: "var(--sjr-primary)" }} />
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-sm font-medium" style={{ color: "var(--sjr-ink)" }}>{DOC_KINDS[d.kind]?.label || d.kind}</div>
                    <div className="truncate text-xs" style={{ color: "var(--sjr-muted)" }}>{d.original_name} · {fmtBytes(d.size)}</div>
                  </div>
                  <a href={`/api/admin/documents/${d.id}`} target="_blank" className="btn-ghost text-xs">Aperçu</a>
                  <a href={`/api/admin/documents/${d.id}?dl=1`} className="btn-outline text-xs"><IconDownload className="h-4 w-4" /> Télécharger</a>
                </div>
              ))}
            </div>
          </section>

          {/* Notes internes */}
          <section className="card p-5">
            <h2 className="mb-3 font-semibold" style={{ color: "var(--sjr-ink)" }}>Notes internes</h2>
            <div className="mb-4"><NoteForm id={a.id} /></div>
            <div className="space-y-3">
              {a.notes.length === 0 && <p className="text-sm" style={{ color: "var(--sjr-muted)" }}>Aucune note pour l'instant.</p>}
              {a.notes.map((n) => (
                <div key={n.id} className="rounded-lg p-3" style={{ background: "#f8fafc", border: "1px solid var(--sjr-line)" }}>
                  <div className="whitespace-pre-wrap text-sm" style={{ color: "var(--sjr-ink)" }}>{n.body}</div>
                  <div className="mt-1 text-xs" style={{ color: "var(--sjr-muted)" }}>{fmtDateTime(n.created_at)}</div>
                </div>
              ))}
            </div>
          </section>
        </div>

        {/* Colonne latérale : workflow + timeline */}
        <div className="space-y-6">
          <section className="card p-5">
            <h2 className="mb-1 font-semibold" style={{ color: "var(--sjr-ink)" }}>Faire évoluer la candidature</h2>
            <p className="mb-4 text-xs" style={{ color: "var(--sjr-muted)" }}>Statut actuel : <b>{a.status_label}</b></p>
            <StatusChanger id={a.id} status={a.status} />
            <p className="mt-4 text-[11px] leading-relaxed" style={{ color: "var(--sjr-muted)" }}>
              « Retenue » n'affecte pas le nombre de postes. Seul le passage à « Recruté » décompte un poste et peut clôturer l'offre.
            </p>
          </section>

          <section className="card p-5">
            <h2 className="mb-3 font-semibold" style={{ color: "var(--sjr-ink)" }}>Historique</h2>
            <ol className="relative space-y-4 border-l pl-4" style={{ borderColor: "var(--sjr-line)" }}>
              {a.events.map((e) => (
                <li key={e.id} className="relative">
                  <span className="absolute -left-[21px] top-1 h-2.5 w-2.5 rounded-full" style={{ background: e.type === "email" ? "var(--sjr-accent)" : e.type === "status" ? "var(--sjr-primary)" : "#94a3b8" }} />
                  <div className="text-sm" style={{ color: "var(--sjr-ink)" }}>{e.message}</div>
                  <div className="text-xs" style={{ color: "var(--sjr-muted)" }}>{fmtDateTime(e.created_at)}</div>
                </li>
              ))}
            </ol>
          </section>
        </div>
      </div>
    </div>
  );
}
SJREOF

echo "=== RGPD installé. Lance : npm run build ==="
