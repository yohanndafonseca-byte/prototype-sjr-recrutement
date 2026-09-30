// Jauge "postes restants" — le motif signature du produit.
export default function PositionMeter({ total, filled, remaining, size = "md" }) {
  const rem = remaining ?? Math.max(0, total - filled);
  const pct = total > 0 ? Math.round(((total - rem) / total) * 100) : 0;
  const done = rem === 0;
  const seg = size === "sm" ? "h-1.5" : "h-2";
  return (
    <div className="w-full">
      <div className="flex items-center justify-between text-sm">
        <span className="font-semibold" style={{ color: done ? "#4338ca" : "var(--sjr-accent-dark)" }}>
          {done ? "Poste(s) pourvu(s)" : `${rem} poste${rem > 1 ? "s" : ""} restant${rem > 1 ? "s" : ""}`}
        </span>
        <span className="text-xs" style={{ color: "var(--sjr-muted)" }}>
          {filled ?? total - rem}/{total} pourvu{(filled ?? total - rem) > 1 ? "s" : ""}
        </span>
      </div>
      <div className={`mt-1.5 w-full overflow-hidden rounded-full bg-slate-100 ${seg}`}>
        <div className={`${seg} rounded-full transition-all`} style={{ width: `${pct}%`, background: done ? "#6366f1" : "var(--sjr-accent)" }} />
      </div>
    </div>
  );
}
