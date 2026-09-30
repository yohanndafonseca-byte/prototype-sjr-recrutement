"use client";
import { useRouter } from "next/navigation";
import { IconLogout } from "./Icons";

export default function LogoutButton() {
  const router = useRouter();
  async function out() {
    await fetch("/api/auth/logout", { method: "POST" });
    router.push("/admin/login");
    router.refresh();
  }
  return (
    <button onClick={out} className="btn-outline text-xs">
      <IconLogout className="h-4 w-4" /> Déconnexion
    </button>
  );
}
