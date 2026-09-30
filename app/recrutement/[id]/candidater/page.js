import Link from "next/link";
import { notFound } from "next/navigation";
import PublicHeader from "@/app/components/PublicHeader";
import PublicFooter from "@/app/components/PublicFooter";
import ApplyForm from "@/app/components/ApplyForm";
import { IconArrowLeft } from "@/app/components/Icons";
import { getPublicOffer } from "@/lib/offers";

export const dynamic = "force-dynamic";

export default async function CandidaterPage({ params }) {
  const o = await getPublicOffer(Number(params.id));
  if (!o) notFound();
  const offer = { id: o.id, title: o.title, positions_total: o.positions_total, contract_type: o.contract_type, location: o.location };

  return (
    <div className="flex min-h-screen flex-col">
      <PublicHeader />
      <main className="flex-1">
        <div className="container-sjr max-w-3xl py-8">
          <Link href={`/recrutement/${o.id}`} className="link inline-flex items-center gap-1.5 text-sm">
            <IconArrowLeft className="h-4 w-4" /> Retour à l'offre
          </Link>
          <h1 className="mt-4 text-2xl font-bold" style={{ color: "var(--sjr-ink)" }}>Postuler</h1>
          <p className="mt-1 text-sm" style={{ color: "var(--sjr-muted)" }}>Complétez les trois étapes ci-dessous pour transmettre votre candidature au service RH.</p>
          <div className="mt-6"><ApplyForm offer={offer} /></div>
        </div>
      </main>
      <PublicFooter />
    </div>
  );
}
