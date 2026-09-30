import Link from "next/link";
import { notFound } from "next/navigation";
import { OfferBadge, AppBadge } from "@/app/components/StatusBadge";
import PositionMeter from "@/app/components/PositionMeter";
import { IconArrowLeft, IconChevron } from "@/app/components/Icons";
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
        <Link href={`/admin/offres/${o.id}/modifier`} className="btn-primary">Modifier l'offre</Link>
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
