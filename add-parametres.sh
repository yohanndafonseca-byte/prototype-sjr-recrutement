#!/usr/bin/env bash
# Ajoute le module Paramètres (secteurs/directions/pôles). À lancer à la racine du projet.
set -e
mkdir -p "app/api/admin/parametres" "app/admin/(dash)/parametres"

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
SJREOF

cat > "lib/taxonomy.js" << 'SJREOF'
import { dbGet, dbRun } from "./db.js";

const clean = (s) => String(s || "").trim();

async function count(sql, args) {
  const r = await dbGet(sql, args);
  return Number(r.n) || 0;
}

/* ---------- SECTEURS ---------- */
export async function createSector(name) {
  name = clean(name);
  if (!name) throw new Error("Le nom est obligatoire.");
  const r = await dbGet("SELECT COALESCE(MAX(sort),0)+1 AS s FROM sectors");
  const info = await dbRun("INSERT INTO sectors (name, sort) VALUES (?,?)", [name, Number(r.s)]);
  return info.lastInsertRowid;
}
export async function renameSector(id, name) {
  name = clean(name);
  if (!name) throw new Error("Le nom est obligatoire.");
  await dbRun("UPDATE sectors SET name=? WHERE id=?", [name, id]);
}
export async function deleteSector(id) {
  const dirs = await count("SELECT COUNT(*) AS n FROM directions WHERE sector_id=?", [id]);
  if (dirs > 0) throw new Error("Ce secteur contient des directions. Supprimez-les d'abord.");
  const used = await count("SELECT COUNT(*) AS n FROM offers WHERE sector_id=?", [id]);
  if (used > 0) throw new Error(`Impossible : ${used} offre(s) utilisent ce secteur.`);
  await dbRun("DELETE FROM sectors WHERE id=?", [id]);
}

/* ---------- DIRECTIONS ---------- */
export async function createDirection(sectorId, name) {
  name = clean(name);
  if (!sectorId) throw new Error("Secteur manquant.");
  if (!name) throw new Error("Le nom est obligatoire.");
  const info = await dbRun("INSERT INTO directions (sector_id, name) VALUES (?,?)", [sectorId, name]);
  return info.lastInsertRowid;
}
export async function renameDirection(id, name) {
  name = clean(name);
  if (!name) throw new Error("Le nom est obligatoire.");
  await dbRun("UPDATE directions SET name=? WHERE id=?", [name, id]);
}
export async function deleteDirection(id) {
  const poles = await count("SELECT COUNT(*) AS n FROM poles WHERE direction_id=?", [id]);
  if (poles > 0) throw new Error("Cette direction contient des pôles. Supprimez-les d'abord.");
  const used = await count("SELECT COUNT(*) AS n FROM offers WHERE direction_id=?", [id]);
  if (used > 0) throw new Error(`Impossible : ${used} offre(s) utilisent cette direction.`);
  await dbRun("DELETE FROM directions WHERE id=?", [id]);
}

/* ---------- PÔLES ---------- */
export async function createPole(directionId, name) {
  name = clean(name);
  if (!directionId) throw new Error("Direction manquante.");
  if (!name) throw new Error("Le nom est obligatoire.");
  const info = await dbRun("INSERT INTO poles (direction_id, name) VALUES (?,?)", [directionId, name]);
  return info.lastInsertRowid;
}
export async function renamePole(id, name) {
  name = clean(name);
  if (!name) throw new Error("Le nom est obligatoire.");
  await dbRun("UPDATE poles SET name=? WHERE id=?", [name, id]);
}
export async function deletePole(id) {
  const used = await count("SELECT COUNT(*) AS n FROM offers WHERE pole_id=?", [id]);
  if (used > 0) throw new Error(`Impossible : ${used} offre(s) utilisent ce pôle.`);
  await dbRun("DELETE FROM poles WHERE id=?", [id]);
}
SJREOF

cat > "app/api/admin/parametres/route.js" << 'SJREOF'
import { NextResponse } from "next/server";
import * as T from "@/lib/taxonomy";

export const runtime = "nodejs";

const MAP = {
  sector: { create: (b) => T.createSector(b.name), rename: (b) => T.renameSector(b.id, b.name), delete: (b) => T.deleteSector(b.id) },
  direction: { create: (b) => T.createDirection(b.parentId, b.name), rename: (b) => T.renameDirection(b.id, b.name), delete: (b) => T.deleteDirection(b.id) },
  pole: { create: (b) => T.createPole(b.parentId, b.name), rename: (b) => T.renamePole(b.id, b.name), delete: (b) => T.deletePole(b.id) },
};

export async function POST(req) {
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
SJREOF

cat > "app/components/ParametresManager.js" << 'SJREOF'
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
SJREOF

cat > "app/admin/(dash)/parametres/page.js" << 'SJREOF'
import { getMetaTree } from "@/lib/offers";
import ParametresManager from "@/app/components/ParametresManager";

export const dynamic = "force-dynamic";

export default async function ParametresPage() {
  const tree = await getMetaTree();
  return (
    <div>
      <div className="mb-5">
        <h1 className="text-2xl font-bold" style={{ color: "var(--sjr-ink)" }}>Paramètres</h1>
        <p className="text-sm" style={{ color: "var(--sjr-muted)" }}>
          Gérez les secteurs, directions et pôles proposés dans le formulaire des offres.
          Renommer est sans risque ; un élément utilisé par des offres ne peut pas être supprimé.
        </p>
      </div>
      <ParametresManager tree={tree} />
    </div>
  );
}
SJREOF

cat > "app/components/AdminNav.js" << 'SJREOF'
"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { IconGrid, IconBriefcase, IconInbox, IconStar, IconSettings } from "./Icons";

const ITEMS = [
  { href: "/admin", label: "Tableau de bord", icon: IconGrid, exact: true },
  { href: "/admin/offres", label: "Offres", icon: IconBriefcase },
  { href: "/admin/candidatures", label: "Candidatures", icon: IconInbox },
  { href: "/admin/recrutements", label: "Recrutements finalisés", icon: IconStar },
  { href: "/admin/parametres", label: "Paramètres", icon: IconSettings },
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

echo "=== Module Paramètres installé. Lance : npm run build ==="
