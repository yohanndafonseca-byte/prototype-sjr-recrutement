"use client";
import { useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";

export default function LoginForm() {
  const router = useRouter();
  const sp = useSearchParams();
  const [username, setU] = useState("rh");
  const [password, setP] = useState("mairie2026");
  const [err, setErr] = useState("");
  const [loading, setLoading] = useState(false);

  async function submit(e) {
    e.preventDefault();
    setLoading(true); setErr("");
    try {
      const res = await fetch("/api/auth/login", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username, password }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Connexion impossible.");
      router.push(sp.get("next") || "/admin");
      router.refresh();
    } catch (e) { setErr(e.message); setLoading(false); }
  }

  return (
    <form onSubmit={submit} className="space-y-4">
      <div>
        <label className="field-label">Identifiant</label>
        <input className="field" value={username} onChange={(e) => setU(e.target.value)} autoComplete="username" />
      </div>
      <div>
        <label className="field-label">Mot de passe</label>
        <input className="field" type="password" value={password} onChange={(e) => setP(e.target.value)} autoComplete="current-password" />
      </div>
      {err && <p className="rounded-lg bg-rose-50 px-3 py-2 text-sm text-rose-700">{err}</p>}
      <button className="btn-primary w-full" disabled={loading}>{loading ? "Connexion…" : "Se connecter"}</button>
      <p className="rounded-lg border border-dashed px-3 py-2 text-center text-xs" style={{ borderColor: "var(--sjr-line)", color: "var(--sjr-muted)" }}>
        Compte de démonstration — identifiant <b>rh</b> · mot de passe <b>mairie2026</b>
      </p>
    </form>
  );
}
