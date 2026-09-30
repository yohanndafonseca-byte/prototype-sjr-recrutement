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
            <span className="grid h-9 w-9 place-items-center rounded-lg font-black text-white" style={{ background: "var(--sjr-primary)" }}>SJR</span>
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
