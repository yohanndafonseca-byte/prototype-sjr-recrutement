import { NextResponse } from "next/server";
import {
  getByEditToken, isApplicationEditable, updateApplicationFields,
  deleteDocumentOfApp, saveDocument, getApplication, addEvent,
} from "@/lib/applications";
import { DOC_KINDS, MAX_FILE_MB, ACCEPTED_EXT } from "@/lib/constants";
import { syncApplication } from "@/lib/sheets";

export const runtime = "nodejs";

function extOk(name) {
  const i = (name || "").lastIndexOf(".");
  return i >= 0 && ACCEPTED_EXT.includes(name.slice(i).toLowerCase());
}

export async function PUT(req, { params }) {
  try {
    const app = await getByEditToken(params.token);
    if (!app) return NextResponse.json({ error: "Lien de modification invalide." }, { status: 404 });
    if (!isApplicationEditable(app)) {
      return NextResponse.json({ error: "Votre candidature est en cours de traitement : elle n'est plus modifiable. Contactez le service RH." }, { status: 409 });
    }

    const fd = await req.formData();

    const data = {
      civility: fd.get("civility"), last_name: fd.get("last_name"), first_name: fd.get("first_name"),
      address: fd.get("address"), postal_code: fd.get("postal_code"), city: fd.get("city"),
      email: fd.get("email"), phone: fd.get("phone"),
      consent_vivier: fd.get("consent_vivier") === "1",
    };
    if (!data.last_name || !data.first_name) {
      return NextResponse.json({ error: "Nom et prénom obligatoires." }, { status: 400 });
    }

    // Pièces existantes que le candidat retire.
    const removed = new Set(fd.getAll("removed_doc_ids").map((v) => Number(v)).filter(Boolean));
    const remainingByKind = (kind) => app.documents.filter((d) => d.kind === kind && !removed.has(d.id)).length;
    const newFilesByKind = (kind) => fd.getAll(kind).filter((f) => f && typeof f !== "string" && f.size > 0);

    // Validations (avant toute modification).
    if (remainingByKind("cv") + newFilesByKind("cv").length === 0) {
      return NextResponse.json({ error: "Le CV est obligatoire." }, { status: 400 });
    }
    if (app.offer_diploma_required && remainingByKind("diplome") + newFilesByKind("diplome").length === 0) {
      return NextResponse.json({ error: `Le diplôme demandé est obligatoire${app.offer_diploma_label ? ` : ${app.offer_diploma_label}` : ""}.` }, { status: 400 });
    }
    for (const kind of Object.keys(DOC_KINDS)) {
      for (const file of newFilesByKind(kind)) {
        if (!extOk(file.name)) return NextResponse.json({ error: `Format non accepté pour ${DOC_KINDS[kind].label}.` }, { status: 400 });
        if (file.size > MAX_FILE_MB * 1024 * 1024) return NextResponse.json({ error: `${DOC_KINDS[kind].label} : fichier trop volumineux.` }, { status: 400 });
      }
    }

    // Application des changements.
    await updateApplicationFields(app.id, data);
    for (const id of removed) await deleteDocumentOfApp(id, app.id);
    for (const kind of Object.keys(DOC_KINDS)) {
      for (const file of newFilesByKind(kind)) {
        const buf = Buffer.from(await file.arrayBuffer());
        await saveDocument(app, kind, file.name, buf, file.type);
      }
    }

    await addEvent(app.id, "modification", "Candidature modifiée par le candidat (lien de modification).");
    await syncApplication(await getApplication(app.id), "Candidature modifiée par le candidat");

    return NextResponse.json({ ok: true });
  } catch (e) {
    console.error("[candidatures PUT]", e);
    return NextResponse.json({ error: "Une erreur est survenue lors de l'enregistrement." }, { status: 500 });
  }
}
