import Link from "next/link";
import PublicHeader from "@/app/components/PublicHeader";
import PublicFooter from "@/app/components/PublicFooter";
import ApplyForm from "@/app/components/ApplyForm";
import { IconCheck } from "@/app/components/Icons";
import { getByEditToken, isApplicationEditable } from "@/lib/applications";

export const dynamic = "force-dynamic";

export default async function MaCandidaturePage({ params, searchParams }) {
  const app = await getByEditToken(params.token);
  const saved = searchParams?.saved === "1";

  return (
    <div className="flex min-h-screen flex-col">
      <PublicHeader />
      <main className="flex-1">
        <div className="container-sjr max-w-3xl py-8">
          {!app ? (
            <div className="card p-8 text-center">
              <h1 className="text-xl font-bold" style={{ color: "var(--sjr-ink)" }}>Lien invalide</h1>
              <p className="mx-auto mt-2 max-w-md text-sm" style={{ color: "var(--sjr-muted)" }}>
                Ce lien de modification n'est pas valide ou a expiré. Si besoin, contactez le service Ressources Humaines.
              </p>
              <div className="mt-6"><Link href="/recrutement" className="btn-primary">Voir les offres</Link></div>
            </div>
          ) : !isApplicationEditable(app) ? (
            <div className="card p-8 text-center">
              <h1 className="text-xl font-bold" style={{ color: "var(--sjr-ink)" }}>Candidature en cours de traitement</h1>
              <p className="mx-auto mt-2 max-w-md text-sm" style={{ color: "var(--sjr-muted)" }}>
                Votre candidature au poste <strong>{app.offer_title}</strong> est désormais prise en charge par le service RH
                et ne peut plus être modifiée en ligne. Pour toute correction, contactez directement le service Ressources Humaines.
              </p>
              <div className="mt-6"><Link href="/recrutement" className="btn-primary">Voir les offres</Link></div>
            </div>
          ) : (
            <>
              <h1 className="text-2xl font-bold" style={{ color: "var(--sjr-ink)" }}>Modifier ma candidature</h1>
              <p className="mt-1 text-sm" style={{ color: "var(--sjr-muted)" }}>
                Poste : <strong>{app.offer_title}</strong> · Référence {app.public_ref}. Vos informations et documents actuels sont pré-remplis ;
                modifiez ce que vous souhaitez puis enregistrez.
              </p>
              {saved && (
                <div className="mt-4 flex items-center gap-2 rounded-lg px-4 py-3 text-sm" style={{ background: "var(--sjr-primary-soft)", color: "var(--sjr-primary-dark)" }}>
                  <IconCheck className="h-4 w-4" /> Vos modifications ont bien été enregistrées.
                </div>
              )}
              <div className="mt-6">
                <ApplyForm
                  mode="edit"
                  token={params.token}
                  offer={{
                    id: app.offer_id,
                    title: app.offer_title,
                    positions_total: app.positions_total,
                    contract_type: app.offer_contract_type,
                    location: app.offer_location,
                    diploma_label: app.offer_diploma_label || "",
                    diploma_required: !!app.offer_diploma_required,
                  }}
                  initial={{
                    civility: app.civility, last_name: app.last_name, first_name: app.first_name,
                    phone: app.phone, email: app.email, address: app.address,
                    postal_code: app.postal_code, city: app.city, consent_vivier: !!app.consent_vivier,
                  }}
                  existingDocs={(app.documents || []).map((d) => ({ id: d.id, kind: d.kind, original_name: d.original_name }))}
                />
              </div>
            </>
          )}
        </div>
      </main>
      <PublicFooter />
    </div>
  );
}
