import { NextResponse } from "next/server";
import { createOffer } from "@/lib/offers";

export const runtime = "nodejs";

export async function POST(req) {
  const body = await req.json().catch(() => ({}));
  const publish = body.action === "publish";
  const offer = await createOffer(body, { publish });
  return NextResponse.json({ ok: true, id: offer.id, status: offer.status });
}
