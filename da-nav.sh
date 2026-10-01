#!/usr/bin/env bash
# Vrais menus + couleurs SJR. À lancer à la racine du projet.
set -e

cat > "app/components/PublicHeader.js" << 'SJREOF'
import Link from "next/link";

const NAV = [
  { label: "Découvrir Saint Jean de la Ruelle", href: "https://www.ville-saintjeandelaruelle.fr/" },
  { label: "La Mairie", href: "https://www.ville-saintjeandelaruelle.fr/la-mairie" },
  { label: "Bien vivre en ville", href: "https://www.ville-saintjeandelaruelle.fr/bien-vivre-en-ville" },
  { label: "Vie associative", href: "https://www.ville-saintjeandelaruelle.fr/vie-associative" },
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
                target={n.href.startsWith("http") ? "_blank" : undefined}
                rel={n.href.startsWith("http") ? "noopener noreferrer" : undefined}
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
SJREOF

cat > "app/globals.css" << 'SJREOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --sjr-bg: #f3f6fa;
  --sjr-surface: #ffffff;
  --sjr-primary: #1f7f8c;
  --sjr-primary-dark: #14606b;
  --sjr-primary-soft: #e3f1f3;
  --sjr-accent: #6aa84f;
  --sjr-accent-dark: #52863d;
  --sjr-ink: #17282c;
  --sjr-muted: #5c6b70;
  --sjr-line: #e2eaec;
}

html { -webkit-text-size-adjust: 100%; }
body {
  background: var(--sjr-bg);
  color: var(--sjr-ink);
  font-feature-settings: "kern", "liga";
}

@layer components {
  .container-sjr { @apply mx-auto w-full max-w-6xl px-4 sm:px-6; }

  .btn { @apply inline-flex items-center justify-center gap-2 rounded-lg px-4 py-2.5 text-sm font-semibold transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed; }
  .btn-primary { @apply btn text-white; background: var(--sjr-primary); }
  .btn-primary:hover { background: var(--sjr-primary-dark); }
  .btn-primary:focus-visible { --tw-ring-color: var(--sjr-primary); }
  .btn-accent { @apply btn text-white; background: var(--sjr-accent); }
  .btn-accent:hover { background: var(--sjr-accent-dark); }
  .btn-ghost { @apply btn bg-transparent; color: var(--sjr-primary); }
  .btn-ghost:hover { background: var(--sjr-primary-soft); }
  .btn-outline { @apply btn bg-white; color: var(--sjr-ink); border: 1px solid var(--sjr-line); }
  .btn-outline:hover { border-color: var(--sjr-primary); color: var(--sjr-primary); }
  .btn-danger { @apply btn text-white; background: #c0392b; }
  .btn-danger:hover { background: #a5281c; }

  .card { @apply rounded-xl2 bg-white shadow-card; border: 1px solid var(--sjr-line); }

  .field-label { @apply block text-sm font-medium mb-1.5; color: var(--sjr-ink); }
  .field { @apply w-full rounded-lg border bg-white px-3.5 py-2.5 text-sm outline-none transition; border-color: var(--sjr-line); color: var(--sjr-ink); }
  .field:focus { border-color: var(--sjr-primary); box-shadow: 0 0 0 3px var(--sjr-primary-soft); }
  textarea.field { @apply min-h-[110px] leading-relaxed; }

  .badge { @apply inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold; }
  .eyebrow { @apply text-xs font-semibold uppercase tracking-wider; color: var(--sjr-muted); }
  .link { color: var(--sjr-primary); @apply font-medium hover:underline; }
}

.prose-block { white-space: pre-line; line-height: 1.65; }

SJREOF

echo "=== Navigation + couleurs mises à jour. Lance : npm run build ==="
