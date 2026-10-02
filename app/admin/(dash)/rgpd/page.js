import { listPurgeable } from "@/lib/purge";
import PurgeManager from "@/app/components/PurgeManager";

export const dynamic = "force-dynamic";

export default async function RgpdPage() {
  const preview = await listPurgeable();
  return (
    <div>
      <div className="mb-5">
        <h1 className="text-2xl font-bold" style={{ color: "var(--sjr-ink)" }}>Conformité (RGPD)</h1>
        <p className="text-sm" style={{ color: "var(--sjr-muted)" }}>
          Les candidatures non recrutées sont conservées {preview.years} ans maximum, puis supprimées.
          La purge s'exécute automatiquement chaque nuit ; vous pouvez aussi la lancer manuellement ci-dessous.
        </p>
      </div>
      <PurgeManager preview={preview} />
    </div>
  );
}

