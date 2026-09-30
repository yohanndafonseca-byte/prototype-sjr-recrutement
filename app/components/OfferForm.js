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