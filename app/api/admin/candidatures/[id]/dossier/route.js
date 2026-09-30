import { NextResponse } from "next/server";
import { getApplication, listDocumentsWithContent } from "@/lib/applications";
import { buildDossierPdf } from "@/lib/dossier";

export const runtime = "nodejs";

function slug(s) { return String(s || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-zA-Z0-9]+/g, "_").replace(/^_|_$/g, ""); }

export async function GET(_req, { params }) {
  const app = await getApplication(Number(params.id));
  if (!app) return NextResponse.json({ error: "Candidature introuvable" }, { status: 404 });
  const docs = await listDocumentsWithContent(app.id);
  const pdf = await buildDossierPdf(app, docs);
  const name = `Dossier_${slug(app.last_name)}_${slug(app.first_name)}_${app.public_ref}.pdf`;
  return new NextResponse(pdf, {
    headers: {
      "Content-Type": "application/pdf",
      "Content-Disposition": `attachment; filename="${name}"`,
      "Content-Length": String(pdf.length),
    },
  });
}
