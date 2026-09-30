import Link from "next/link";
import OfferForm from "@/app/components/OfferForm";
import { IconArrowLeft } from "@/app/components/Icons";
import { getMetaTree } from "@/lib/offers";

export const dynamic = "force-dynamic";

export default async function NouvelleOffre() {
  const tree = await getMetaTree();
  return (
    <div className="max-w-4xl">
      <Link href="/admin/offres" className="link inline-flex items-center gap-1.5 text-sm"><IconArrowLeft className="h-4 w-4" /> Retour aux offres</Link>
      <h1 className="mt-3 mb-5 text-2xl font-bold" style={{ color: "var(--sjr-ink)" }}>Nouvelle offre</h1>
      <OfferForm tree={tree} />
    </div>
  );
}
