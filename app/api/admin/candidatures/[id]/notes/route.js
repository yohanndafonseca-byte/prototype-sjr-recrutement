import { NextResponse } from "next/server";
import { addNote } from "@/lib/applications";

export const runtime = "nodejs";

export async function POST(req, { params }) {
  const { body } = await req.json().catch(() => ({}));
  if (!body || !body.trim()) return NextResponse.json({ error: "Note vide" }, { status: 400 });
  await addNote(Number(params.id), body);
  return NextResponse.json({ ok: true });
}
