#!/usr/bin/env bash
# Correctifs de securite & qualite (audit du 09/11/2026) :
#  - Auth reelle sur toutes les API admin
#  - Retrait des secrets en dur (Google Sheets, mot de passe admin)
#  - Next >= 14.2.25, expiration des sessions, anti-spam (honeypot), logs nettoyes
#  - Correctif URL offre non numerique
# A lancer a la racine du projet, puis : npm install && npm run build && git add -A && commit && push.
set -e

mkdir -p "$(dirname "app/api/admin/candidatures/[id]/dossier/route.js")"
cat > "app/api/admin/candidatures/[id]/dossier/route.js" << 'SJR_EOF_7f3c'
import { NextResponse } from "next/server";
import { unauthorized } from "@/lib/auth";
import { getApplication, listDocumentsWithContent } from "@/lib/applications";
import { buildDossierPdf } from "@/lib/dossier";

export const runtime = "nodejs";

function slug(s) { return String(s || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-zA-Z0-9]+/g, "_").replace(/^_|_$/g, ""); }

export async function GET(_req, { params }) {
  const deny = await unauthorized(); if (deny) return deny;
  const app = await getApplication(Number(params.id));
  if (!app) return NextResponse.json({ error: "Candidature introuvable" }, { status: 404 });
  const docs = await listDocumentsWithContent(app.id);
  const pdf = await buildDossierPdf(app, docs);
  const name = `Dossier_${slug(app.last_name)}_${slug(app.first_name)}_${app.public_ref}.pdf`;
  return new NextResponse(pdf, {
    headers: {
      "Content-Type": "application/pdf",
      "Content-Disposition": `attachment; filename="${name}"`,
      "Content-Length": String(pdf.length),
    },
  });
}
SJR_EOF_7f3c

mkdir -p "$(dirname "app/api/admin/candidatures/[id]/notes/route.js")"
cat > "app/api/admin/candidatures/[id]/notes/route.js" << 'SJR_EOF_7f3c'
import { NextResponse } from "next/server";
import { unauthorized } from "@/lib/auth";
import { addNote } from "@/lib/applications";

export const runtime = "nodejs";

export async function POST(req, { params }) {
  const deny = await unauthorized(); if (deny) return deny;
  const { body } = await req.json().catch(() => ({}));
  if (!body || !body.trim()) return NextResponse.json({ error: "Note vide" }, { status: 400 });
  await addNote(Number(params.id), body);
  return NextResponse.json({ ok: true });
}
SJR_EOF_7f3c

mkdir -p "$(dirname "app/api/admin/candidatures/[id]/status/route.js")"
cat > "app/api/admin/candidatures/[id]/status/route.js" << 'SJR_EOF_7f3c'
import { NextResponse } from "next/server";
import { unauthorized } from "@/lib/auth";
import { setStatus, getApplication } from "@/lib/applications";
import { syncApplication } from "@/lib/sheets";

export const runtime = "nodejs";

export async function POST(req, { params }) {
  const deny = await unauthorized(); if (deny) return deny;
  const { status } = await req.json().catch(() => ({}));
  try {
    const updated = await setStatus(Number(params.id), status);
    const app = await getApplication(updated.id);
    await syncApplication(app, `Étape : ${app.status_label}`);
    return NextResponse.json({ ok: true, status: updated.status });
  } catch (e) {
    return NextResponse.json({ error: e.message }, { status: 400 });
  }
}
SJR_EOF_7f3c

mkdir -p "$(dirname "app/api/admin/candidatures/export-zip/route.js")"
cat > "app/api/admin/candidatures/export-zip/route.js" << 'SJR_EOF_7f3c'
import { NextResponse } from "next/server";
import { unauthorized } from "@/lib/auth";
import { listApplications } from "@/lib/applications";
import { buildApplicationsZip } from "@/lib/zip";

export const runtime = "nodejs";

const IN_PROGRESS = ["a_etudier", "preselectionnee", "entretien", "retenue"];

export async function GET(req) {
  const deny = await unauthorized(); if (deny) return deny;
  const sp = req.nextUrl.searchParams;
  const statut = sp.get("statut") || "";
  const offre = sp.get("offre") || "";

  let filter = {};
  if (statut === "en_cours") filter.statusIn = IN_PROGRESS;
  else if (statut) filter.status = statut;
  let rows = await listApplications(filter);
  if (offre) rows = rows.filter((a) => String(a.offer_id) === String(offre));

  const buf = await buildApplicationsZip(rows);
  const date = new Date().toISOString().slice(0, 10);
  return new NextResponse(buf, {
    headers: {
      "Content-Type": "application/zip",
      "Content-Disposition": `attachment; filename="Dossiers_SJR_${date}.zip"`,
      "Content-Length": String(buf.length),
    },
  });
}
SJR_EOF_7f3c

mkdir -p "$(dirname "app/api/admin/candidatures/export/route.js")"
cat > "app/api/admin/candidatures/export/route.js" << 'SJR_EOF_7f3c'
import { NextResponse } from "next/server";
import { unauthorized } from "@/lib/auth";
import { listApplications, getApplication } from "@/lib/applications";
import { buildApplicationsWorkbook } from "@/lib/exportXlsx";

export const runtime = "nodejs";

const IN_PROGRESS = ["a_etudier", "preselectionnee", "entretien", "retenue"];

export async function GET(req) {
  const deny = await unauthorized(); if (deny) return deny;
  const sp = req.nextUrl.searchParams;
  const statut = sp.get("statut") || "";
  const offre = sp.get("offre") || "";

  let filter = {};
  if (statut === "en_cours") filter.statusIn = IN_PROGRESS;
  else if (statut) filter.status = statut;
  let rows = await listApplications(filter);
  if (offre) rows = rows.filter((a) => String(a.offer_id) === String(offre));

  // enrichir : types de documents + collecte de l'historique détaillé
  const history = [];
  const enriched = [];
  for (const a of rows) {
    const full = await getApplication(a.id);
    if (full) {
      for (const ev of [...full.events].reverse()) {
        history.push({
          ref: a.public_ref, last_name: a.last_name, first_name: a.first_name,
          offer_title: a.offer_title, created_at: ev.created_at, message: ev.message, type: ev.type,
        });
      }
    }
    enriched.push({ ...a, doc_kinds: full ? full.documents.map((d) => d.kind) : [] });
  }
  rows = enriched;

  const buf = buildApplicationsWorkbook(rows, history);
  const date = new Date().toISOString().slice(0, 10);
  return new NextResponse(buf, {
    headers: {
      "Content-Type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "Content-Disposition": `attachment; filename="Candidatures_SJR_${date}.xlsx"`,
      "Content-Length": String(buf.length),
    },
  });
}
SJR_EOF_7f3c

mkdir -p "$(dirname "app/api/admin/documents/[id]/route.js")"
cat > "app/api/admin/documents/[id]/route.js" << 'SJR_EOF_7f3c'
import { NextResponse } from "next/server";
import { unauthorized } from "@/lib/auth";
import { getDocumentContent } from "@/lib/applications";

export const runtime = "nodejs";

export async function GET(req, { params }) {
  const deny = await unauthorized(); if (deny) return deny;
  const doc = await getDocumentContent(Number(params.id));
  if (!doc) return NextResponse.json({ error: "Document introuvable" }, { status: 404 });
  const data = doc.buffer;
  const download = req.nextUrl.searchParams.get("dl") === "1";
  return new NextResponse(data, {
    headers: {
      "Content-Type": doc.mime || "application/octet-stream",
      "Content-Disposition": `${download ? "attachment" : "inline"}; filename="${encodeURIComponent(doc.original_name || "document")}"`,
      "Content-Length": String(data.length),
    },
  });
}
SJR_EOF_7f3c

mkdir -p "$(dirname "app/api/admin/offres/[id]/route.js")"
cat > "app/api/admin/offres/[id]/route.js" << 'SJR_EOF_7f3c'
import { NextResponse } from "next/server";
import { unauthorized } from "@/lib/auth";
import { updateOffer, publishOffer, unpublishOffer, getOffer } from "@/lib/offers";

export const runtime = "nodejs";

export async function PATCH(req, { params }) {
  const deny = await unauthorized(); if (deny) return deny;
  const id = Number(params.id);
  const body = await req.json().catch(() => ({}));
  if (body.action === "publish") { const o = await publishOffer(id); return NextResponse.json({ ok: true, status: o.status }); }
  if (body.action === "unpublish") { const o = await unpublishOffer(id); return NextResponse.json({ ok: true, status: o.status }); }
  const o = await updateOffer(id, body);
  if (!o) return NextResponse.json({ error: "Offre introuvable" }, { status: 404 });
  return NextResponse.json({ ok: true, status: o.status });
}

export async function GET(_req, { params }) {
  const deny = await unauthorized(); if (deny) return deny;
  const o = await getOffer(Number(params.id));
  if (!o) return NextResponse.json({ error: "Offre introuvable" }, { status: 404 });
  return NextResponse.json(o);
}
SJR_EOF_7f3c

mkdir -p "$(dirname "app/api/admin/offres/route.js")"
cat > "app/api/admin/offres/route.js" << 'SJR_EOF_7f3c'
import { NextResponse } from "next/server";
import { unauthorized } from "@/lib/auth";
import { createOffer } from "@/lib/offers";

export const runtime = "nodejs";

export async function POST(req) {
  const deny = await unauthorized(); if (deny) return deny;
  const body = await req.json().catch(() => ({}));
  const publish = body.action === "publish";
  const offer = await createOffer(body, { publish });
  return NextResponse.json({ ok: true, id: offer.id, status: offer.status });
}
SJR_EOF_7f3c

mkdir -p "$(dirname "app/api/admin/parametres/route.js")"
cat > "app/api/admin/parametres/route.js" << 'SJR_EOF_7f3c'
import { NextResponse } from "next/server";
import { unauthorized } from "@/lib/auth";
import * as T from "@/lib/taxonomy";

export const runtime = "nodejs";

const MAP = {
  sector: { create: (b) => T.createSector(b.name), rename: (b) => T.renameSector(b.id, b.name), delete: (b) => T.deleteSector(b.id) },
  direction: { create: (b) => T.createDirection(b.parentId, b.name), rename: (b) => T.renameDirection(b.id, b.name), delete: (b) => T.deleteDirection(b.id) },
  pole: { create: (b) => T.createPole(b.parentId, b.name), rename: (b) => T.renamePole(b.id, b.name), delete: (b) => T.deletePole(b.id) },
};

export async function POST(req) {
  const deny = await unauthorized(); if (deny) return deny;
  try {
    const b = await req.json();
    const fn = MAP[b.level]?.[b.op];
    if (!fn) throw new Error("Opération inconnue.");
    const id = await fn(b);
    return NextResponse.json({ ok: true, id: id ?? null });
  } catch (e) {
    return NextResponse.json({ ok: false, error: e.message }, { status: 400 });
  }
}
SJR_EOF_7f3c

mkdir -p "$(dirname "app/api/admin/purge/route.js")"
cat > "app/api/admin/purge/route.js" << 'SJR_EOF_7f3c'
import { NextResponse } from "next/server";
import { unauthorized } from "@/lib/auth";
import { listPurgeable, purgeExpired } from "@/lib/purge";

export const runtime = "nodejs";

export async function GET() {
  const deny = await unauthorized(); if (deny) return deny;
  const preview = await listPurgeable();
  return NextResponse.json({ ok: true, ...preview });
}

export async function POST() {
  const deny = await unauthorized(); if (deny) return deny;
  const res = await purgeExpired();
  return NextResponse.json({ ok: true, ...res });
}
SJR_EOF_7f3c

mkdir -p "$(dirname "app/api/candidatures/route.js")"
cat > "app/api/candidatures/route.js" << 'SJR_EOF_7f3c'
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

    // Anti-spam : si le champ piège "website" est rempli, c'est un robot.
    // On renvoie un faux succès (le robot n'insiste pas) sans rien enregistrer.
    if (fd.get("website")) return NextResponse.json({ ok: true, public_ref: "—" });

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

    if (offer.diploma_required) {
      const diplomas = fd.getAll("diplome").filter((f) => f && typeof f !== "string" && f.size > 0);
      if (diplomas.length === 0) {
        return NextResponse.json({ error: `Le diplôme demandé est obligatoire${offer.diploma_label ? ` : ${offer.diploma_label}` : ""}.` }, { status: 400 });
      }
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
      for (const file of fd.getAll(kind)) {
        if (!file || typeof file === "string" || file.size === 0) continue;
        if (!extOk(file.name)) return NextResponse.json({ error: `Format non accepté pour ${DOC_KINDS[kind].label}.` }, { status: 400 });
        if (file.size > MAX_FILE_MB * 1024 * 1024) return NextResponse.json({ error: `${DOC_KINDS[kind].label} : fichier trop volumineux.` }, { status: 400 });
        const buf = Buffer.from(await file.arrayBuffer());
        await saveDocument(app, kind, file.name, buf, file.type);
      }
    }

    await syncApplication(await getApplication(created.id), "Candidature reçue");
    return NextResponse.json({ ok: true, public_ref: created.public_ref, id: created.id, edit_token: created.edit_token });
  } catch (e) {
    console.error("[candidatures POST]", e);
    return NextResponse.json({ error: "Une erreur est survenue lors de l'envoi." }, { status: 500 });
  }
}
SJR_EOF_7f3c

mkdir -p "$(dirname "app/components/ApplyForm.js")"
cat > "app/components/ApplyForm.js" << 'SJR_EOF_7f3c'
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

export default function ApplyForm({ offer, mode = "create", initial = null, existingDocs = [], token = null }) {
  const router = useRouter();
  const isEdit = mode === "edit";
  const [step, setStep] = useState(0);
  const [form, setForm] = useState({
    civility: initial?.civility || "Madame",
    last_name: initial?.last_name || "",
    first_name: initial?.first_name || "",
    phone: initial?.phone || "",
    email: initial?.email || "",
    address: initial?.address || "",
    postal_code: initial?.postal_code || "",
    city: initial?.city || "",
  });
  const [files, setFiles] = useState({});
  const [removedDocIds, setRemovedDocIds] = useState([]);
  const [isAgent, setIsAgent] = useState(existingDocs.some((d) => d.kind === "entretiens"));
  const [errors, setErrors] = useState({});
  const [certified, setCertified] = useState(false);
  const [consentProcessing, setConsentProcessing] = useState(isEdit);
  const [consentVivier, setConsentVivier] = useState(isEdit ? !!initial?.consent_vivier : false);
  const [submitting, setSubmitting] = useState(false);
  const [serverError, setServerError] = useState("");
  const [hp, setHp] = useState(""); // champ piège anti-spam (honeypot)

  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }));
  const existingByKind = (kind) => existingDocs.filter((d) => d.kind === kind && !removedDocIds.includes(d.id));

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
    const cvCount = (files.cv?.length || 0) + existingByKind("cv").length;
    if (cvCount === 0) e.cv = "Le CV est obligatoire";
    const dipCount = (files.diplome?.length || 0) + existingByKind("diplome").length;
    if (offer.diploma_required && dipCount === 0) {
      e.diplome = `Le diplôme demandé est obligatoire${offer.diploma_label ? ` : ${offer.diploma_label}` : ""}`;
    }
    for (const [kind, arr] of Object.entries(files)) {
      for (const file of arr || []) {
        if (!extOk(file.name)) { e[kind] = "Format non accepté"; break; }
        if (file.size > MAX_FILE_MB * 1024 * 1024) { e[kind] = `Fichier trop volumineux (max ${MAX_FILE_MB} Mo)`; break; }
      }
    }
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  function next() {
    if (step === 0 && !validateStep1()) return;
    if (step === 1 && !validateStep2()) return;
    setStep((s) => Math.min(s + 1, 2));
  }
  function addFiles(kind, list) {
    const incoming = Array.from(list || []).filter(Boolean);
    if (incoming.length === 0) return;
    setFiles((prev) => {
      const cur = prev[kind] || [];
      const multi = DOC_KINDS[kind]?.multiple;
      return { ...prev, [kind]: multi ? [...cur, ...incoming] : [incoming[0]] };
    });
    setErrors((e) => ({ ...e, [kind]: undefined }));
  }
  function removeFile(kind, idx) {
    setFiles((prev) => {
      const cur = [...(prev[kind] || [])];
      cur.splice(idx, 1);
      const next = { ...prev };
      if (cur.length) next[kind] = cur; else delete next[kind];
      return next;
    });
  }
  function clearKind(kind) {
    setFiles((prev) => { const n = { ...prev }; delete n[kind]; return n; });
  }
  function removeExisting(docId) {
    setRemovedDocIds((prev) => (prev.includes(docId) ? prev : [...prev, docId]));
  }
  // Libellé/obligation du champ "diplôme" pilotés par l'offre.
  function kindMeta(kind, meta) {
    if (kind === "diplome" && offer.diploma_label) {
      return {
        label: `Diplôme demandé : ${offer.diploma_label}`,
        required: !!offer.diploma_required,
        hint: offer.diploma_required ? "obligatoire" : "facultatif",
        multiple: true,
      };
    }
    return meta;
  }

  async function submit() {
    if (!certified) { setServerError("Veuillez certifier l'exactitude des informations."); return; }
    if (!consentProcessing) { setServerError("Vous devez accepter le traitement de vos données pour postuler."); return; }
    setSubmitting(true); setServerError("");
    try {
      const fd = new FormData();
      fd.append("consent_vivier", consentVivier ? "1" : "0");
      Object.entries(form).forEach(([k, v]) => fd.append(k, v));
      Object.entries(files).forEach(([kind, arr]) => (arr || []).forEach((file) => fd.append(kind, file)));

      if (isEdit) {
        removedDocIds.forEach((id) => fd.append("removed_doc_ids", String(id)));
        const res = await fetch(`/api/candidatures/${token}`, { method: "PUT", body: fd });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || "Erreur lors de l'enregistrement.");
        router.push(`/ma-candidature/${token}?saved=1`);
        router.refresh();
      } else {
        fd.append("offer_id", String(offer.id));
        fd.append("consent_processing", consentProcessing ? "1" : "0");
        fd.append("website", hp);
        const res = await fetch("/api/candidatures", { method: "POST", body: fd });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || "Erreur lors de l'envoi.");
        router.push(`/candidature-envoyee?ref=${encodeURIComponent(data.public_ref)}${data.edit_token ? `&t=${encodeURIComponent(data.edit_token)}` : ""}`);
      }
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
        {/* Anti-spam : champ piège invisible — un humain ne le voit pas, un robot le remplit. */}
        <input type="text" name="website" tabIndex={-1} autoComplete="off" aria-hidden="true"
          value={hp} onChange={(e) => setHp(e.target.value)}
          style={{ position: "absolute", left: "-9999px", top: 0, width: 1, height: 1, opacity: 0 }} />
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

            <label className="mt-4 flex items-center gap-3 rounded-lg border p-4" style={{ borderColor: "var(--sjr-line)", background: "var(--sjr-primary-soft)" }}>
              <input type="checkbox" checked={isAgent} onChange={(e) => { const v = e.target.checked; setIsAgent(v); if (!v) { clearKind("entretiens"); existingByKind("entretiens").forEach((d) => removeExisting(d.id)); } }} className="h-4 w-4" />
              <span className="text-sm" style={{ color: "var(--sjr-ink)" }}>
                Je suis déjà agent / fonctionnaire titulaire en collectivité
              </span>
            </label>

            <div className="mt-5 space-y-3">
              {Object.entries(DOC_KINDS).filter(([kind, meta]) => !meta.agentOnly || isAgent).map(([kind, rawMeta]) => {
                const meta = kindMeta(kind, rawMeta);
                const chosen = files[kind] || [];
                const existing = existingByKind(kind);
                return (
                  <div key={kind} className="rounded-lg border p-4" style={{ borderColor: errors[kind] ? "#f43f5e" : "var(--sjr-line)" }}>
                    <div className="flex flex-wrap items-center justify-between gap-3">
                      <div className="flex items-center gap-3">
                        <IconDoc className="h-5 w-5" style={{ color: "var(--sjr-primary)" }} />
                        <div className="text-sm font-medium" style={{ color: "var(--sjr-ink)" }}>
                          {meta.label} <span className="text-xs font-normal" style={{ color: meta.required ? "#e11d48" : "var(--sjr-muted)" }}>({meta.hint})</span>
                        </div>
                      </div>
                      <label className="btn-outline cursor-pointer text-xs">
                        {meta.multiple ? "Ajouter un/des fichier(s)" : ((chosen.length || existing.length) ? "Remplacer" : "Choisir un fichier")}
                        <input type="file" className="hidden" multiple={!!meta.multiple} accept={ACCEPTED_EXT.join(",")} onChange={(e) => { addFiles(kind, e.target.files); e.target.value = ""; }} />
                      </label>
                    </div>
                    {(existing.length > 0 || chosen.length > 0) && (
                      <ul className="mt-3 space-y-1.5">
                        {existing.map((d) => (
                          <li key={`e${d.id}`} className="flex items-center justify-between gap-3 rounded-md px-2.5 py-1.5" style={{ background: "#f1f5f9" }}>
                            <span className="truncate text-xs" style={{ color: "var(--sjr-muted)" }}>📎 {d.original_name} <span className="opacity-70">(déjà envoyé)</span></span>
                            <button type="button" className="shrink-0 text-xs text-rose-600 hover:underline" onClick={() => removeExisting(d.id)}>Retirer</button>
                          </li>
                        ))}
                        {chosen.map((file, idx) => (
                          <li key={`n${idx}`} className="flex items-center justify-between gap-3 rounded-md px-2.5 py-1.5" style={{ background: "var(--sjr-primary-soft)" }}>
                            <span className="truncate text-xs" style={{ color: "var(--sjr-primary-dark)" }}>✓ {file.name}</span>
                            <button type="button" className="shrink-0 text-xs text-rose-600 hover:underline" onClick={() => removeFile(kind, idx)}>Retirer</button>
                          </li>
                        ))}
                      </ul>
                    )}
                    {errors[kind] && <p className="mt-2 text-xs text-rose-600">{errors[kind]}</p>}
                  </div>
                );
              })}
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
                {Object.entries(DOC_KINDS).flatMap(([kind, meta]) => {
                  const label = kindMeta(kind, meta).label;
                  const ex = existingByKind(kind).map((d) => <li key={`re${d.id}`}>✓ {label} — {d.original_name}</li>);
                  const nw = (files[kind] || []).map((file, idx) => <li key={`rn${kind}${idx}`}>✓ {label} — {file.name}</li>);
                  return [...ex, ...nw];
                })}
              </ul>
            </div>

            <label className="mt-5 flex items-start gap-3 rounded-lg border p-4" style={{ borderColor: "var(--sjr-line)" }}>
              <input type="checkbox" checked={certified} onChange={(e) => setCertified(e.target.checked)} className="mt-0.5 h-4 w-4" />
              <span className="text-sm" style={{ color: "var(--sjr-ink)" }}>Je certifie l'exactitude des informations renseignées.</span>
            </label>

            {!isEdit && (
              <label className="mt-3 flex items-start gap-3 rounded-lg border p-4" style={{ borderColor: "var(--sjr-line)" }}>
                <input type="checkbox" checked={consentProcessing} onChange={(e) => setConsentProcessing(e.target.checked)} className="mt-0.5 h-4 w-4" />
                <span className="text-sm" style={{ color: "var(--sjr-ink)" }}>
                  J'accepte que les informations et documents transmis soient traités par la Ville de Saint-Jean-de-la-Ruelle
                  dans le cadre de l'étude de ma candidature. <span className="text-rose-500">*</span>
                </span>
              </label>
            )}

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
            <button className="btn-accent" onClick={submit} disabled={submitting}>
              {submitting ? "Envoi…" : isEdit ? "Enregistrer les modifications" : "Envoyer ma candidature"}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
SJR_EOF_7f3c

mkdir -p "$(dirname "lib/auth.js")"
cat > "lib/auth.js" << 'SJR_EOF_7f3c'
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
SJR_EOF_7f3c

mkdir -p "$(dirname "lib/offers.js")"
cat > "lib/offers.js" << 'SJR_EOF_7f3c'
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
  id = Number(id);
  if (!Number.isInteger(id)) return null;
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
  id = Number(id);
  if (!Number.isInteger(id)) return null;
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

const OFFER_FIELDS = ["title","sector_id","direction_id","pole_id","contract_type","work_time","location","positions_total","deadline","missions","profile","conditions","extra_info","keywords","diploma_label","diploma_required"];

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
    data.diploma_label ? String(data.diploma_label).trim() : null,
    data.diploma_required ? 1 : 0,
  ];
  const info = await dbRun(`
    INSERT INTO offers (reference, title, sector_id, direction_id, pole_id, contract_type,
      work_time, location, positions_total, deadline, missions, profile, conditions,
      extra_info, keywords, status, published_at, diploma_label, diploma_required)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`, args);
  return getOffer(info.lastInsertRowid);
}

export async function updateOffer(id, data) {
  const current = await dbGet("SELECT * FROM offers WHERE id = ?", [id]);
  if (!current) return null;
  const merged = { ...current };
  for (const f of OFFER_FIELDS) if (f in data && data[f] !== undefined) merged[f] = data[f];
  merged.positions_total = Math.max(1, parseInt(merged.positions_total) || 1);
  const diplomaLabel = merged.diploma_label ? String(merged.diploma_label).trim() : null;
  const diplomaRequired = merged.diploma_required ? 1 : 0;
  await dbRun(`
    UPDATE offers SET title=?, sector_id=?, direction_id=?, pole_id=?, contract_type=?, work_time=?,
      location=?, positions_total=?, deadline=?, missions=?, profile=?, conditions=?, extra_info=?,
      keywords=?, diploma_label=?, diploma_required=?, updated_at=datetime('now') WHERE id=?`,
    [merged.title, merged.sector_id, merged.direction_id, merged.pole_id, merged.contract_type,
     merged.work_time, merged.location, merged.positions_total, merged.deadline, merged.missions,
     merged.profile, merged.conditions, merged.extra_info, merged.keywords, diplomaLabel, diplomaRequired, id]);
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
SJR_EOF_7f3c

mkdir -p "$(dirname "lib/purge.js")"
cat > "lib/purge.js" << 'SJR_EOF_7f3c'
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
  // Au passage : on purge aussi les sessions RH expirées (> 30 jours).
  await dbRun("DELETE FROM sessions WHERE created_at < datetime('now', '-30 days')");
  return { deleted: ids.length, years: YEARS };
}
SJR_EOF_7f3c

mkdir -p "$(dirname "lib/sheets.js")"
cat > "lib/sheets.js" << 'SJR_EOF_7f3c'
// Synchronisation vers Google Sheets (miroir + stats).
// Non bloquant : si le webhook est absent ou en erreur, l'appli continue.

// URL et secret du webhook Google Sheets : UNIQUEMENT via variables d'environnement
// (SHEETS_WEBHOOK_URL / SHEETS_WEBHOOK_SECRET sur Vercel). Aucune valeur en dur ici.
const WEBHOOK_URL = process.env.SHEETS_WEBHOOK_URL || "";
const SECRET = process.env.SHEETS_WEBHOOK_SECRET || "";

export function sheetsEnabled() {
  return /^https:\/\//.test(WEBHOOK_URL);
}

export async function syncApplication(app, event) {
  if (!sheetsEnabled() || !app) {
    console.log("[sheets] synchronisation désactivée");
    return;
  }

  const payload = {
    secret: SECRET,
    ref: app.public_ref,
    received_at: app.created_at,
    updated_at: new Date().toISOString(),
    status: app.status,
    status_label: app.status_label || app.status,
    civility: app.civility || "",
    last_name: app.last_name || "",
    first_name: app.first_name || "",
    email: app.email || "",
    phone: app.phone || "",
    city: app.city || "",
    offer_title: app.offer_title || "",
    offer_ref: app.offer_reference || "",
    sector: app.sector_name || "",
    direction: app.direction_name || "",
    pole: app.pole_name || "",
    event: event || "",
  };

  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 10000);

    const response = await fetch(WEBHOOK_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: ctrl.signal,
    });

    clearTimeout(timer);

    if (!response.ok) {
      console.error("[sheets] Google Sheets a refusé la requête (HTTP " + response.status + ")");
    }
  } catch (e) {
    console.error("[sheets] Erreur de synchronisation :", e.message);
  }
} 
SJR_EOF_7f3c

mkdir -p "$(dirname "package.json")"
cat > "package.json" << 'SJR_EOF_7f3c'
{
  "name": "recrutement-sjr",
  "version": "1.0.0",
  "private": true,
  "description": "Prototype - Plateforme de recrutement - Ville de Saint-Jean-de-la-Ruelle",
  "scripts": {
    "dev": "next dev -p 3000",
    "build": "next build",
    "start": "next start -p 3000",
    "reset-db": "node scripts/reset.js"
  },
  "dependencies": {
    "@libsql/client": "^0.14.0",
    "jszip": "^3.10.2",
    "next": "^14.2.25",
    "nodemailer": "^10.0.13",
    "pdf-lib": "^1.17.1",
    "react": "18.3.1",
    "react-dom": "18.3.1",
    "xlsx": "^0.18.5"
  },
  "devDependencies": {
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.47",
    "tailwindcss": "^3.4.14"
  }
}
SJR_EOF_7f3c

echo "=== 17 fichiers mis a jour. Lance : npm install && npm run build, puis git add -A && commit && push ==="
