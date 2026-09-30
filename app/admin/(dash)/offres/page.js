import Link from "next/link";
import { IconPlus, IconChevron } from "@/app/components/Icons";
import { OfferBadge } from "@/app/components/StatusBadge";
import PositionMeter from "@/app/components/PositionMeter";
import QuerySelect from "@/app/components/QuerySelect";
import { listAdminOffers, getMetaTree } from "@/lib/offers";
import { fmtDate } from "@/lib/format";

export const dynamic = "force-dynamic";

const TABS = [
  { key: "", label: "Toutes" },
  { key: "publiee", label: "Publiées" },
  { key: "brouillon", label: "Brouillons" },
  { key: "expiree", label: "Expirées" },
  { key: "pourvue", label: "Pourvues" },
];

export default async function OffresPage({ searchParams }) {
  const statut = searchParams?.statut || "";
  const secteur = searchParams?.secteur || "";
  let offers = await listAdminOffers({ status: statut || null });
  if (secteur) offers = offers.filter((o) => String(o.sector_id) === String(secteur));

  const tree = await getMetaTree();
  const sectorOptions = tree.map((s) => ({ value: String(s.id), label: s.name }));

  return (
    <div>
      <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold" style={{ color: "var(--sjr-ink)" }}>Offres</h1>
          <p className="text-sm" style={{ color: "var(--sjr-muted)" }}>{offers.length} offre{offers.length > 1 ? "s" : ""} affichée{offers.length > 1 ? "s" : ""}</p>
        </div>
        <Link href="/admin/offres/nouvelle" className="btn-primary"><IconPlus className="h-4 w-4" /> Nouvelle offre</Link>
      </div>

      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div className="flex flex-wrap gap-1.5 rounded-lg p-1" style={{ background: "#eef3f8" }}>
          {TABS.map((t) => {
            const active = statut === t.key;
            const qs = new URLSearchParams();
            if (t.key) qs.set("statut", t.key);
            if (secteur) qs.set("secteur", secteur);
            return (
              <Link key={t.key || "all"} href={`/admin/offres${qs.toString() ? "?" + qs.toString() : ""}`}
                className={`rounded-md px-3 py-1.5 text-sm font-medium ${active ? "bg-white shadow-sm" : ""}`}
                style={{ color: active ? "var(--sjr-primary)" : "var(--sjr-muted)" }}>{t.label}</Link>
            );
          })}
        </div>
        <QuerySelect param="secteur" value={secteur} options={sectorOptions} allLabel="Tous les secteurs" />
      </div>

      <div className="space-y-3">
        {offers.length === 0 && (
          <div className="card p-10 text-center">
            <p className="font-medium" style={{ color: "var(--sjr-ink)" }}>Aucune offre dans cette vue.</p>
            <Link href="/admin/offres/nouvelle" className="link mt-2 inline-block text-sm">Créer une offre</Link>
          </div>
        )}
        {offers.map((o) => (
          <Link key={o.id} href={`/admin/offres/${o.id}`} className="card group flex items-center gap-4 p-4 transition-all hover:shadow-pop">
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2">
                <span className="truncate font-semibold" style={{ color: "var(--sjr-ink)" }}>{o.title}</span>
                <OfferBadge status={o.status} />
                <span className="text-xs" style={{ color: "var(--sjr-muted)" }}>{o.reference}</span>
              </div>
              <div className="mt-1 text-xs" style={{ color: "var(--sjr-muted)" }}>
                {o.direction_name} · {o.sector_name} · {o.contract_type}
                {o.deadline ? ` · limite ${fmtDate(o.deadline)}` : ""}
              </div>
            </div>
            <div className="hidden w-48 shrink-0 sm:block">
              <PositionMeter total={o.positions_total} filled={o.positions_filled} remaining={o.positions_remaining} size="sm" />
            </div>
            <div className="shrink-0 text-center">
              <div className="text-lg font-bold" style={{ color: "var(--sjr-ink)" }}>{o.applications_count}</div>
              <div className="text-[11px]" style={{ color: "var(--sjr-muted)" }}>candidat.</div>
            </div>
            <IconChevron className="h-5 w-5 shrink-0 text-slate-300" />
          </Link>
        ))}
      </div>
    </div>
  );
}
