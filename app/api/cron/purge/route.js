import { NextResponse } from "next/server";
import { purgeExpired } from "@/lib/purge";

export const runtime = "nodejs";

export async function GET(req) {
  const secret = process.env.CRON_SECRET || "";
  const auth = req.headers.get("authorization") || "";
  if (!secret || auth !== `Bearer ${secret}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const res = await purgeExpired();
  return NextResponse.json({ ok: true, ...res });
}

