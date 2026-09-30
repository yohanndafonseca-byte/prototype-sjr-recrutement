import { NextResponse } from "next/server";
import { getDocumentContent } from "@/lib/applications";

export const runtime = "nodejs";

export async function GET(req, { params }) {
  const doc = await getDocumentContent(Number(params.id));
  if (!doc) return NextResponse.json({ error: "Document introuvable" }, { status: 404 });
  const data = doc.buffer;
  const download = req.nextUrl.searchParams.get("dl") === "1";
  return new NextResponse(data, {
    headers: {
      "Content-Type": doc.mime || "application/octet-stream",
      "Content-Disposition": `${download ? "attachment" : "inline"}; filename="${encodeURIComponent(doc.original_name || "document")}"`,
      "Content-Length": String(data.length),
    },
  });
}
