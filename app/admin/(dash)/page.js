import Link from "next/link";
import { IconInbox, IconLayers, IconBriefcase, IconAlert, IconChevron } from "@/app/components/Icons";
import { AppBadge } from "@/app/components/StatusBadge";
import PositionMeter from "@/app/components/PositionMeter";
import { dashboardStats } from "@/lib/offers";
import { listApplications } from "@/lib/applications";
import { fmtDate, fmtDateTime, daysUntil } from "@/lib/format";

export const dynamic = "force-dynamic";

function StatTile({ href, value, label, icon: Icon, tone = "primary", cta }) {
  const bg = tone === "accent" ? "var(--sjr-accent)" : tone === "amber" ? "#d97706" : tone === "indigo" ? "#4f46e5" : "var(--sjr-primary)";
  return (
    <Link href={href} className="card group flex flex-col p-5 transition-all hover:-translate-y-0.5 hover:shadow-pop">
      <div className="flex items-center justify-between">
        <span className="grid h-10 w-10 place-items-center rounded-lg text-white" style={{ background: bg }}><Icon className="h-5 w-5" /></span>
        <IconChevron className="h-5 w-5 text-slate-300 transition-transform group-hover:translate-x-0.5" />
      </div>
      <div className="mt-4 text-3xl font-bold" style={{ color: "var(--sjr-ink)" }}>{value}</div>
      <div className="text-sm" style={{ color: "var(--sjr-muted)" }}>{label}</div>
      <div className="mt-3 text-xs font-semibold" style={{ color: bg }}>{cta} →</div>
    </Link>
  );
}

export default async function Dashboard() {
  const s = await dashboardStats();
  const latestNew = (await listApplications({ status: "nouvelle" })).slice(0, 5);

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold" style={{ color: "var(--sjr-ink)" }}>Tableau de bord</h1>
        <p className="text-sm" style={{ color: "var(--sjr-muted)" }}>Vue d'ensemble du recrutement · {s.totalOffers} offres · {s.recruited} recrutement{s.recruited > 1 ? "s" : ""} finalisé{s.recruited > 1 ? "s" : ""}</p>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatTile href="/admin/candidatures?statut=nouvelle" value={s.newApps} label="Nouvelles candidatures" icon={IconInbox} tone="accent" cta="Voir les candidatures" />
        <StatTile href="/admin/candidatures?statut=en_cours" value={s.inProgress} label="Candidatures en cours" icon={IconLayers} tone="primary" cta="Suivre le processus" />
        <StatTile href="/admin/offres?statut=publiee" value={s.published} label="Offres publiées" icon={IconBriefcase} tone="indigo" cta="Gérer les offres" />
        <StatTile href="/admin/offres?statut=publiee" value={s.soon.length} label="Offres à échéance proche" icon={IconAlert} tone="amber" cta="Anticiper les fins" />
      </div>

      <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-2">
        {/* Dernières nouvelles candidatures */}
        <section className="card p-5">
          <div className="mb-3 flex items-center justify-between">
            <h2 className="font-semibold" style={{ color: "var(--sjr-ink)" }}>Dernières candidatures reçues</h2>
            <Link href="/admin/candidatures?statut=nouvelle" className="link text-sm">Tout voir</Link>
          </div>
          <div className="divide-y" style={{ borderColor: "var(--sjr-line)" }}>
            {latestNew.length === 0 && <p className="py-6 text-center text-sm" style={{ color: "var(--sjr-muted)" }}>Aucune nouvelle candidature.</p>}
            {latestNew.map((a) => (
              <Link key={a.id} href={`/admin/candidatures/${a.id}`} className="flex items-center justify-between gap-3 py-3 hover:opacity-80">
                <div className="min-w-0">
                  <div className="truncate text-sm font-medium" style={{ color: "var(--sjr-ink)" }}>{a.first_name} {a.last_name}</div>
                  <div className="truncate text-xs" style={{ color: "var(--sjr-muted)" }}>{a.offer_title} · {fmtDateTime(a.created_at)}</div>
                </div>
                <AppBadge status={a.status} />
              </Link>
            ))}
          </div>
        </section>

        {/* Offres bientôt à échéance */}
        <section className="card p-5">
          <div className="mb-3 flex items-center justify-between">
            <h2 className="font-semibold" style={{ color: "var(--sjr-ink)" }}>Offres arrivant à échéance</h2>
            <Link href="/admin/offres?statut=publiee" className="link text-sm">Toutes les offres</Link>
          </div>
          <div className="space-y-3">
            {s.soon.length === 0 && <p className="py-6 text-center text-sm" style={{ color: "var(--sjr-muted)" }}>Aucune échéance dans les 14 prochains jours.</p>}
            {s.soon.map((o) => {
              const d = daysUntil(o.deadline);
              return (
                <Link key={o.id} href={`/admin/offres/${o.id}`} className="block rounded-lg border p-3 hover:shadow-card" style={{ borderColor: "var(--sjr-line)" }}>
                  <div className="flex items-center justify-between gap-3">
                    <span className="truncate text-sm font-medium" style={{ color: "var(--sjr-ink)" }}>{o.title}</span>
                    <span className="shrink-0 rounded-full bg-amber-50 px-2 py-0.5 text-xs font-semibold text-amber-700">{d} j</span>
                  </div>
                  <div className="mt-1 text-xs" style={{ color: "var(--sjr-muted)" }}>Limite : {fmtDate(o.deadline)} · {o.applications_count} candidature{o.applications_count > 1 ? "s" : ""}</div>
                  <div className="mt-2"><PositionMeter total={o.positions_total} filled={o.positions_filled} remaining={o.positions_remaining} size="sm" /></div>
                </Link>
              );
            })}
          </div>
        </section>
      </div>
    </div>
  );
}
