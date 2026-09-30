import PublicHeader from "@/app/components/PublicHeader";
import PublicFooter from "@/app/components/PublicFooter";
import SearchOffers from "@/app/components/SearchOffers";
import { listPublicOffers } from "@/lib/offers";

export const dynamic = "force-dynamic";

export default async function RecrutementPage() {
  const offers = (await listPublicOffers("")).map((o) => ({
    id: o.id, title: o.title, contract_type: o.contract_type, work_time: o.work_time,
    location: o.location, sector_name: o.sector_name, direction_name: o.direction_name,
    pole_name: o.pole_name, deadline: o.deadline, keywords: o.keywords,
    missions: o.missions, profile: o.profile, positions_total: o.positions_total,
    positions_filled: o.positions_filled, positions_remaining: o.positions_remaining,
  }));

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
        </section>
      </main>
      <PublicFooter />
    </div>
  );
}
