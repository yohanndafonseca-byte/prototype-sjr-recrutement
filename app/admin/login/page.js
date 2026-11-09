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
