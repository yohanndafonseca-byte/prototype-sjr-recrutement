#!/usr/bin/env bash
# Remplace le placeholder 'SJR' par le logo officiel (public/logo-sjr.png) :
#  en-tete admin, page de connexion, pied de page public.
# A lancer a la racine du projet, puis : npm run build && git add -A && commit && push.
set -e

mkdir -p "$(dirname "app/admin/login/page.js")"
cat > "app/admin/login/page.js" << 'SJR_EOF_7f3c'
import Link from "next/link";
import { Suspense } from "react";
import LoginForm from "@/app/components/LoginForm";

export const dynamic = "force-dynamic";

export default function LoginPage() {
  return (
    <div className="grid min-h-screen place-items-center px-4" style={{ background: "linear-gradient(160deg,var(--sjr-primary-soft),var(--sjr-bg))" }}>
      <div className="w-full max-w-md">
        <div className="mb-6 text-center">
          <img src="/logo-sjr.png" alt="Ville de Saint-Jean-de-la-Ruelle" className="mx-auto mb-3 h-16 w-auto" />
          <h1 className="text-xl font-bold" style={{ color: "var(--sjr-ink)" }}>Espace RH — Recrutement</h1>
          <p className="text-sm" style={{ color: "var(--sjr-muted)" }}>Ville de Saint-Jean-de-la-Ruelle</p>
        </div>
        <div className="card p-6 md:p-8">
          <Suspense><LoginForm /></Suspense>
        </div>
        <p className="mt-4 text-center text-sm">
          <Link href="/recrutement" className="link">← Retour à l'espace candidat</Link>
        </p>
      </div>
    </div>
  );
}
SJR_EOF_7f3c

mkdir -p "$(dirname "app/admin/(dash)/layout.js")"
cat > "app/admin/(dash)/layout.js" << 'SJR_EOF_7f3c'
import Link from "next/link";
import { redirect } from "next/navigation";
import AdminNav from "@/app/components/AdminNav";
import LogoutButton from "@/app/components/LogoutButton";
import { getCurrentUser } from "@/lib/auth";

export const dynamic = "force-dynamic";

export default async function AdminLayout({ children }) {
  const user = await getCurrentUser();
  if (!user) redirect("/admin/login");

  return (
    <div className="min-h-screen">
      {/* Barre supérieure */}
      <header className="sticky top-0 z-20 border-b bg-white/90 backdrop-blur" style={{ borderColor: "var(--sjr-line)" }}>
        <div className="mx-auto flex max-w-[1400px] items-center justify-between px-4 py-3">
          <div className="flex items-center gap-3">
            <img src="/logo-sjr.png" alt="Ville de Saint-Jean-de-la-Ruelle" className="h-10 w-auto" />
            <div className="leading-tight">
              <div className="text-sm font-bold" style={{ color: "var(--sjr-ink)" }}>Recrutement · Espace RH</div>
              <div className="text-xs" style={{ color: "var(--sjr-muted)" }}>Ville de Saint-Jean-de-la-Ruelle</div>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <Link href="/recrutement" target="_blank" className="hidden text-xs sm:inline" style={{ color: "var(--sjr-muted)" }}>Voir l'espace candidat ↗</Link>
            <span className="hidden text-sm font-medium sm:inline" style={{ color: "var(--sjr-ink)" }}>{user.display_name}</span>
            <LogoutButton />
          </div>
        </div>
      </header>

      <div className="mx-auto flex max-w-[1400px] gap-6 px-4 py-6">
        <aside className="hidden w-60 shrink-0 md:block">
          <div className="sticky top-20 rounded-xl2 p-2" style={{ background: "#eef3f8", border: "1px solid var(--sjr-line)" }}>
            <AdminNav />
          </div>
        </aside>
        <main className="min-w-0 flex-1">{children}</main>
      </div>
    </div>
  );
}
SJR_EOF_7f3c

mkdir -p "$(dirname "app/components/PublicFooter.js")"
cat > "app/components/PublicFooter.js" << 'SJR_EOF_7f3c'
export default function PublicFooter() {
  return (
    <footer className="mt-16 text-white" style={{ background: "var(--sjr-primary-dark)" }}>
      <div className="container-sjr grid gap-8 py-12 md:grid-cols-3">
        <div>
          <div className="flex items-center gap-2">
            <span className="grid h-10 w-10 place-items-center rounded-md bg-white p-1"><img src="/logo-sjr.png" alt="Ville de Saint-Jean-de-la-Ruelle" className="h-full w-full object-contain" /></span>
            <span className="font-semibold">Ville de Saint-Jean-de-la-Ruelle</span>
          </div>
          <p className="mt-4 text-sm opacity-80">
            71, rue Charles-Beauhaire (BP 74)<br />45140 Saint-Jean-de-la-Ruelle
          </p>
        </div>
        <div className="text-sm">
          <h3 className="mb-3 font-semibold">Nous contacter</h3>
          <ul className="space-y-1.5 opacity-85">
            <li>Accueil : 02 38 79 33 00</li>
            <li>Services techniques : 02 38 79 58 00</li>
            <li>Du lundi au vendredi : 8h45–12h / 13h45–17h30</li>
            <li>Le samedi : 9h–12h30</li>
          </ul>
        </div>
        <div className="text-sm">
          <h3 className="mb-3 font-semibold">Recrutement</h3>
          <ul className="space-y-1.5 opacity-85">
            <li>Offres d'emploi de la Ville</li>
            <li>Candidature en ligne</li>
            <li>Suivi assuré par le service RH</li>
          </ul>
        </div>
      </div>
      <div className="border-t border-white/10">
        <div className="container-sjr flex flex-col gap-2 py-4 text-xs opacity-70 sm:flex-row sm:items-center sm:justify-between">
          <span>© {new Date().getFullYear()} Ville de Saint-Jean-de-la-Ruelle — Prototype espace recrutement</span>
          <span>Mentions légales · Accessibilité · Données personnelles</span>
        </div>
      </div>
    </footer>
  );
}
SJR_EOF_7f3c

echo "=== Logo officiel applique (3 fichiers). Lance : npm run build, puis git add -A && commit && push ==="
