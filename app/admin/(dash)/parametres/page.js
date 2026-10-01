import { getMetaTree } from "@/lib/offers";
import ParametresManager from "@/app/components/ParametresManager";

export const dynamic = "force-dynamic";

export default async function ParametresPage() {
  const tree = await getMetaTree();
  return (
    <div>
      <div className="mb-5">
        <h1 className="text-2xl font-bold" style={{ color: "var(--sjr-ink)" }}>Paramètres</h1>
        <p className="text-sm" style={{ color: "var(--sjr-muted)" }}>
          Gérez les secteurs, directions et pôles proposés dans le formulaire des offres.
          Renommer est sans risque ; un élément utilisé par des offres ne peut pas être supprimé.
        </p>
      </div>
      <ParametresManager tree={tree} />
    </div>
  );
}
