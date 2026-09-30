import { NextResponse } from "next/server";
import { updateOffer, publishOffer, unpublishOffer, getOffer } from "@/lib/offers";

export const runtime = "nodejs";

export async function PATCH(req, { params }) {
  const id = Number(params.id);
  const body = await req.json().catch(() => ({}));
  if (body.action === "publish") { const o = await publishOffer(id); return NextResponse.json({ ok: true, status: o.status }); }
  if (body.action === "unpublish") { const o = await unpublishOffer(id); return NextResponse.json({ ok: true, status: o.status }); }
  const o = await updateOffer(id, body);
  if (!o) return NextResponse.json({ error: "Offre introuvable" }, { status: 404 });
  return NextResponse.json({ ok: true, status: o.status });
}

export async function GET(_req, { params }) {
  const o = await getOffer(Number(params.id));
  if (!o) return NextResponse.json({ error: "Offre introuvable" }, { status: 404 });
  return NextResponse.json(o);
}
