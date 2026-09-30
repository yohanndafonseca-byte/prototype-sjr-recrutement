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
        <a
          href={`/api/admin/candidatures/export${(() => { const p = new URLSearchParams(); if (statut) p.set("statut", statut); if (offre) p.set("offre", offre); const s = p.toString(); return s ? "?" + s : ""; })()}`}
          className="btn-outline"
        >
          <IconDownload className="h-4 w-4" /> Exporter (Excel)
        </a>
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
