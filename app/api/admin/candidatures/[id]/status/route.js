import { NextResponse } from "next/server";
import { setStatus, getApplication } from "@/lib/applications";
import { syncApplication } from "@/lib/sheets";

export const runtime = "nodejs";

export async function POST(req, { params }) {
  const { status } = await req.json().catch(() => ({}));
  try {
    const updated = await setStatus(Number(params.id), status);
    const app = await getApplication(updated.id);
    await syncApplication(app, `Étape : ${app.status_label}`);
    return NextResponse.json({ ok: true, status: updated.status });
  } catch (e) {
    return NextResponse.json({ error: e.message }, { status: 400 });
  }
}
