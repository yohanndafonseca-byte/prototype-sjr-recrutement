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
