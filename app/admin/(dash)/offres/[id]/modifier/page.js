import Link from "next/link";
import { notFound } from "next/navigation";
import OfferForm from "@/app/components/OfferForm";
import { IconArrowLeft } from "@/app/components/Icons";
import { getOffer, getMetaTree } from "@/lib/offers";

export const dynamic = "force-dynamic";

export default async function ModifierOffre({ params }) {
  const id = Number(params.id);
  const o = await getOffer(id);
  if (!o) notFound();
  const tree = await getMetaTree();
  const initial = {
    title: o.title || "", sector_id: o.sector_id || "", direction_id: o.direction_id || "",
    pole_id: o.pole_id || "", contract_type: o.contract_type || "", work_time: o.work_time || "",
    positions_total: o.positions_total || 1, deadline: o.deadline || "", keywords: o.keywords || "",
    missions: o.missions || "", profile: o.profile || "", conditions: o.conditions || "", extra_info: o.extra_info || "",
  };
  return (
    <div className="max-w-4xl">
      <Link href={`/admin/offres/${id}`} className="link inline-flex items-center gap-1.5 text-sm"><IconArrowLeft className="h-4 w-4" /> Retour à l'offre</Link>
      <h1 className="mt-3 mb-5 text-2xl font-bold" style={{ color: "var(--sjr-ink)" }}>Modifier l'offre</h1>
      <OfferForm tree={tree} initial={initial} offerId={id} status={o.status} />
    </div>
  );
}
