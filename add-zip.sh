#!/usr/bin/env bash
# Ajoute le téléchargement ZIP des dossiers (à lancer à la racine du projet).
set -e
mkdir -p "app/api/admin/candidatures/export-zip"

cat > "lib/zip.js" << 'SJREOF'
import JSZip from "jszip";
import { getApplication, listDocumentsWithContent } from "./applications.js";
import { buildDossierPdf } from "./dossier.js";

// Nom de fichier sûr : lettres (accents ok), chiffres, espace, _ et -
function safeName(s) {
  return String(s || "").replace(/[^\p{L}\p{N} _-]/gu, "").replace(/\s+/g, " ").trim();
}

// Construit un ZIP : un dossier PDF fusionné (page de garde + pièces) par candidat,
// nommé "NOM Prénom.pdf".
export async function buildApplicationsZip(apps) {
  const zip = new JSZip();
  const used = {};
  let count = 0;
  for (const a of apps) {
    const full = await getApplication(a.id);
    if (!full) continue;
    const docs = await listDocumentsWithContent(a.id);
    const pdf = await buildDossierPdf(full, docs);
    let base = safeName(`${a.last_name || ""} ${a.first_name || ""}`) || `candidat_${a.id}`;
    let name = base, i = 2;
    while (used[name]) name = `${base} (${i++})`; // évite les écrasements (homonymes)
    used[name] = true;
    zip.file(`${name}.pdf`, pdf);
    count++;
  }
  if (count === 0) {
    zip.file("AUCUNE_CANDIDATURE.txt", "Aucune candidature à télécharger pour ce filtre.");
  }
  return zip.generateAsync({ type: "nodebuffer" });
}
SJREOF

cat > "app/api/admin/candidatures/export-zip/route.js" << 'SJREOF'
import { NextResponse } from "next/server";
import { listApplications } from "@/lib/applications";
import { buildApplicationsZip } from "@/lib/zip";

export const runtime = "nodejs";

const IN_PROGRESS = ["a_etudier", "preselectionnee", "entretien", "retenue"];

export async function GET(req) {
  const sp = req.nextUrl.searchParams;
  const statut = sp.get("statut") || "";
  const offre = sp.get("offre") || "";

  let filter = {};
  if (statut === "en_cours") filter.statusIn = IN_PROGRESS;
  else if (statut) filter.status = statut;
  let rows = await listApplications(filter);
  if (offre) rows = rows.filter((a) => String(a.offer_id) === String(offre));

  const buf = await buildApplicationsZip(rows);
  const date = new Date().toISOString().slice(0, 10);
  return new NextResponse(buf, {
    headers: {
      "Content-Type": "application/zip",
      "Content-Disposition": `attachment; filename="Dossiers_SJR_${date}.zip"`,
      "Content-Length": String(buf.length),
    },
  });
}
SJREOF

cat > "app/admin/(dash)/candidatures/page.js" << 'SJREOF'
import Link from "next/link";
import { AppBadge } from "@/app/components/StatusBadge";
import QuerySelect from "@/app/components/QuerySelect";
import { IconChevron, IconDownload } from "@/app/components/Icons";
import { listApplications } from "@/lib/applications";
import { listAdminOffers } from "@/lib/offers";
import { fmtDateTime, initials } from "@/lib/format";

export const dynamic = "force-dynamic";

const IN_PROGRESS = ["a_etudier", "preselectionnee", "entretien", "retenue"];
const TABS = [
  { key: "", label: "Toutes" },
  { key: "nouvelle", label: "Nouvelles" },
  { key: "en_cours", label: "En cours" },
  { key: "retenue", label: "Retenues" },
  { key: "recrute", label: "Recrutées" },
  { key: "refusee", label: "Refusées" },
];

export default async function CandidaturesPage({ searchParams }) {
  const statut = searchParams?.statut || "";
  const offre = searchParams?.offre || "";

  let filter = {};
  if (statut === "en_cours") filter.statusIn = IN_PROGRESS;
  else if (statut) filter.status = statut;
  let apps = await listApplications(filter);
  if (offre) apps = apps.filter((a) => String(a.offer_id) === String(offre));

  const offerOptions = (await listAdminOffers({})).map((o) => ({ value: String(o.id), label: `${o.title}` }));

  return (
    <div>
      <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold" style={{ color: "var(--sjr-ink)" }}>Candidatures</h1>
          <p className="text-sm" style={{ color: "var(--sjr-muted)" }}>{apps.length} candidature{apps.length > 1 ? "s" : ""} affichée{apps.length > 1 ? "s" : ""}</p>
        </div>
        <div className="flex flex-wrap gap-2">
          <a
            href={`/api/admin/candidatures/export-zip${(() => { const p = new URLSearchParams(); if (statut) p.set("statut", statut); if (offre) p.set("offre", offre); const s = p.toString(); return s ? "?" + s : ""; })()}`}
            className="btn-outline"
          >
            <IconDownload className="h-4 w-4" /> Télécharger les dossiers (ZIP)
          </a>
          <a
            href={`/api/admin/candidatures/export${(() => { const p = new URLSearchParams(); if (statut) p.set("statut", statut); if (offre) p.set("offre", offre); const s = p.toString(); return s ? "?" + s : ""; })()}`}
            className="btn-outline"
          >
            <IconDownload className="h-4 w-4" /> Exporter (Excel)
          </a>
        </div>
      </div>

      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div className="flex flex-wrap gap-1.5 rounded-lg p-1" style={{ background: "#eef3f8" }}>
          {TABS.map((t) => {
            const active = statut === t.key;
            const qs = new URLSearchParams();
            if (t.key) qs.set("statut", t.key);
            if (offre) qs.set("offre", offre);
            return (
              <Link key={t.key || "all"} href={`/admin/candidatures${qs.toString() ? "?" + qs.toString() : ""}`}
                className={`rounded-md px-3 py-1.5 text-sm font-medium ${active ? "bg-white shadow-sm" : ""}`}
                style={{ color: active ? "var(--sjr-primary)" : "var(--sjr-muted)" }}>{t.label}</Link>
            );
          })}
        </div>
        <QuerySelect param="offre" value={offre} options={offerOptions} allLabel="Toutes les offres" />
      </div>

      <div className="card divide-y overflow-hidden" style={{ borderColor: "var(--sjr-line)" }}>
        {apps.length === 0 && <p className="p-10 text-center text-sm" style={{ color: "var(--sjr-muted)" }}>Aucune candidature dans cette vue.</p>}
        {apps.map((a) => (
          <Link key={a.id} href={`/admin/candidatures/${a.id}`} className="flex items-center gap-3 p-4 hover:bg-slate-50">
            <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full text-xs font-bold" style={{ background: "var(--sjr-primary-soft)", color: "var(--sjr-primary-dark)" }}>{initials(a.first_name, a.last_name)}</span>
            <div className="min-w-0 flex-1">
              <div className="truncate text-sm font-semibold" style={{ color: "var(--sjr-ink)" }}>{a.first_name} {a.last_name}</div>
              <div className="truncate text-xs" style={{ color: "var(--sjr-muted)" }}>{a.offer_title} · {a.public_ref} · {fmtDateTime(a.created_at)}</div>
            </div>
            <AppBadge status={a.status} />
            <IconChevron className="h-4 w-4 shrink-0 text-slate-300" />
          </Link>
        ))}
      </div>
    </div>
  );
}
SJREOF

cat > "app/admin/(dash)/offres/[id]/page.js" << 'SJREOF'
import Link from "next/link";
import { notFound } from "next/navigation";
import { OfferBadge, AppBadge } from "@/app/components/StatusBadge";
import PositionMeter from "@/app/components/PositionMeter";
import { IconArrowLeft, IconChevron, IconDownload } from "@/app/components/Icons";
import { getOffer } from "@/lib/offers";
import { listByOffer } from "@/lib/applications";
import { fmtDate, fmtDateTime, initials } from "@/lib/format";

export const dynamic = "force-dynamic";

function Row({ label, value }) {
  return (
    <div className="flex justify-between gap-4 py-2 text-sm">
      <span style={{ color: "var(--sjr-muted)" }}>{label}</span>
      <span className="text-right font-medium" style={{ color: "var(--sjr-ink)" }}>{value || "—"}</span>
    </div>
  );
}
function Block({ title, text }) {
  if (!text) return null;
  return <div className="mt-4"><div className="text-sm font-semibold" style={{ color: "var(--sjr-ink)" }}>{title}</div><div className="prose-block mt-1 text-sm" style={{ color: "var(--sjr-muted)" }}>{text}</div></div>;
}

export default async function OffreRH({ params }) {
  const o = await getOffer(Number(params.id));
  if (!o) notFound();
  const apps = await listByOffer(o.id);

  return (
    <div>
      <Link href="/admin/offres" className="link inline-flex items-center gap-1.5 text-sm"><IconArrowLeft className="h-4 w-4" /> Retour aux offres</Link>

      <div className="mt-3 flex flex-wrap items-start justify-between gap-4">
        <div>
          <div className="flex flex-wrap items-center gap-2">
            <h1 className="text-2xl font-bold" style={{ color: "var(--sjr-ink)" }}>{o.title}</h1>
            <OfferBadge status={o.status} />
          </div>
          <p className="mt-1 text-sm" style={{ color: "var(--sjr-muted)" }}>{o.reference} · {o.direction_name} · {o.sector_name}</p>
        </div>
        <div className="flex flex-wrap gap-2">
          {apps.length > 0 && (
            <a href={`/api/admin/candidatures/export-zip?offre=${o.id}`} className="btn-outline">
              <IconDownload className="h-4 w-4" /> Télécharger les dossiers (ZIP)
            </a>
          )}
          <Link href={`/admin/offres/${o.id}/modifier`} className="btn-primary">Modifier l'offre</Link>
        </div>
      </div>

      <div className="mt-5 grid gap-6 lg:grid-cols-[340px_1fr]">
        {/* Colonne infos */}
        <div className="space-y-4">
          <div className="card p-5">
            <div className="text-sm font-semibold" style={{ color: "var(--sjr-ink)" }}>{o.positions_total} poste{o.positions_total > 1 ? "s" : ""} à pourvoir</div>
            <div className="mt-3"><PositionMeter total={o.positions_total} filled={o.positions_filled} remaining={o.positions_remaining} /></div>
            <p className="mt-3 text-xs" style={{ color: "var(--sjr-muted)" }}>Le décompte se met à jour automatiquement lorsqu'une candidature passe au statut « Recruté ».</p>
          </div>
          <div className="card p-5">
            <Row label="Statut" value={<OfferBadge status={o.status} />} />
            <Row label="Type de contrat" value={o.contract_type} />
            <Row label="Temps de travail" value={o.work_time} />
            <Row label="Publiée le" value={o.published_at ? fmtDate(o.published_at) : "—"} />
            <Row label="Date limite" value={o.deadline ? fmtDate(o.deadline) : "—"} />
            <Row label="Pôle" value={o.pole_name} />
            <Row label="Localisation" value={o.location} />
          </div>
          <div className="card p-5">
            <Block title="Missions" text={o.missions} />
            <Block title="Profil recherché" text={o.profile} />
            <Block title="Conditions" text={o.conditions} />
            <Block title="Informations complémentaires" text={o.extra_info} />
          </div>
        </div>

        {/* Candidatures */}
        <div className="card p-5">
          <div className="mb-3 flex items-center justify-between">
            <h2 className="font-semibold" style={{ color: "var(--sjr-ink)" }}>Candidatures</h2>
            <span className="text-sm" style={{ color: "var(--sjr-muted)" }}>{apps.length} au total</span>
          </div>
          <div className="divide-y" style={{ borderColor: "var(--sjr-line)" }}>
            {apps.length === 0 && <p className="py-8 text-center text-sm" style={{ color: "var(--sjr-muted)" }}>Aucune candidature pour cette offre.</p>}
            {apps.map((a) => (
              <Link key={a.id} href={`/admin/candidatures/${a.id}`} className="flex items-center gap-3 py-3 hover:opacity-80">
                <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full text-xs font-bold" style={{ background: "var(--sjr-primary-soft)", color: "var(--sjr-primary-dark)" }}>{initials(a.first_name, a.last_name)}</span>
                <div className="min-w-0 flex-1">
                  <div className="truncate text-sm font-medium" style={{ color: "var(--sjr-ink)" }}>{a.first_name} {a.last_name}</div>
                  <div className="truncate text-xs" style={{ color: "var(--sjr-muted)" }}>Reçue le {fmtDateTime(a.created_at)}</div>
                </div>
                <AppBadge status={a.status} />
                <IconChevron className="h-4 w-4 shrink-0 text-slate-300" />
              </Link>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
SJREOF

echo "=== 4 fichiers écrits. Lance maintenant : npm install jszip ==="
