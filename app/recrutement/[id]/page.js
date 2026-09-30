import Link from "next/link";
import { notFound } from "next/navigation";
import PublicHeader from "@/app/components/PublicHeader";
import PublicFooter from "@/app/components/PublicFooter";
import PositionMeter from "@/app/components/PositionMeter";
import { IconArrowLeft, IconBriefcase, IconClock, IconPin, IconBuilding, IconLayers, IconUsers } from "@/app/components/Icons";
import { getPublicOffer } from "@/lib/offers";
import { fmtDate, daysUntil } from "@/lib/format";

export const dynamic = "force-dynamic";

function Info({ icon: Icon, label, value }) {
  return (
    <div className="flex items-start gap-3">
      <Icon className="mt-0.5 h-5 w-5 shrink-0" style={{ color: "var(--sjr-primary)" }} />
      <div>
        <div className="text-xs" style={{ color: "var(--sjr-muted)" }}>{label}</div>
        <div className="text-sm font-medium" style={{ color: "var(--sjr-ink)" }}>{value || "—"}</div>
      </div>
    </div>
  );
}
function Block({ title, text }) {
  if (!text) return null;
  return (
    <section className="mt-8">
      <h2 className="text-lg font-semibold" style={{ color: "var(--sjr-ink)" }}>{title}</h2>
      <div className="prose-block mt-2 text-[15px]" style={{ color: "var(--sjr-ink)" }}>{text}</div>
    </section>
  );
}

export default async function OfferDetail({ params }) {
  const o = await getPublicOffer(Number(params.id));
  if (!o) notFound();
  const d = daysUntil(o.deadline);

  return (
    <div className="flex min-h-screen flex-col">
      <PublicHeader />
      <main className="flex-1">
        <div className="container-sjr py-8">
          <Link href="/recrutement" className="link inline-flex items-center gap-1.5 text-sm">
            <IconArrowLeft className="h-4 w-4" /> Retour aux offres
          </Link>

          <div className="mt-5 grid gap-6 lg:grid-cols-[1fr_320px]">
            {/* Colonne principale */}
            <div className="card p-6 md:p-8">
              <p className="eyebrow">{o.reference}</p>
              <h1 className="mt-1 text-2xl font-bold md:text-3xl" style={{ color: "var(--sjr-ink)" }}>{o.title}</h1>
              <div className="mt-3 flex flex-wrap items-center gap-x-5 gap-y-2 text-sm" style={{ color: "var(--sjr-muted)" }}>
                <span className="inline-flex items-center gap-1.5"><IconBriefcase className="h-4 w-4" />{o.contract_type}</span>
                <span className="inline-flex items-center gap-1.5"><IconClock className="h-4 w-4" />{o.work_time}</span>
                <span className="inline-flex items-center gap-1.5"><IconPin className="h-4 w-4" />{o.location}</span>
              </div>

              <Block title="Missions" text={o.missions} />
              <Block title="Profil recherché" text={o.profile} />
              <Block title="Conditions" text={o.conditions} />
              <Block title="Informations complémentaires" text={o.extra_info} />

              <div className="mt-10 border-t pt-6" style={{ borderColor: "var(--sjr-line)" }}>
                <Link href={`/recrutement/${o.id}/candidater`} className="btn-primary w-full sm:w-auto">
                  Candidater à cette offre
                </Link>
                <p className="mt-2 text-xs" style={{ color: "var(--sjr-muted)" }}>
                  Aucun compte n'est nécessaire. Le poste concerné est automatiquement associé à votre candidature.
                </p>
              </div>
            </div>

            {/* Encadré latéral */}
            <aside className="space-y-4">
              <div className="card p-5">
                <div className="text-sm font-semibold" style={{ color: "var(--sjr-ink)" }}>
                  {o.positions_total} poste{o.positions_total > 1 ? "s" : ""} à pourvoir
                </div>
                <div className="mt-3"><PositionMeter total={o.positions_total} filled={o.positions_filled} remaining={o.positions_remaining} /></div>
              </div>
              <div className="card space-y-4 p-5">
                <Info icon={IconClock} label="Date limite de candidature" value={o.deadline ? fmtDate(o.deadline) : "Non précisée"} />
                {d != null && d <= 14 && <div className="rounded-lg bg-amber-50 px-3 py-2 text-xs font-medium text-amber-700">Plus que {d} jour{d > 1 ? "s" : ""} pour candidater</div>}
                <Info icon={IconLayers} label="Secteur" value={o.sector_name} />
                <Info icon={IconBuilding} label="Direction" value={o.direction_name} />
                <Info icon={IconUsers} label="Pôle" value={o.pole_name} />
              </div>
            </aside>
          </div>
        </div>
      </main>
      <PublicFooter />
    </div>
  );
}
