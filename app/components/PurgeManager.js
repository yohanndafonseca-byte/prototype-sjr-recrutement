"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { IconTrash } from "./Icons";

export default function PurgeManager({ preview }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState("");
  const [err, setErr] = useState("");

  async function purge() {
    if (!window.confirm(
      `Supprimer DÉFINITIVEMENT ${preview.count} candidature(s) de plus de ${preview.years} ans ` +
      `(pièces, notes et historique compris) ? Cette action est irréversible.`
    )) return;
    setBusy(true); setErr(""); setMsg("");
    try {
      const res = await fetch("/api/admin/purge", { method: "POST" });
      const data = await res.json();
      if (!data.ok) throw new Error(data.error || "Erreur");
      setMsg(`${data.deleted} candidature(s) supprimée(s) définitivement.`);
      router.refresh();
    } catch (e) { setErr(e.message); }
    finally { setBusy(false); }
  }

  return (
    <div className="card p-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <div className="font-semibold" style={{ color: "var(--sjr-ink)" }}>
            Candidatures à purger
          </div>
          <div className="text-sm" style={{ color: "var(--sjr-muted)" }}>
            Non recrutées, de plus de {preview.years} ans.
          </div>
        </div>
        <span className="rounded-full px-3 py-1 text-sm font-bold text-white"
          style={{ background: preview.count > 0 ? "#b4231f" : "var(--sjr-accent)" }}>
          {preview.count}
        </span>
      </div>

      {msg && <div className="mt-3 rounded-lg px-4 py-2 text-sm" style={{ background: "#e6f4ea", color: "#137333" }}>{msg}</div>}
      {err && <div className="mt-3 rounded-lg px-4 py-2 text-sm" style={{ background: "#fde8e8", color: "#b4231f" }}>{err}</div>}

      {preview.count > 0 && (
        <>
          <div className="mt-4 max-h-64 overflow-auto rounded-lg border" style={{ borderColor: "var(--sjr-line)" }}>
            <table className="w-full text-sm">
              <thead>
                <tr style={{ background: "#f3f6f7", color: "var(--sjr-muted)" }}>
                  <th className="px-3 py-2 text-left font-medium">Candidat</th>
                  <th className="px-3 py-2 text-left font-medium">Offre</th>
                  <th className="px-3 py-2 text-left font-medium">Dernière activité</th>
                </tr>
              </thead>
              <tbody>
                {preview.rows.map((r) => (
                  <tr key={r.id} className="border-t" style={{ borderColor: "var(--sjr-line)" }}>
                    <td className="px-3 py-2">{r.last_name} {r.first_name}</td>
                    <td className="px-3 py-2" style={{ color: "var(--sjr-muted)" }}>{r.offer_title}</td>
                    <td className="px-3 py-2" style={{ color: "var(--sjr-muted)" }}>{String(r.updated_at).slice(0, 10)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <button disabled={busy} onClick={purge} className="btn-primary mt-4" style={{ background: "#b4231f" }}>
            <IconTrash className="h-4 w-4" /> {busy ? "Suppression…" : `Purger maintenant (${preview.count})`}
          </button>
        </>
      )}

      {preview.count === 0 && (
        <p className="mt-3 text-sm" style={{ color: "var(--sjr-muted)" }}>
          Aucune candidature à purger pour le moment. ✅
        </p>
      )}
    </div>
  );
}

