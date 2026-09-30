import Link from "next/link";
import PublicHeader from "@/app/components/PublicHeader";
import PublicFooter from "@/app/components/PublicFooter";
import { IconCheck } from "@/app/components/Icons";

export const dynamic = "force-dynamic";

export default function Confirmation({ searchParams }) {
  const ref = searchParams?.ref;
  return (
    <div className="flex min-h-screen flex-col">
      <PublicHeader />
      <main className="flex-1">
        <div className="container-sjr max-w-2xl py-16">
          <div className="card p-8 text-center md:p-12">
            <div className="mx-auto grid h-16 w-16 place-items-center rounded-full" style={{ background: "var(--sjr-accent)" }}>
              <IconCheck className="h-8 w-8 text-white" />
            </div>
            <h1 className="mt-6 text-2xl font-bold" style={{ color: "var(--sjr-ink)" }}>Votre candidature a bien été envoyée</h1>
            <p className="mx-auto mt-3 max-w-md text-[15px]" style={{ color: "var(--sjr-muted)" }}>
              Votre candidature a été transmise au service des ressources humaines de la Ville de
              Saint-Jean-de-la-Ruelle. Un accusé de réception vous a été adressé par e-mail.
            </p>
            {ref && (
              <div className="mx-auto mt-5 inline-block rounded-lg px-4 py-2" style={{ background: "var(--sjr-primary-soft)" }}>
                <span className="text-xs" style={{ color: "var(--sjr-muted)" }}>Référence de suivi</span>
                <div className="font-mono text-sm font-semibold" style={{ color: "var(--sjr-primary-dark)" }}>{ref}</div>
              </div>
            )}
            <div className="mt-8">
              <Link href="/recrutement" className="btn-primary">Voir les autres offres</Link>
            </div>
          </div>
        </div>
      </main>
      <PublicFooter />
    </div>
  );
}
