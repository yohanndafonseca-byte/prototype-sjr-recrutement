"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { APP_STATUS_LABEL, allowedTransitions, APP_FLOW } from "@/lib/constants";

const CONFIRM = { recrute: "Confirmer le recrutement ? Cela décrémentera le nombre de postes restants.", refusee: "Confirmer le refus de cette candidature ?" };

export default function StatusChanger({ id, status }) {
  const router = useRouter();
  const [busy, setBusy] = useState("");
  const [err, setErr] = useState("");
  const transitions = allowedTransitions(status);

  async function change(target) {
    if (CONFIRM[target] && !window.confirm(CONFIRM[target])) return;
    setBusy(target); setErr("");
    try {
      const res = await fetch(`/api/admin/candidatures/${id}/status`, {
        method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ status: target }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Erreur");
      router.refresh();
    } catch (e) { setErr(e.message); } finally { setBusy(""); }
  }

  const forward = transitions.filter((t) => t !== "refusee" && APP_FLOW.indexOf(t) > APP_FLOW.indexOf(status));
  const backward = transitions.filter((t) => t !== "refusee" && !forward.includes(t));
  const btn = (t) => {
    const cls = t === "recrute" ? "btn-accent" : t === "refusee" ? "btn-danger" : "btn-primary";
    return <button key={t} className={`${cls} w-full`} disabled={!!busy} onClick={() => change(t)}>{busy === t ? "…" : `→ ${APP_STATUS_LABEL[t]}`}</button>;
  };

  return (
    <div className="space-y-2.5">
      {forward.map(btn)}
      {backward.map((t) => (
        <button key={t} className="btn-outline w-full" disabled={!!busy} onClick={() => change(t)}>{busy === t ? "…" : `← ${APP_STATUS_LABEL[t]}`}</button>
      ))}
      {transitions.includes("refusee") && (
        <button className="btn-danger w-full" disabled={!!busy} onClick={() => change("refusee")}>{busy === "refusee" ? "…" : "Refuser la candidature"}</button>
      )}
      {err && <p className="rounded-lg bg-rose-50 px-3 py-2 text-xs text-rose-700">{err}</p>}
    </div>
  );
}
