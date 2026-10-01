import { NextResponse } from "next/server";
import * as T from "@/lib/taxonomy";

export const runtime = "nodejs";

const MAP = {
  sector: { create: (b) => T.createSector(b.name), rename: (b) => T.renameSector(b.id, b.name), delete: (b) => T.deleteSector(b.id) },
  direction: { create: (b) => T.createDirection(b.parentId, b.name), rename: (b) => T.renameDirection(b.id, b.name), delete: (b) => T.deleteDirection(b.id) },
  pole: { create: (b) => T.createPole(b.parentId, b.name), rename: (b) => T.renamePole(b.id, b.name), delete: (b) => T.deletePole(b.id) },
};

export async function POST(req) {
  try {
    const b = await req.json();
    const fn = MAP[b.level]?.[b.op];
    if (!fn) throw new Error("Opération inconnue.");
    const id = await fn(b);
    return NextResponse.json({ ok: true, id: id ?? null });
  } catch (e) {
    return NextResponse.json({ ok: false, error: e.message }, { status: 400 });
  }
}
