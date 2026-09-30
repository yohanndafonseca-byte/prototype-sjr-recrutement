"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { IconGrid, IconBriefcase, IconInbox, IconStar } from "./Icons";

const ITEMS = [
  { href: "/admin", label: "Tableau de bord", icon: IconGrid, exact: true },
  { href: "/admin/offres", label: "Offres", icon: IconBriefcase },
  { href: "/admin/candidatures", label: "Candidatures", icon: IconInbox },
  { href: "/admin/recrutements", label: "Recrutements finalisés", icon: IconStar },
];

export default function AdminNav() {
  const path = usePathname();
  return (
    <nav className="space-y-1">
      {ITEMS.map(({ href, label, icon: Icon, exact }) => {
        const active = exact ? path === href : path.startsWith(href);
        return (
          <Link key={href} href={href}
            className={`flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors ${active ? "text-white" : "hover:bg-white"}`}
            style={active ? { background: "var(--sjr-primary)" } : { color: "var(--sjr-ink)" }}>
            <Icon className="h-5 w-5" />
            {label}
          </Link>
        );
      })}
    </nav>
  );
}
