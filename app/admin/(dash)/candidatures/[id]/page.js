import Link from "next/link";
import { notFound } from "next/navigation";
import { AppBadge } from "@/app/components/StatusBadge";
import StatusChanger from "@/app/components/StatusChanger";
import NoteForm from "@/app/components/NoteForm";
import PositionMeter from "@/app/components/PositionMeter";
import { IconArrowLeft, IconDoc, IconDownload } from "@/app/components/Icons";
import { getApplication, markOpened } from "@/lib/applications";
import { DOC_KINDS } from "@/lib/constants";
import { fmtDate, fmtDateTime, fmtBytes, initials } from "@/lib/format";

export const dynamic = "force-dynamic";

function Info({ label, value }) {
  return (
    <div className="flex justify-between gap-4 border-b py-2 text-sm" style={{ borderColor: "var(--sjr-line)" }}>
      <span style={{ color: "var(--sjr-muted)" }}>{label}</span>
      <span className="text-right font-medium" style={{ color: "var(--sjr-ink)" }}>{value || "—"}</span>
    </div>
  );
}

export default async function CandidatureDetail({ params }) {
  const id = Number(params.id);
  await markOpened(id); // ouverture d'une candidature "nouvelle" -> passe en "à étudier"
  const a = await getApplication(id);
  if (!a) notFound();

  return (
    <div>
      <Link href="/admin/candidatures" className="link inline-flex items-center gap-1.5 text-sm"><IconArrowLeft className="h-4 w-4" /> Retour aux candidatures</Link>

      <div className="mt-3 flex flex-wrap items-start justify-between gap-4">
        <div className="flex items-center gap-3">
          <span className="grid h-12 w-12 place-items-center rounded-full text-sm font-bold" style={{ background: "var(--sjr-primary-soft)", color: "var(--sjr-primary-dark)" }}>{initials(a.first_name, a.last_name)}</span>
          <div>
            <h1 className="text-2xl font-bold" style={{ color: "var(--sjr-ink)" }}>{a.civility ? a.civility + " " : ""}{a.first_name} {a.last_name}</h1>
            <p className="text-sm" style={{ color: "var(--sjr-muted)" }}>{a.public_ref} · candidature reçue le {fmtDateTime(a.created_at)}</p>
          </div>
        </div>
        <AppBadge status={a.status} />
      </div>

      <div className="mt-5 grid gap-6 lg:grid-cols-[1fr_320px]">
        {/* Colonne principale */}
        <div className="space-y-6">
          {/* Offre associée (renseignée automatiquement) */}
          <section className="card p-5">
            <h2 className="mb-3 font-semibold" style={{ color: "var(--sjr-ink)" }}>Poste concerné</h2>
            <Link href={`/admin/offres/${a.offer_id}`} className="link text-base font-semibold">{a.offer_title}</Link>
            <div className="mt-3 grid grid-cols-1 sm:grid-cols-2">
              <Info label="Référence de l'offre" value={a.offer_reference} />
              <Info label="Secteur" value={a.sector_name} />
              <Info label="Direction" value={a.direction_name} />
              <Info label="Pôle" value={a.pole_name} />
            </div>
            <div className="mt-3"><PositionMeter total={a.positions_total} filled={a.positions_filled} remaining={a.positions_remaining} size="sm" /></div>
          </section>

          {/* Coordonnées candidat */}
          <section className="card p-5">
            <h2 className="mb-3 font-semibold" style={{ color: "var(--sjr-ink)" }}>Coordonnées du candidat</h2>
            <div className="grid grid-cols-1 sm:grid-cols-2">
              <Info label="E-mail" value={a.email} />
              <Info label="Téléphone" value={a.phone} />
              <Info label="Adresse" value={a.address} />
              <Info label="Code postal / Ville" value={[a.postal_code, a.city].filter(Boolean).join(" ")} />
            </div>
            <div className="mt-3 flex flex-wrap gap-2 border-t pt-3" style={{ borderColor: "var(--sjr-line)" }}>
              <span className="badge" style={{ background: "#e6f4ea", color: "#137333" }}>✓ Traitement accepté</span>
              {a.consent_vivier
                ? <span className="badge" style={{ background: "#e8f0fe", color: "#1967d2" }}>✓ Conservation en vivier (2 ans) acceptée</span>
                : <span className="badge" style={{ background: "#fde8e8", color: "#b4231f" }}>✗ Vivier refusé — à supprimer après recrutement</span>}
            </div>
          </section>

          {/* Documents */}
          <section className="card p-5">
            <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
              <h2 className="font-semibold" style={{ color: "var(--sjr-ink)" }}>Documents transmis</h2>
              {a.documents.length > 0 && (
                <a href={`/api/admin/candidatures/${a.id}/dossier`} className="btn-accent text-xs">
                  <IconDownload className="h-4 w-4" /> Dossier complet (PDF)
                </a>
              )}
            </div>
            <div className="space-y-2">
              {a.documents.length === 0 && <p className="text-sm" style={{ color: "var(--sjr-muted)" }}>Aucun document.</p>}
              {a.documents.map((d) => (
                <div key={d.id} className="flex items-center gap-3 rounded-lg border p-3" style={{ borderColor: "var(--sjr-line)" }}>
                  <IconDoc className="h-5 w-5 shrink-0" style={{ color: "var(--sjr-primary)" }} />
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-sm font-medium" style={{ color: "var(--sjr-ink)" }}>{DOC_KINDS[d.kind]?.label || d.kind}</div>
                    <div className="truncate text-xs" style={{ color: "var(--sjr-muted)" }}>{d.original_name} · {fmtBytes(d.size)}</div>
                  </div>
                  <a href={`/api/admin/documents/${d.id}`} target="_blank" className="btn-ghost text-xs">Aperçu</a>
                  <a href={`/api/admin/documents/${d.id}?dl=1`} className="btn-outline text-xs"><IconDownload className="h-4 w-4" /> Télécharger</a>
                </div>
              ))}
            </div>
          </section>

          {/* Notes internes */}
          <section className="card p-5">
            <h2 className="mb-3 font-semibold" style={{ color: "var(--sjr-ink)" }}>Notes internes</h2>
            <div className="mb-4"><NoteForm id={a.id} /></div>
            <div className="space-y-3">
              {a.notes.length === 0 && <p className="text-sm" style={{ color: "var(--sjr-muted)" }}>Aucune note pour l'instant.</p>}
              {a.notes.map((n) => (
                <div key={n.id} className="rounded-lg p-3" style={{ background: "#f8fafc", border: "1px solid var(--sjr-line)" }}>
                  <div className="whitespace-pre-wrap text-sm" style={{ color: "var(--sjr-ink)" }}>{n.body}</div>
                  <div className="mt-1 text-xs" style={{ color: "var(--sjr-muted)" }}>{fmtDateTime(n.created_at)}</div>
                </div>
              ))}
            </div>
          </section>
        </div>

        {/* Colonne latérale : workflow + timeline */}
        <div className="space-y-6">
          <section className="card p-5">
            <h2 className="mb-1 font-semibold" style={{ color: "var(--sjr-ink)" }}>Faire évoluer la candidature</h2>
            <p className="mb-4 text-xs" style={{ color: "var(--sjr-muted)" }}>Statut actuel : <b>{a.status_label}</b></p>
            <StatusChanger id={a.id} status={a.status} />
            <p className="mt-4 text-[11px] leading-relaxed" style={{ color: "var(--sjr-muted)" }}>
              « Retenue » n'affecte pas le nombre de postes. Seul le passage à « Recruté » décompte un poste et peut clôturer l'offre.
            </p>
          </section>

          <section className="card p-5">
            <h2 className="mb-3 font-semibold" style={{ color: "var(--sjr-ink)" }}>Historique</h2>
            <ol className="relative space-y-4 border-l pl-4" style={{ borderColor: "var(--sjr-line)" }}>
              {a.events.map((e) => (
                <li key={e.id} className="relative">
                  <span className="absolute -left-[21px] top-1 h-2.5 w-2.5 rounded-full" style={{ background: e.type === "email" ? "var(--sjr-accent)" : e.type === "status" ? "var(--sjr-primary)" : "#94a3b8" }} />
                  <div className="text-sm" style={{ color: "var(--sjr-ink)" }}>{e.message}</div>
                  <div className="text-xs" style={{ color: "var(--sjr-muted)" }}>{fmtDateTime(e.created_at)}</div>
                </li>
              ))}
            </ol>
          </section>
        </div>
      </div>
    </div>
  );
}
