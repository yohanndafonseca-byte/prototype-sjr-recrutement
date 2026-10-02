#!/usr/bin/env bash
# Ajoute la mise en avant "Candidature spontanee" sur la page recrutement. A lancer a la racine.
set -e
cat > "app/recrutement/page.js" << 'SJREOF'
import Link from "next/link";
import PublicHeader from "@/app/components/PublicHeader";
import PublicFooter from "@/app/components/PublicFooter";
import SearchOffers from "@/app/components/SearchOffers";
import { listPublicOffers } from "@/lib/offers";

export const dynamic = "force-dynamic";

const isSpontanee = (o) => (o.title || "").toLowerCase().includes("spontan");

export default async function RecrutementPage() {
  const all = (await listPublicOffers("")).map((o) => ({
    id: o.id, title: o.title, contract_type: o.contract_type, work_time: o.work_time,
    location: o.location, sector_name: o.sector_name, direction_name: o.direction_name,
    pole_name: o.pole_name, deadline: o.deadline, keywords: o.keywords,
    missions: o.missions, profile: o.profile, positions_total: o.positions_total,
    positions_filled: o.positions_filled, positions_remaining: o.positions_remaining,
  }));

  // L'offre "Candidature spontanée" est mise en avant à part, pas mélangée aux vraies offres.
  const spontanee = all.find(isSpontanee);
  const offers = all.filter((o) => !isSpontanee(o));

  return (
    <div className="flex min-h-screen flex-col">
      <PublicHeader />
      <main className="flex-1">
        <section className="border-b" style={{ background: "linear-gradient(180deg,var(--sjr-primary-soft),transparent)", borderColor: "var(--sjr-line)" }}>
          <div className="container-sjr py-12 md:py-16">
            <p className="eyebrow">Ville de Saint-Jean-de-la-Ruelle</p>
            <h1 className="mt-2 max-w-2xl text-3xl font-bold leading-tight md:text-4xl" style={{ color: "var(--sjr-ink)" }}>
              Rejoignez les équipes de votre Ville
            </h1>
            <p className="mt-3 max-w-2xl text-base" style={{ color: "var(--sjr-muted)" }}>
              Découvrez les postes ouverts au sein des services municipaux et candidatez en ligne,
              en quelques minutes et sans créer de compte.
            </p>
          </div>
        </section>

        <section className="container-sjr -mt-8 pb-12">
          <SearchOffers offers={offers} />

          {spontanee && (
            <div className="mt-8 flex flex-col items-start justify-between gap-4 rounded-xl border p-6 sm:flex-row sm:items-center"
              style={{ borderColor: "var(--sjr-primary)", background: "var(--sjr-primary-soft)" }}>
              <div>
                <h2 className="text-lg font-bold" style={{ color: "var(--sjr-ink)" }}>
                  Aucune offre ne correspond à votre profil ?
                </h2>
                <p className="mt-1 text-sm" style={{ color: "var(--sjr-muted)" }}>
                  Envoyez une <strong>candidature spontanée</strong> : votre dossier sera conservé et étudié
                  par notre service Ressources Humaines.
                </p>
              </div>
              <Link href={`/recrutement/${spontanee.id}/candidater`} className="btn-primary whitespace-nowrap">
                Candidature spontanée
              </Link>
            </div>
          )}
        </section>
      </main>
      <PublicFooter />
    </div>
  );
}

SJREOF

echo "=== Carte candidature spontanee installee. Lance : npm run build ==="
