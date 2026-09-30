"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";

export default function NoteForm({ id }) {
  const router = useRouter();
  const [body, setBody] = useState("");
  const [busy, setBusy] = useState(false);
  async function add() {
    if (!body.trim()) return;
    setBusy(true);
    try {
      await fetch(`/api/admin/candidatures/${id}/notes`, {
        method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ body }),
      });
      setBody(""); router.refresh();
    } finally { setBusy(false); }
  }
  return (
    <div>
      <textarea className="field" value={body} onChange={(e) => setBody(e.target.value)} placeholder="Ajouter une note interne (visible uniquement par la RH)…" />
      <div className="mt-2 flex justify-end">
        <button className="btn-primary" disabled={busy || !body.trim()} onClick={add}>{busy ? "Ajout…" : "Ajouter la note"}</button>
      </div>
    </div>
  );
}
