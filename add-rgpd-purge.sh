#!/usr/bin/env bash
# Purge RGPD auto (2 ans) : bouton manuel + tâche quotidienne. À lancer à la racine du projet.
set -e
mkdir -p "app/api/admin/purge" "app/api/cron/purge" "app/admin/(dash)/rgpd"

cat > "lib/purge.js" << 'SJREOF'
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
  return { deleted: ids.length, years: YEARS };
}

SJREOF

cat > "app/api/admin/purge/route.js" << 'SJREOF'
import { NextResponse } from "next/server";
import { listPurgeable, purgeExpired } from "@/lib/purge";

export const runtime = "nodejs";

export async function GET() {
  const preview = await listPurgeable();
  return NextResponse.json({ ok: true, ...preview });
}

export async function POST() {
  const res = await purgeExpired();
  return NextResponse.json({ ok: true, ...res });
}

SJREOF

cat > "app/api/cron/purge/route.js" << 'SJREOF'
import { NextResponse } from "next/server";
import { purgeExpired } from "@/lib/purge";

export const runtime = "nodejs";

export async function GET(req) {
  const secret = process.env.CRON_SECRET || "";
  const auth = req.headers.get("authorization") || "";
  if (!secret || auth !== `Bearer ${secret}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const res = await purgeExpired();
  return NextResponse.json({ ok: true, ...res });
}

SJREOF

cat > "app/components/PurgeManager.js" << 'SJREOF'
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

SJREOF

cat > "app/admin/(dash)/rgpd/page.js" << 'SJREOF'
import { listPurgeable } from "@/lib/purge";
import PurgeManager from "@/app/components/PurgeManager";

export const dynamic = "force-dynamic";

export default async function RgpdPage() {
  const preview = await listPurgeable();
  return (
    <div>
      <div className="mb-5">
        <h1 className="text-2xl font-bold" style={{ color: "var(--sjr-ink)" }}>Conformité (RGPD)</h1>
        <p className="text-sm" style={{ color: "var(--sjr-muted)" }}>
          Les candidatures non recrutées sont conservées {preview.years} ans maximum, puis supprimées.
          La purge s'exécute automatiquement chaque nuit ; vous pouvez aussi la lancer manuellement ci-dessous.
        </p>
      </div>
      <PurgeManager preview={preview} />
    </div>
  );
}

SJREOF

cat > "app/components/Icons.js" << 'SJREOF'
const base = { fill: "none", stroke: "currentColor", strokeWidth: 1.8, strokeLinecap: "round", strokeLinejoin: "round" };
const S = ({ children, className = "w-5 h-5", ...p }) => (
  <svg viewBox="0 0 24 24" className={className} {...base} {...p}>{children}</svg>
);
export const IconSearch = (p) => (<S {...p}><circle cx="11" cy="11" r="7" /><path d="m21 21-4.3-4.3" /></S>);
export const IconPin = (p) => (<S {...p}><path d="M12 21s7-6.2 7-11a7 7 0 1 0-14 0c0 4.8 7 11 7 11Z" /><circle cx="12" cy="10" r="2.5" /></S>);
export const IconClock = (p) => (<S {...p}><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></S>);
export const IconBriefcase = (p) => (<S {...p}><rect x="3" y="7" width="18" height="13" rx="2" /><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 12h18" /></S>);
export const IconUsers = (p) => (<S {...p}><circle cx="9" cy="8" r="3.2" /><path d="M2.5 20a6.5 6.5 0 0 1 13 0M16 5.5a3 3 0 0 1 0 5.4M17 14.2A6 6 0 0 1 21.5 20" /></S>);
export const IconBuilding = (p) => (<S {...p}><rect x="4" y="3" width="16" height="18" rx="1.5" /><path d="M8 7h2M14 7h2M8 11h2M14 11h2M8 15h2M14 15h2M10 21v-3h4v3" /></S>);
export const IconChevron = (p) => (<S {...p}><path d="m9 6 6 6-6 6" /></S>);
export const IconArrowLeft = (p) => (<S {...p}><path d="M19 12H5M11 6l-6 6 6 6" /></S>);
export const IconCheck = (p) => (<S {...p}><path d="M20 6 9 17l-5-5" /></S>);
export const IconDownload = (p) => (<S {...p}><path d="M12 3v12M7 11l5 5 5-5M4 21h16" /></S>);
export const IconLogout = (p) => (<S {...p}><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9" /></S>);
export const IconDoc = (p) => (<S {...p}><path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z" /><path d="M14 3v5h5M9 13h6M9 17h6" /></S>);
export const IconLayers = (p) => (<S {...p}><path d="m12 3 9 5-9 5-9-5 9-5ZM3 13l9 5 9-5" /></S>);
export const IconGauge = (p) => (<S {...p}><path d="M12 13.5 15 9M21 14a9 9 0 1 0-18 0" /><circle cx="12" cy="14" r="1.4" /></S>);
export const IconAlert = (p) => (<S {...p}><path d="M12 9v4M12 17h.01M10.3 3.9 2 18a1.7 1.7 0 0 0 1.5 2.6h17A1.7 1.7 0 0 0 22 18L13.7 3.9a2 2 0 0 0-3.4 0Z" /></S>);
export const IconGrid = (p) => (<S {...p}><rect x="3" y="3" width="7" height="7" rx="1" /><rect x="14" y="3" width="7" height="7" rx="1" /><rect x="3" y="14" width="7" height="7" rx="1" /><rect x="14" y="14" width="7" height="7" rx="1" /></S>);
export const IconInbox = (p) => (<S {...p}><path d="M3 13h4l2 3h6l2-3h4" /><path d="M5 5h14l3 8v6a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1v-6z" /></S>);
export const IconStar = (p) => (<S {...p}><path d="M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8-5.2-2.7L6.8 19.7l1-5.8L3.5 9.7l5.9-.9z" /></S>);
export const IconPlus = (p) => (<S {...p}><path d="M12 5v14M5 12h14" /></S>);
export const IconSettings = (p) => (<S {...p}><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-1.8-.3 1.6 1.6 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.6 1.6 0 0 0-1-1.5 1.6 1.6 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.6 1.6 0 0 0 .3-1.8 1.6 1.6 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.6 1.6 0 0 0 1.5-1 1.6 1.6 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.6 1.6 0 0 0 1.8.3H9a1.6 1.6 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.6 1.6 0 0 0 1 1.5 1.6 1.6 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0-.3 1.8V9a1.6 1.6 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.6 1.6 0 0 0-1.5 1Z" /></S>);
export const IconPencil = (p) => (<S {...p}><path d="M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z" /></S>);
export const IconTrash = (p) => (<S {...p}><path d="M3 6h18M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6M10 11v6M14 11v6" /></S>);
export const IconShield = (p) => (<S {...p}><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z" /><path d="M9 12l2 2 4-4" /></S>);

SJREOF

cat > "app/components/AdminNav.js" << 'SJREOF'
"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { IconGrid, IconBriefcase, IconInbox, IconStar, IconSettings, IconShield } from "./Icons";

const ITEMS = [
  { href: "/admin", label: "Tableau de bord", icon: IconGrid, exact: true },
  { href: "/admin/offres", label: "Offres", icon: IconBriefcase },
  { href: "/admin/candidatures", label: "Candidatures", icon: IconInbox },
  { href: "/admin/recrutements", label: "Recrutements finalisés", icon: IconStar },
  { href: "/admin/parametres", label: "Paramètres", icon: IconSettings },
  { href: "/admin/rgpd", label: "Conformité (RGPD)", icon: IconShield },
];

export default function AdminNav() {
  const path = usePathname();
  return (
    <nav className="space-y-1">
      {ITEMS.map(({ href, label, icon: Icon, exact }) => {
        const active = exact ? path === href : path.startsWith(href);
        return (
          <Link key={href} href={href}
            className={`flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors ${active ? "text-white" : "hover:bg-white"}`}
            style={active ? { background: "var(--sjr-primary)" } : { color: "var(--sjr-ink)" }}>
            <Icon className="h-5 w-5" />
            {label}
          </Link>
        );
      })}
    </nav>
  );
}

SJREOF

cat > "vercel.json" << 'SJREOF'
{
  "regions": ["dub1"],
  "crons": [
    { "path": "/api/cron/purge", "schedule": "0 3 * * *" }
  ]
}

SJREOF

echo "=== Purge RGPD installée. Lance : npm run build ==="
