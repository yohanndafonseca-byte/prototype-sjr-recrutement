#!/usr/bin/env bash
# MAJ v2 : diplome par offre + import multi-fichiers + lien de modification candidat.
# A lancer a la racine du projet, puis : npm run build && git add -A && commit && push.
set -e

mkdir -p "$(dirname "app/api/candidatures/[token]/route.js")"
cat > "app/api/candidatures/[token]/route.js" << 'SJR_EOF_7f3c'
import { NextResponse } from "next/server";
import {
  getByEditToken, isApplicationEditable, updateApplicationFields,
  deleteDocumentOfApp, saveDocument, getApplication, addEvent,
} from "@/lib/applications";
import { DOC_KINDS, MAX_FILE_MB, ACCEPTED_EXT } from "@/lib/constants";
import { syncApplication } from "@/lib/sheets";

export const runtime = "nodejs";

function extOk(name) {
  const i = (name || "").lastIndexOf(".");
  return i >= 0 && ACCEPTED_EXT.includes(name.slice(i).toLowerCase());
}

export async function PUT(req, { params }) {
  try {
    const app = await getByEditToken(params.token);
    if (!app) return NextResponse.json({ error: "Lien de modification invalide." }, { status: 404 });
    if (!isApplicationEditable(app)) {
      return NextResponse.json({ error: "Votre candidature est en cours de traitement : elle n'est plus modifiable. Contactez le service RH." }, { status: 409 });
    }

    const fd = await req.formData();

    const data = {
      civility: fd.get("civility"), last_name: fd.get("last_name"), first_name: fd.get("first_name"),
      address: fd.get("address"), postal_code: fd.get("postal_code"), city: fd.get("city"),
      email: fd.get("email"), phone: fd.get("phone"),
      consent_vivier: fd.get("consent_vivier") === "1",
    };
    if (!data.last_name || !data.first_name) {
      return NextResponse.json({ error: "Nom et prénom obligatoires." }, { status: 400 });
    }

    // Pièces existantes que le candidat retire.
    const removed = new Set(fd.getAll("removed_doc_ids").map((v) => Number(v)).filter(Boolean));
    const remainingByKind = (kind) => app.documents.filter((d) => d.kind === kind && !removed.has(d.id)).length;
    const newFilesByKind = (kind) => fd.getAll(kind).filter((f) => f && typeof f !== "string" && f.size > 0);

    // Validations (avant toute modification).
    if (remainingByKind("cv") + newFilesByKind("cv").length === 0) {
      return NextResponse.json({ error: "Le CV est obligatoire." }, { status: 400 });
    }
    if (app.offer_diploma_required && remainingByKind("diplome") + newFilesByKind("diplome").length === 0) {
      return NextResponse.json({ error: `Le diplôme demandé est obligatoire${app.offer_diploma_label ? ` : ${app.offer_diploma_label}` : ""}.` }, { status: 400 });
    }
    for (const kind of Object.keys(DOC_KINDS)) {
      for (const file of newFilesByKind(kind)) {
        if (!extOk(file.name)) return NextResponse.json({ error: `Format non accepté pour ${DOC_KINDS[kind].label}.` }, { status: 400 });
        if (file.size > MAX_FILE_MB * 1024 * 1024) return NextResponse.json({ error: `${DOC_KINDS[kind].label} : fichier trop volumineux.` }, { status: 400 });
      }
    }

    // Application des changements.
    await updateApplicationFields(app.id, data);
    for (const id of removed) await deleteDocumentOfApp(id, app.id);
    for (const kind of Object.keys(DOC_KINDS)) {
      for (const file of newFilesByKind(kind)) {
        const buf = Buffer.from(await file.arrayBuffer());
        await saveDocument(app, kind, file.name, buf, file.type);
      }
    }

    await addEvent(app.id, "modification", "Candidature modifiée par le candidat (lien de modification).");
    await syncApplication(await getApplication(app.id), "Candidature modifiée par le candidat");

    return NextResponse.json({ ok: true });
  } catch (e) {
    console.error("[candidatures PUT]", e);
    return NextResponse.json({ error: "Une erreur est survenue lors de l'enregistrement." }, { status: 500 });
  }
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

mkdir -p "$(dirname "app/candidature-envoyee/page.js")"
cat > "app/candidature-envoyee/page.js" << 'SJR_EOF_7f3c'
import Link from "next/link";
import PublicHeader from "@/app/components/PublicHeader";
import PublicFooter from "@/app/components/PublicFooter";
import { IconCheck } from "@/app/components/Icons";

export const dynamic = "force-dynamic";

export default function Confirmation({ searchParams }) {
  const ref = searchParams?.ref;
  const token = searchParams?.t;
  return (
    <div className="flex min-h-screen flex-col">
      <PublicHeader />
      <main className="flex-1">
        <div className="container-sjr max-w-2xl py-16">
          <div className="card p-8 text-center md:p-12">
            <div className="mx-auto grid h-16 w-16 place-items-center rounded-full" style={{ background: "var(--sjr-accent)" }}>
              <IconCheck className="h-8 w-8 text-white" />
            </div>
            <h1 className="mt-6 text-2xl font-bold" style={{ color: "var(--sjr-ink)" }}>Votre candidature a bien été envoyée</h1>
            <p className="mx-auto mt-3 max-w-md text-[15px]" style={{ color: "var(--sjr-muted)" }}>
              Votre candidature a été transmise au service des ressources humaines de la Ville de
              Saint-Jean-de-la-Ruelle. Un accusé de réception vous a été adressé par e-mail.
            </p>
            {ref && (
              <div className="mx-auto mt-5 inline-block rounded-lg px-4 py-2" style={{ background: "var(--sjr-primary-soft)" }}>
                <span className="text-xs" style={{ color: "var(--sjr-muted)" }}>Référence de suivi</span>
                <div className="font-mono text-sm font-semibold" style={{ color: "var(--sjr-primary-dark)" }}>{ref}</div>
              </div>
            )}
            {token && (
              <p className="mx-auto mt-5 max-w-md text-sm" style={{ color: "var(--sjr-muted)" }}>
                Besoin de compléter ou corriger votre dossier ? Vous pouvez le faire tant que votre candidature
                n'a pas été traitée. Le lien vous a aussi été envoyé par e-mail.
              </p>
            )}
            <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
              {token && (
                <Link href={`/ma-candidature/${token}`} className="btn-outline">Modifier ma candidature</Link>
              )}
              <Link href="/recrutement" className="btn-primary">Voir les autres offres</Link>
            </div>
          </div>
        </div>
      </main>
      <PublicFooter />
    </div>
  );
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

mkdir -p "$(dirname "app/components/OfferForm.js")"
cat > "app/components/OfferForm.js" << 'SJR_EOF_7f3c'
"use client";
import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { CONTRACT_TYPES, WORK_TIMES } from "@/lib/constants";

const empty = {
  title: "", sector_id: "", direction_id: "", pole_id: "", contract_type: "",
  work_time: "", positions_total: 1, deadline: "", keywords: "",
  diploma_label: "", diploma_required: false,
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
      diploma_label: (f.diploma_label || "").trim(), diploma_required: !!f.diploma_required,
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
          <Field label="Diplôme demandé (intitulé)">
            <input className="field" value={f.diploma_label} onChange={(e) => set("diploma_label", e.target.value)} placeholder="ex. BPJEPS, Bafa, DEAP — laisser vide si aucun" />
          </Field>
          <Field label="Ce diplôme est">
            <select className="field" value={f.diploma_required ? "1" : "0"} onChange={(e) => set("diploma_required", e.target.value === "1")} disabled={!f.diploma_label.trim()}>
              <option value="0">Facultatif</option>
              <option value="1">Obligatoire</option>
            </select>
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
SJR_EOF_7f3c

mkdir -p "$(dirname "app/ma-candidature/[token]/page.js")"
cat > "app/ma-candidature/[token]/page.js" << 'SJR_EOF_7f3c'
import Link from "next/link";
import PublicHeader from "@/app/components/PublicHeader";
import PublicFooter from "@/app/components/PublicFooter";
import ApplyForm from "@/app/components/ApplyForm";
import { IconCheck } from "@/app/components/Icons";
import { getByEditToken, isApplicationEditable } from "@/lib/applications";

export const dynamic = "force-dynamic";

export default async function MaCandidaturePage({ params, searchParams }) {
  const app = await getByEditToken(params.token);
  const saved = searchParams?.saved === "1";

  return (
    <div className="flex min-h-screen flex-col">
      <PublicHeader />
      <main className="flex-1">
        <div className="container-sjr max-w-3xl py-8">
          {!app ? (
            <div className="card p-8 text-center">
              <h1 className="text-xl font-bold" style={{ color: "var(--sjr-ink)" }}>Lien invalide</h1>
              <p className="mx-auto mt-2 max-w-md text-sm" style={{ color: "var(--sjr-muted)" }}>
                Ce lien de modification n'est pas valide ou a expiré. Si besoin, contactez le service Ressources Humaines.
              </p>
              <div className="mt-6"><Link href="/recrutement" className="btn-primary">Voir les offres</Link></div>
            </div>
          ) : !isApplicationEditable(app) ? (
            <div className="card p-8 text-center">
              <h1 className="text-xl font-bold" style={{ color: "var(--sjr-ink)" }}>Candidature en cours de traitement</h1>
              <p className="mx-auto mt-2 max-w-md text-sm" style={{ color: "var(--sjr-muted)" }}>
                Votre candidature au poste <strong>{app.offer_title}</strong> est désormais prise en charge par le service RH
                et ne peut plus être modifiée en ligne. Pour toute correction, contactez directement le service Ressources Humaines.
              </p>
              <div className="mt-6"><Link href="/recrutement" className="btn-primary">Voir les offres</Link></div>
            </div>
          ) : (
            <>
              <h1 className="text-2xl font-bold" style={{ color: "var(--sjr-ink)" }}>Modifier ma candidature</h1>
              <p className="mt-1 text-sm" style={{ color: "var(--sjr-muted)" }}>
                Poste : <strong>{app.offer_title}</strong> · Référence {app.public_ref}. Vos informations et documents actuels sont pré-remplis ;
                modifiez ce que vous souhaitez puis enregistrez.
              </p>
              {saved && (
                <div className="mt-4 flex items-center gap-2 rounded-lg px-4 py-3 text-sm" style={{ background: "var(--sjr-primary-soft)", color: "var(--sjr-primary-dark)" }}>
                  <IconCheck className="h-4 w-4" /> Vos modifications ont bien été enregistrées.
                </div>
              )}
              <div className="mt-6">
                <ApplyForm
                  mode="edit"
                  token={params.token}
                  offer={{
                    id: app.offer_id,
                    title: app.offer_title,
                    positions_total: app.positions_total,
                    contract_type: app.offer_contract_type,
                    location: app.offer_location,
                    diploma_label: app.offer_diploma_label || "",
                    diploma_required: !!app.offer_diploma_required,
                  }}
                  initial={{
                    civility: app.civility, last_name: app.last_name, first_name: app.first_name,
                    phone: app.phone, email: app.email, address: app.address,
                    postal_code: app.postal_code, city: app.city, consent_vivier: !!app.consent_vivier,
                  }}
                  existingDocs={(app.documents || []).map((d) => ({ id: d.id, kind: d.kind, original_name: d.original_name }))}
                />
              </div>
            </>
          )}
        </div>
      </main>
      <PublicFooter />
    </div>
  );
}
SJR_EOF_7f3c

mkdir -p "$(dirname "app/recrutement/[id]/candidater/page.js")"
cat > "app/recrutement/[id]/candidater/page.js" << 'SJR_EOF_7f3c'
import Link from "next/link";
import { notFound } from "next/navigation";
import PublicHeader from "@/app/components/PublicHeader";
import PublicFooter from "@/app/components/PublicFooter";
import ApplyForm from "@/app/components/ApplyForm";
import { IconArrowLeft } from "@/app/components/Icons";
import { getPublicOffer } from "@/lib/offers";

export const dynamic = "force-dynamic";

export default async function CandidaterPage({ params }) {
  const o = await getPublicOffer(Number(params.id));
  if (!o) notFound();
  const offer = { id: o.id, title: o.title, positions_total: o.positions_total, contract_type: o.contract_type, location: o.location, diploma_label: o.diploma_label || "", diploma_required: !!o.diploma_required };

  return (
    <div className="flex min-h-screen flex-col">
      <PublicHeader />
      <main className="flex-1">
        <div className="container-sjr max-w-3xl py-8">
          <Link href={`/recrutement/${o.id}`} className="link inline-flex items-center gap-1.5 text-sm">
            <IconArrowLeft className="h-4 w-4" /> Retour à l'offre
          </Link>
          <h1 className="mt-4 text-2xl font-bold" style={{ color: "var(--sjr-ink)" }}>Postuler</h1>
          <p className="mt-1 text-sm" style={{ color: "var(--sjr-muted)" }}>Complétez les trois étapes ci-dessous pour transmettre votre candidature au service RH.</p>
          <div className="mt-6"><ApplyForm offer={offer} /></div>
        </div>
      </main>
      <PublicFooter />
    </div>
  );
}
SJR_EOF_7f3c

mkdir -p "$(dirname "lib/applications.js")"
cat > "lib/applications.js" << 'SJR_EOF_7f3c'
import crypto from "crypto";
import { dbAll, dbGet, dbRun } from "./db.js";
import { getOffer, syncOffer } from "./offers.js";
import { APP_STATUS_LABEL, allowedTransitions, EDITABLE_STATUSES } from "./constants.js";
import { sendAccuseReception, sendReponsePositive, sendReponseNegative } from "./email.js";

export function publicRef() {
  const y = new Date().getFullYear();
  const r = crypto.randomBytes(3).toString("hex").toUpperCase();
  return `CAND-${y}-${r}`;
}

// Jeton privé non devinable pour le lien de modification candidat.
export function editToken() {
  return crypto.randomBytes(16).toString("hex");
}

// URL publique du site (sert à construire le lien de modification dans l'e-mail).
export function siteUrl() {
  return (process.env.SITE_URL || process.env.NEXT_PUBLIC_SITE_URL || "https://recrutement-sjr.vercel.app").replace(/\/+$/, "");
}
export function editUrlFor(token) {
  return `${siteUrl()}/ma-candidature/${token}`;
}

function todayISO() {
  return new Date().toISOString().slice(0, 10);
}
// Le candidat peut-il encore modifier sa candidature ?
export function isApplicationEditable(app) {
  if (!app) return false;
  if (!EDITABLE_STATUSES.includes(app.status)) return false;
  if (app.offer_deadline && String(app.offer_deadline) < todayISO()) return false;
  return true;
}

const APP_SELECT = `
  SELECT a.*, o.title AS offer_title, o.reference AS offer_reference,
    o.positions_total, o.deadline AS offer_deadline, o.contract_type AS offer_contract_type,
    o.location AS offer_location, o.status AS offer_status,
    o.diploma_label AS offer_diploma_label, o.diploma_required AS offer_diploma_required,
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
  const token = editToken();
  const info = await dbRun(`
    INSERT INTO applications (public_ref, offer_id, civility, last_name, first_name,
      address, postal_code, city, email, phone, consent_processing, consent_vivier, status, edit_token)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?, 'nouvelle', ?)`,
    [ref, offerId, data.civility || null, data.last_name || "", data.first_name || "",
     data.address || null, data.postal_code || null, data.city || null,
     data.email || null, data.phone || null,
     data.consent_processing ? 1 : 0, data.consent_vivier ? 1 : 0, token]);
  const id = info.lastInsertRowid;
  await addEvent(id, "creation", "Candidature reçue — statut initial : Nouvelle candidature.");
  const arSent = await sendAccuseReception({ to: data.email, firstName: data.first_name, offerTitle: offer.title, ref, editUrl: editUrlFor(token) });
  await addEvent(id, "email", arSent ? "Accusé de réception envoyé au candidat." : "Accusé de réception — e-mail non envoyé (service non configuré).");
  return { id, public_ref: ref, edit_token: token, offer };
}

// Récupère une candidature complète à partir de son jeton de modification.
export async function getByEditToken(token) {
  if (!token) return null;
  const row = await dbGet("SELECT id FROM applications WHERE edit_token = ?", [String(token)]);
  if (!row) return null;
  return getApplication(row.id);
}

// Met à jour les informations personnelles (modification par le candidat).
export async function updateApplicationFields(id, data) {
  await dbRun(`
    UPDATE applications SET civility=?, last_name=?, first_name=?, address=?,
      postal_code=?, city=?, email=?, phone=?, consent_vivier=?, updated_at=datetime('now')
    WHERE id=?`,
    [data.civility || null, data.last_name || "", data.first_name || "",
     data.address || null, data.postal_code || null, data.city || null,
     data.email || null, data.phone || null, data.consent_vivier ? 1 : 0, id]);
}

// Supprime une pièce — uniquement si elle appartient bien à la candidature.
export async function deleteDocumentOfApp(docId, applicationId) {
  await dbRun("DELETE FROM documents WHERE id=? AND application_id=?", [Number(docId), applicationId]);
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
  if (newStatus === "recrute") {
    const off = await getOffer(app.offer_id);
    const sent = await sendReponsePositive({ to: app.email, firstName: app.first_name, offerTitle: off.title });
    await addEvent(id, "email", sent ? "Réponse positive envoyée au candidat." : "Réponse positive — e-mail non envoyé (service non configuré).");
  }
  if (newStatus === "refusee") {
    const off = await getOffer(app.offer_id);
    const sent = await sendReponseNegative({ to: app.email, firstName: app.first_name, offerTitle: off.title });
    await addEvent(id, "email", sent ? "Réponse négative envoyée au candidat." : "Réponse négative — e-mail non envoyé (service non configuré).");
  }
  await syncOffer(app.offer_id);
  return getApplication(id);
}

export async function addNote(id, body) {
  if (!body || !body.trim()) return;
  await dbRun("INSERT INTO notes (application_id, body) VALUES (?,?)", [id, body.trim()]);
  await addEvent(id, "note", "Note interne ajoutée.");
}
SJR_EOF_7f3c

mkdir -p "$(dirname "lib/constants.js")"
cat > "lib/constants.js" << 'SJR_EOF_7f3c'
// ---- Statuts d'offre ----
export const OFFER_STATUS = {
  BROUILLON: "brouillon",
  PUBLIEE: "publiee",
  EXPIREE: "expiree",
  POURVUE: "pourvue",
};

export const OFFER_STATUS_LABEL = {
  brouillon: "Brouillon",
  publiee: "Publiée",
  expiree: "Expirée",
  pourvue: "Pourvue",
};

// ---- Statuts de candidature (workflow V1) ----
export const APP_STATUS = {
  NOUVELLE: "nouvelle",
  A_ETUDIER: "a_etudier",
  PRESELECTIONNEE: "preselectionnee",
  ENTRETIEN: "entretien",
  RETENUE: "retenue",
  RECRUTE: "recrute",
  REFUSEE: "refusee",
};

export const APP_STATUS_LABEL = {
  nouvelle: "Nouvelle candidature",
  a_etudier: "À étudier",
  preselectionnee: "Présélectionnée",
  entretien: "Entretien",
  retenue: "Retenue",
  recrute: "Recruté",
  refusee: "Refusée",
};

// Ordre normal du processus (Refusée est transverse)
export const APP_FLOW = [
  "nouvelle",
  "a_etudier",
  "preselectionnee",
  "entretien",
  "retenue",
  "recrute",
];

// Statuts pendant lesquels le candidat peut encore modifier lui-même sa candidature
// (avant toute évaluation par la RH).
export const EDITABLE_STATUSES = ["nouvelle", "a_etudier"];

// Transitions autorisées depuis un statut donné.
// Refusée est atteignable depuis n'importe quelle étape non finale.
export function allowedTransitions(current) {
  if (current === "recrute") return ["retenue"]; // possibilité d'annuler un recrutement
  if (current === "refusee") return ["a_etudier"]; // ré-ouvrir une candidature refusée
  const idx = APP_FLOW.indexOf(current);
  const next = [];
  if (idx >= 0 && idx < APP_FLOW.length - 1) next.push(APP_FLOW[idx + 1]);
  if (idx > 0) next.push(APP_FLOW[idx - 1]); // revenir en arrière
  next.push("refusee");
  return [...new Set(next)];
}

export const DOC_KINDS = {
  cv: { label: "CV", required: true, hint: "obligatoire" },
  lm: { label: "Lettre de motivation", required: false, hint: "recommandée" },
  diplome: { label: "Diplôme(s)", required: false, hint: "recommandé", multiple: true },
  autre: { label: "Autres documents", required: false, hint: "facultatif", multiple: true },
  entretiens: { label: "3 derniers entretiens professionnels", required: false, hint: "agents, facultatif", agentOnly: true, multiple: true },
};

export const CONTRACT_TYPES = ["CDI", "CDD", "Titulaire", "Contractuel", "Apprentissage", "Stage"];
export const WORK_TIMES = ["Temps complet (35h)", "Temps complet (37h30)", "Temps non complet (28h)", "Temps non complet (17h30)"];

export const MAX_FILE_MB = 8;
export const ACCEPTED_EXT = [".pdf", ".doc", ".docx", ".png", ".jpg", ".jpeg"];
SJR_EOF_7f3c

mkdir -p "$(dirname "lib/db.js")"
cat > "lib/db.js" << 'SJR_EOF_7f3c'
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
    "ALTER TABLE offers ADD COLUMN diploma_label TEXT",
    "ALTER TABLE offers ADD COLUMN diploma_required INTEGER DEFAULT 0",
    "ALTER TABLE applications ADD COLUMN edit_token TEXT",
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
SJR_EOF_7f3c

mkdir -p "$(dirname "lib/email.js")"
cat > "lib/email.js" << 'SJR_EOF_7f3c'
// Envoi d'e-mails via SMTP générique (nodemailer). Indépendant du fournisseur :
// Brevo pour la démo, SMTP de la mairie en production → on change juste les variables.
// Non bloquant : si non configuré ou en erreur, l'application continue normalement.
//
// Variables d'environnement (Vercel) :
//   SMTP_HOST        ex: smtp-relay.brevo.com
//   SMTP_PORT        ex: 587
//   SMTP_USER        identifiant SMTP (login Brevo, ou compte mairie)
//   SMTP_PASS        mot de passe / clé SMTP
//   SMTP_SECURE      "true" si port 465 (sinon laisser vide → STARTTLS sur 587)
//   SMTP_FROM_EMAIL  adresse expéditeur affichée
//   SMTP_FROM_NAME   nom expéditeur (optionnel)

import nodemailer from "nodemailer";

const HOST = process.env.SMTP_HOST || "";
const PORT = Number(process.env.SMTP_PORT || 587);
const USER = process.env.SMTP_USER || "";
const PASS = process.env.SMTP_PASS || "";
const SECURE = process.env.SMTP_SECURE === "true";
const FROM_EMAIL = process.env.SMTP_FROM_EMAIL || "";
const FROM_NAME = process.env.SMTP_FROM_NAME || "Ville de Saint-Jean-de-la-Ruelle — Recrutement";

export function emailEnabled() {
  console.log("[email] configuration :", {
    host: !!HOST,
    user: !!USER,
    pass: !!PASS,
    from: !!FROM_EMAIL,
    port: PORT,
    secure: SECURE,
  });

  return !!HOST && !!USER && !!PASS && !!FROM_EMAIL;
}

async function sendEmail(to, subject, html) {
  if (!emailEnabled() || !to) return false;
  try {
    const transporter = nodemailer.createTransport({
      host: HOST, port: PORT, secure: SECURE,
      auth: { user: USER, pass: PASS },
      connectionTimeout: 7000, greetingTimeout: 7000, socketTimeout: 7000,
    });
    await transporter.sendMail({
      from: `"${FROM_NAME}" <${FROM_EMAIL}>`,
      to, subject, html,
    });
    return true;
  } catch (e) {
    console.error("[email] envoi ignoré :", e.message);
    return false;
  }
}

function layout(innerHtml) {
  return `<!doctype html><html><body style="margin:0;background:#f3f6f7;font-family:Arial,Helvetica,sans-serif;color:#17282c;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f3f6f7;padding:24px 0;">
    <tr><td align="center">
      <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;background:#ffffff;border-radius:12px;overflow:hidden;border:1px solid #e2eaec;">
        <tr><td style="background:#1f7f8c;padding:20px 28px;color:#ffffff;font-size:16px;font-weight:bold;">
          Ville de Saint-Jean-de-la-Ruelle
          <div style="font-size:12px;font-weight:normal;opacity:.9;">Service Ressources Humaines — Recrutement</div>
        </td></tr>
        <tr><td style="padding:28px;font-size:14px;line-height:1.6;">${innerHtml}</td></tr>
        <tr><td style="padding:18px 28px;background:#f3f6f7;color:#5c6b70;font-size:12px;line-height:1.5;">
          Ceci est un message automatique, merci de ne pas y répondre.<br/>
          Conformément au RGPD, vous disposez d'un droit d'accès, de rectification et de suppression de vos données.
        </td></tr>
      </table>
    </td></tr>
  </table></body></html>`;
}

export function sendAccuseReception({ to, firstName, offerTitle, ref, editUrl }) {
  const editBlock = editUrl ? `
    <p style="margin-top:20px;">Besoin de compléter ou corriger votre dossier (documents, coordonnées…) ?
       Vous pouvez modifier votre candidature tant qu'elle n'a pas été traitée :</p>
    <p style="text-align:center;margin:18px 0;">
      <a href="${editUrl}" style="display:inline-block;background:#1f7f8c;color:#ffffff;text-decoration:none;padding:12px 22px;border-radius:8px;font-weight:bold;">Modifier ma candidature</a>
    </p>
    <p style="color:#5c6b70;font-size:12px;">Ce lien vous est personnel, ne le transmettez pas. Il se désactive dès que votre candidature est prise en charge par le service RH.</p>
  ` : "";
  const html = layout(`
    <p>Bonjour ${firstName || ""},</p>
    <p>Nous avons bien reçu votre candidature au poste suivant :</p>
    <p style="background:#e3f1f3;border-radius:8px;padding:12px 16px;font-weight:bold;">${offerTitle}</p>
    <p>Votre dossier va être étudié par notre service Ressources Humaines. Nous reviendrons vers vous dès que possible.</p>
    <p style="color:#5c6b70;font-size:13px;">Référence de votre candidature : <strong>${ref}</strong></p>
    ${editBlock}
    <p>Cordialement,<br/>Le service Ressources Humaines<br/>Ville de Saint-Jean-de-la-Ruelle</p>
  `);
  return sendEmail(to, `Accusé de réception de votre candidature — ${offerTitle}`, html);
}

export function sendReponsePositive({ to, firstName, offerTitle }) {
  const html = layout(`
    <p>Bonjour ${firstName || ""},</p>
    <p>Nous avons le plaisir de vous informer que votre candidature au poste de
       <strong>${offerTitle}</strong> a été retenue.</p>
    <p>Notre service Ressources Humaines vous recontactera très prochainement pour la suite du processus.</p>
    <p>Félicitations, et à très bientôt.</p>
    <p>Cordialement,<br/>Le service Ressources Humaines<br/>Ville de Saint-Jean-de-la-Ruelle</p>
  `);
  return sendEmail(to, `Votre candidature a été retenue — ${offerTitle}`, html);
}

export function sendReponseNegative({ to, firstName, offerTitle }) {
  const html = layout(`
    <p>Bonjour ${firstName || ""},</p>
    <p>Nous vous remercions de l'intérêt que vous avez porté au poste de
       <strong>${offerTitle}</strong> et du temps consacré à votre candidature.</p>
    <p>Après étude attentive, nous ne sommes pas en mesure de donner une suite favorable à votre demande pour ce poste.</p>
    <p>Nous vous souhaitons une pleine réussite dans vos recherches et démarches professionnelles.</p>
    <p>Cordialement,<br/>Le service Ressources Humaines<br/>Ville de Saint-Jean-de-la-Ruelle</p>
  `);
  return sendEmail(to, `Suite donnée à votre candidature — ${offerTitle}`, html);
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

echo "=== 12 fichiers mis a jour. Lance : npm run build, puis git add -A && commit && push ==="
