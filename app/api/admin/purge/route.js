import { NextResponse } from "next/server";
import { unauthorized } from "@/lib/auth";
import { listPurgeable, purgeExpired } from "@/lib/purge";

export const runtime = "nodejs";

export async function GET() {
  const deny = await unauthorized(); if (deny) return deny;
  const preview = await listPurgeable();
  return NextResponse.json({ ok: true, ...preview });
}

export async function POST() {
  const deny = await unauthorized(); if (deny) return deny;
  const res = await purgeExpired();
  return NextResponse.json({ ok: true, ...res });
}
