import { NextResponse } from "next/server";
import { createApplication, getApplication, saveDocument } from "@/lib/applications";
import { getPublicOffer } from "@/lib/offers";
import { DOC_KINDS, MAX_FILE_MB, ACCEPTED_EXT } from "@/lib/constants";
import { syncApplication } from "@/lib/sheets";

export const runtime = "nodejs";

function extOk(name) {
  const i = (name || "").lastIndexOf(".");
  return i >= 0 && ACCEPTED_EXT.includes(name.slice(i).toLowerCase());
}

export async function POST(req) {
  try {
    const fd = await req.formData();
    const offerId = Number(fd.get("offer_id"));
    const offer = await getPublicOffer(offerId);
    if (!offer) return NextResponse.json({ error: "Cette offre n'est plus disponible." }, { status: 400 });

    const cv = fd.get("cv");
    if (!cv || typeof cv === "string" || cv.size === 0) {
      return NextResponse.json({ error: "Le CV est obligatoire." }, { status: 400 });
    }

    const consentProcessing = fd.get("consent_processing") === "1";
    if (!consentProcessing) {
      return NextResponse.json({ error: "Vous devez accepter le traitement de vos données pour postuler." }, { status: 400 });
    }
    const data = {
      civility: fd.get("civility"), last_name: fd.get("last_name"), first_name: fd.get("first_name"),
      address: fd.get("address"), postal_code: fd.get("postal_code"), city: fd.get("city"),
      email: fd.get("email"), phone: fd.get("phone"),
      consent_processing: consentProcessing,
      consent_vivier: fd.get("consent_vivier") === "1",
    };
    if (!data.last_name || !data.first_name) {
      return NextResponse.json({ error: "Nom et prénom obligatoires." }, { status: 400 });
    }

    const created = await createApplication(offerId, data);
    const app = await getApplication(created.id);

    for (const kind of Object.keys(DOC_KINDS)) {
      const file = fd.get(kind);
      if (!file || typeof file === "string" || file.size === 0) continue;
      if (!extOk(file.name)) return NextResponse.json({ error: `Format non accepté pour ${DOC_KINDS[kind].label}.` }, { status: 400 });
      if (file.size > MAX_FILE_MB * 1024 * 1024) return NextResponse.json({ error: `${DOC_KINDS[kind].label} : fichier trop volumineux.` }, { status: 400 });
      const buf = Buffer.from(await file.arrayBuffer());
      await saveDocument(app, kind, file.name, buf, file.type);
    }

    await syncApplication(await getApplication(created.id), "Candidature reçue");
    return NextResponse.json({ ok: true, public_ref: created.public_ref, id: created.id });
  } catch (e) {
    console.error("[candidatures POST]", e);
    return NextResponse.json({ error: "Une erreur est survenue lors de l'envoi." }, { status: 500 });
  }
}
