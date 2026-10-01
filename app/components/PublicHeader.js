import Link from "next/link";

const NAV = [
  { label: "Découvrir la ville", href: "#" },
  { label: "La Mairie", href: "#" },
  { label: "Bien vivre en ville", href: "#" },
  { label: "Vie associative", href: "#" },
  { label: "Recrutement", href: "/recrutement", active: true },
];

export default function PublicHeader() {
  return (
    <header className="bg-white">
      <div
        className="text-white"
        style={{ background: "var(--sjr-primary-dark)" }}
      >
        <div className="container-sjr flex h-9 items-center justify-between text-xs">
          <span className="hidden sm:inline opacity-90">
            Site officiel de la Ville de Saint-Jean-de-la-Ruelle
          </span>

          <div className="flex items-center gap-4">
            <a className="opacity-90 hover:opacity-100" href="#">
              Mes services en ligne
            </a>
          </div>
        </div>
      </div>

      <div
        className="border-b"
        style={{ borderColor: "var(--sjr-line)" }}
      >
        <div className="container-sjr flex items-center justify-between py-4">
          <Link
            href="/recrutement"
            className="flex items-center gap-3"
          >
            <img
              src="/logo-sjr.png"
              alt="Ville de Saint-Jean-de-la-Ruelle"
              className="h-12 w-auto"
            />

            <span className="leading-tight">
              <span
                className="block text-[15px] font-bold"
                style={{ color: "var(--sjr-ink)" }}
              >
                Espace recrutement
              </span>
            </span>
          </Link>

          <nav className="hidden items-center gap-1 md:flex">
            {NAV.map((n) => (
              <Link
                key={n.label}
                href={n.href}
                className={`rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
                  n.active ? "text-white" : "hover:bg-slate-50"
                }`}
                style={
                  n.active
                    ? { background: "var(--sjr-primary)" }
                    : { color: "var(--sjr-ink)" }
                }
              >
                {n.label}
              </Link>
            ))}
          </nav>
        </div>
      </div>
    </header>
  );
}