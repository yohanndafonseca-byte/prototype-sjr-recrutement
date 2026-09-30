import { NextResponse } from "next/server";
import { login, SESSION_COOKIE } from "@/lib/auth";

export const runtime = "nodejs";

export async function POST(req) {
  const { username, password } = await req.json().catch(() => ({}));
  const result = await login((username || "").trim(), password || "");
  if (!result) return NextResponse.json({ error: "Identifiant ou mot de passe incorrect." }, { status: 401 });
  const res = NextResponse.json({ ok: true });
  res.cookies.set(SESSION_COOKIE, result.token, {
    httpOnly: true, sameSite: "lax", path: "/", maxAge: 60 * 60 * 8,
  });
  return res;
}
