import Link from "next/link";
import { IconStar, IconChevron } from "@/app/components/Icons";
import { listApplications } from "@/lib/applications";
import { fmtDateTime, initials } from "@/lib/format";

export const dynamic = "force-dynamic";

export default async function RecrutementsPage() {
  const apps = await listApplications({ status: "recrute" });
  const byOffer = {};
  for (const a of apps) (byOffer[a.offer_title] ||= []).push(a);

  return (
    <div>
      <div className="mb-5 flex items-center gap-3">
        <span className="grid h-10 w-10 place-items-center rounded-lg text-white" style={{ background: "var(--sjr-accent)" }}><IconStar className="h-5 w-5" /></span>
        <div>
          <h1 className="text-2xl font-bold" style={{ color: "var(--sjr-ink)" }}>Recrutements finalisés</h1>
          <p className="text-sm" style={{ color: "var(--sjr-muted)" }}>{apps.length} personne{apps.length > 1 ? "s" : ""} recrutée{apps.length > 1 ? "s" : ""}</p>
        </div>
      </div>

      {apps.length === 0 && (
        <div className="card p-10 text-center">
          <p className="font-medium" style={{ color: "var(--sjr-ink)" }}>Aucun recrutement finalisé pour l'instant.</p>
          <p className="mt-1 text-sm" style={{ color: "var(--sjr-muted)" }}>Les candidatures passées au statut « Recruté » apparaîtront ici.</p>
        </div>
      )}

      <div className="space-y-6">
        {Object.entries(byOffer).map(([title, list]) => (
          <section key={title} className="card p-5">
            <h2 className="mb-3 font-semibold" style={{ color: "var(--sjr-ink)" }}>{title} <span className="text-sm font-normal" style={{ color: "var(--sjr-muted)" }}>· {list.length} recruté{list.length > 1 ? "s" : ""}</span></h2>
            <div className="divide-y" style={{ borderColor: "var(--sjr-line)" }}>
              {list.map((a) => (
                <Link key={a.id} href={`/admin/candidatures/${a.id}`} className="flex items-center gap-3 py-3 hover:opacity-80">
                  <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full text-xs font-bold text-white" style={{ background: "var(--sjr-accent)" }}>{initials(a.first_name, a.last_name)}</span>
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-sm font-medium" style={{ color: "var(--sjr-ink)" }}>{a.first_name} {a.last_name}</div>
                    <div className="truncate text-xs" style={{ color: "var(--sjr-muted)" }}>{a.public_ref} · {a.email || "—"}</div>
                  </div>
                  <IconChevron className="h-4 w-4 shrink-0 text-slate-300" />
                </Link>
              ))}
            </div>
          </section>
        ))}
      </div>
    </div>
  );
}
