"use client";
import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { IconSearch, IconPin, IconBriefcase, IconClock, IconChevron } from "./Icons";
import PositionMeter from "./PositionMeter";
import { fmtDate, daysUntil } from "@/lib/format";

function haystack(o) {
  return [o.title, o.sector_name, o.direction_name, o.pole_name, o.contract_type, o.work_time, o.location, o.keywords, o.missions, o.profile]
    .filter(Boolean).join(" ").toLowerCase();
}

export default function SearchOffers({ offers }) {
  const router = useRouter();
  const [q, setQ] = useState("");
  const [focused, setFocused] = useState(false);

  const results = useMemo(() => {
    const t = q.trim().toLowerCase();
    if (!t) return offers;
    const terms = t.split(/\s+/);
    return offers.filter((o) => { const h = haystack(o); return terms.every((x) => h.includes(x)); });
  }, [q, offers]);

  return (
    <div>
      {/* Barre de recherche — élément central */}
      <div className={`card p-2 transition-shadow ${focused ? "shadow-pop" : ""}`}>
        <div className="flex items-center gap-3 px-3">
          <IconSearch className="h-5 w-5 shrink-0" style={{ color: "var(--sjr-primary)" }} />
          <input
            autoFocus
            value={q}
            onChange={(e) => setQ(e.target.value)}
            onFocus={() => setFocused(true)}
            onBlur={() => setFocused(false)}
            placeholder="Rechercher un métier, un poste, une direction…"
            className="h-12 w-full bg-transparent text-base outline-none placeholder:text-slate-400"
            aria-label="Rechercher une offre"
          />
          {q && (
            <button onClick={() => setQ("")} className="text-sm text-slate-400 hover:text-slate-600">Effacer</button>
          )}
        </div>
      </div>

      <p className="mt-4 text-sm" style={{ color: "var(--sjr-muted)" }}>
        <span className="font-semibold" style={{ color: "var(--sjr-ink)" }}>{results.length}</span>{" "}
        offre{results.length > 1 ? "s" : ""} ouverte{results.length > 1 ? "s" : ""}
        {q && " correspondant à votre recherche"}
      </p>

      {/* Résultats — cartes compactes */}
      <div className="mt-3 space-y-3">
        {results.map((o) => {
          const d = daysUntil(o.deadline);
          return (
            <button
              key={o.id}
              onClick={() => router.push(`/recrutement/${o.id}`)}
              className="card group w-full p-5 text-left transition-all hover:-translate-y-0.5 hover:shadow-pop"
            >
              <div className="flex items-start justify-between gap-4">
                <div className="min-w-0">
                  <h3 className="truncate text-lg font-semibold" style={{ color: "var(--sjr-ink)" }}>{o.title}</h3>
                  <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1.5 text-sm" style={{ color: "var(--sjr-muted)" }}>
                    <span className="inline-flex items-center gap-1.5"><IconBriefcase className="h-4 w-4" />{o.contract_type}</span>
                    <span className="inline-flex items-center gap-1.5"><IconClock className="h-4 w-4" />{o.work_time}</span>
                    <span className="inline-flex items-center gap-1.5"><IconPin className="h-4 w-4" />{o.location}</span>
                  </div>
                  <p className="mt-1 text-sm" style={{ color: "var(--sjr-muted)" }}>
                    {o.direction_name} · {o.sector_name}
                  </p>
                </div>
                <IconChevron className="mt-1 h-5 w-5 shrink-0 text-slate-300 transition-transform group-hover:translate-x-0.5" style={{ color: "var(--sjr-primary)" }} />
              </div>

              <div className="mt-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <div className="sm:max-w-xs sm:flex-1">
                  <PositionMeter total={o.positions_total} filled={o.positions_filled} remaining={o.positions_remaining} size="sm" />
                </div>
                <span className="text-xs" style={{ color: d != null && d <= 7 ? "#b45309" : "var(--sjr-muted)" }}>
                  {o.deadline ? `Candidature jusqu'au ${fmtDate(o.deadline)}${d != null && d <= 7 ? ` · ${d} j restants` : ""}` : "Sans date limite"}
                </span>
              </div>
            </button>
          );
        })}

        {results.length === 0 && (
          <div className="card p-10 text-center">
            <p className="font-medium" style={{ color: "var(--sjr-ink)" }}>Aucune offre ne correspond à votre recherche.</p>
            <p className="mt-1 text-sm" style={{ color: "var(--sjr-muted)" }}>Essayez un autre mot-clé ou effacez la recherche pour voir toutes les offres.</p>
          </div>
        )}
      </div>
    </div>
  );
}
