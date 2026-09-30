import { NextResponse } from "next/server";
import { listApplications, getApplication } from "@/lib/applications";
import { buildApplicationsWorkbook } from "@/lib/exportXlsx";

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

  // enrichir : types de documents + collecte de l'historique détaillé
  const history = [];
  const enriched = [];
  for (const a of rows) {
    const full = await getApplication(a.id);
    if (full) {
      for (const ev of [...full.events].reverse()) {
        history.push({
          ref: a.public_ref, last_name: a.last_name, first_name: a.first_name,
          offer_title: a.offer_title, created_at: ev.created_at, message: ev.message, type: ev.type,
        });
      }
    }
    enriched.push({ ...a, doc_kinds: full ? full.documents.map((d) => d.kind) : [] });
  }
  rows = enriched;

  const buf = buildApplicationsWorkbook(rows, history);
  const date = new Date().toISOString().slice(0, 10);
  return new NextResponse(buf, {
    headers: {
      "Content-Type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "Content-Disposition": `attachment; filename="Candidatures_SJR_${date}.xlsx"`,
      "Content-Length": String(buf.length),
    },
  });
}
