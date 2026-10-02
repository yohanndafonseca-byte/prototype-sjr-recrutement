import { NextResponse } from "next/server";
import { listPurgeable, purgeExpired } from "@/lib/purge";

export const runtime = "nodejs";

export async function GET() {
  const preview = await listPurgeable();
  return NextResponse.json({ ok: true, ...preview });
}

export async function POST() {
  const res = await purgeExpired();
  return NextResponse.json({ ok: true, ...res });
}

