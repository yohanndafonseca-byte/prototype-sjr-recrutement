import { NextResponse } from "next/server";
import { unauthorized } from "@/lib/auth";
import { createOffer } from "@/lib/offers";

export const runtime = "nodejs";

export async function POST(req) {
  const deny = await unauthorized(); if (deny) return deny;
  const body = await req.json().catch(() => ({}));
  const publish = body.action === "publish";
  const offer = await createOffer(body, { publish });
  return NextResponse.json({ ok: true, id: offer.id, status: offer.status });
}
