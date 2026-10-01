"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { IconPlus, IconPencil, IconTrash, IconCheck } from "./Icons";

export default function ParametresManager({ tree }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  const [editing, setEditing] = useState(null); // "level:id"
  const [editVal, setEditVal] = useState("");
  const [adds, setAdds] = useState({}); // "level:parentId" -> valeur

  async function send(op, level, extra = {}) {
    setBusy(true); setErr("");
    try {
      const res = await fetch("/api/admin/parametres", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ op, level, ...extra }),
      });
      const data = await res.json();
      if (!data.ok) throw new Error(data.error || "Erreur");
      router.refresh();
      return true;
    } catch (e) {
      setErr(e.message);
      return false;
    } finally {
      setBusy(false);
    }
  }

  const aKey = (level, parentId) => `${level}:${parentId || 0}`;
  const setAdd = (k, v) => setAdds((s) => ({ ...s, [k]: v }));

  async function doAdd(level, parentId) {
    const k = aKey(level, parentId);
    const name = (adds[k] || "").trim();
    if (!name) return;
    if (await send("create", level, { name, parentId })) setAdd(k, "");
  }
  function startEdit(level, id, current) { setEditing(`${level}:${id}`); setEditVal(current); setErr(""); }
  async function doRename(level, id) {
    if (!editVal.trim()) return;
    if (await send("rename", level, { id, name: editVal.trim() })) setEditing(null);
  }
  async function doDelete(level, id, label) {
    if (!window.confirm(`Supprimer « ${label} » ?`)) return;
    await send("delete", level, { id });
  }

  const isEditing = (level, id) => editing === `${level}:${id}`;

  function NameOrEdit({ level, id, name, bold }) {
    if (isEditing(level, id)) {
      return (
        <span className="flex flex-1 items-center gap-2">
          <input autoFocus value={editVal} onChange={(e) => setEditVal(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter") doRename(level, id); if (e.key === "Escape") setEditing(null); }}
            className="field flex-1" />
          <button disabled={busy} onClick={() => doRename(level, id)} className="btn-primary px-2 py-1" title="Valider"><IconCheck className="h-4 w-4" /></button>
          <button disabled={busy} onClick={() => setEditing(null)} className="btn-outline px-2 py-1">Annuler</button>
        </span>
      );
    }
    return (
      <span className="flex flex-1 items-center justify-between gap-2">
        <span className={bold ? "font-semibold" : ""} style={{ color: "var(--sjr-ink)" }}>{name}</span>
        <span className="flex items-center gap-1">
          <button disabled={busy} onClick={() => startEdit(level, id, name)} className="rounded-lg p-1.5 transition-colors hover:bg-slate-100" title="Renommer"><IconPencil className="h-4 w-4" /></button>
          <button disabled={busy} onClick={() => doDelete(level, id, name)} className="rounded-lg p-1.5 text-rose-600 transition-colors hover:bg-rose-50" title="Supprimer"><IconTrash className="h-4 w-4" /></button>
        </span>
      </span>
    );
  }

  function AddRow({ level, parentId, placeholder }) {
    const k = aKey(level, parentId);
    return (
      <div className="mt-2 flex items-center gap-2">
        <input value={adds[k] || ""} onChange={(e) => setAdd(k, e.target.value)}
          onKeyDown={(e) => { if (e.key === "Enter") doAdd(level, parentId); }}
          placeholder={placeholder} className="field flex-1" />
        <button disabled={busy} onClick={() => doAdd(level, parentId)} className="btn-outline whitespace-nowrap">
          <IconPlus className="h-4 w-4" /> Ajouter
        </button>
      </div>
    );
  }

  return (
    <div>
      {err && (
        <div className="mb-4 rounded-lg border px-4 py-3 text-sm" style={{ borderColor: "#f5c2c0", background: "#fdecea", color: "#b4231f" }}>
          {err}
        </div>
      )}

      <div className="space-y-4">
        {tree.map((s) => (
          <div key={s.id} className="card p-4">
            {/* Secteur */}
            <div className="flex items-center gap-2 border-b pb-3" style={{ borderColor: "var(--sjr-line)" }}>
              <span className="rounded px-2 py-0.5 text-xs font-bold text-white" style={{ background: "var(--sjr-primary)" }}>SECTEUR</span>
              <NameOrEdit level="sector" id={s.id} name={s.name} bold />
            </div>

            {/* Directions */}
            <div className="mt-3 space-y-3 pl-3">
              {s.directions.map((d) => (
                <div key={d.id} className="rounded-lg border p-3" style={{ borderColor: "var(--sjr-line)" }}>
                  <div className="flex items-center gap-2">
                    <span className="rounded px-2 py-0.5 text-[11px] font-semibold" style={{ background: "#eef3f8", color: "var(--sjr-primary-dark)" }}>DIRECTION</span>
                    <NameOrEdit level="direction" id={d.id} name={d.name} />
                  </div>

                  {/* Pôles */}
                  <div className="mt-2 space-y-1.5 pl-3">
                    {d.poles.map((p) => (
                      <div key={p.id} className="flex items-center gap-2 text-sm">
                        <span className="text-xs" style={{ color: "var(--sjr-muted)" }}>Pôle</span>
                        <NameOrEdit level="pole" id={p.id} name={p.name} />
                      </div>
                    ))}
                    <AddRow level="pole" parentId={d.id} placeholder="Nouveau pôle…" />
                  </div>
                </div>
              ))}
              <AddRow level="direction" parentId={s.id} placeholder="Nouvelle direction…" />
            </div>
          </div>
        ))}
      </div>

      {/* Ajouter un secteur */}
      <div className="card mt-4 p-4">
        <div className="text-sm font-semibold" style={{ color: "var(--sjr-ink)" }}>Ajouter un secteur</div>
        <AddRow level="sector" parentId={0} placeholder="Nouveau secteur…" />
      </div>
    </div>
  );
}
