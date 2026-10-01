import { NextResponse } from "next/server";
import { listApplications } from "@/lib/applications";
import { buildApplicationsZip } from "@/lib/zip";

export const runtime = "nodejs";

const IN_PROGRESS = ["a_etudier", "preselectionnee", "entretien", "retenue"];

export async function GET(req) {
  const sp = req.nextUrl.searchParams;
  const statut = sp.get("statut") || "";
  const offre = sp.get("offre") || "";

  let filter = {};
  if (statut === "en_cours") filter.statusIn = IN_PROGRESS;
  else if (statut) filter.status = statut;
  let rows = await listApplications(filter);
  if (offre) rows = rows.filter((a) => String(a.offer_id) === String(offre));

  const buf = await buildApplicationsZip(rows);
  const date = new Date().toISOString().slice(0, 10);
  return new NextResponse(buf, {
    headers: {
      "Content-Type": "application/zip",
      "Content-Disposition": `attachment; filename="Dossiers_SJR_${date}.zip"`,
      "Content-Length": String(buf.length),
    },
  });
}
