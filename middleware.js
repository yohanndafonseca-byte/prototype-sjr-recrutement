import { NextResponse } from "next/server";

const COOKIE = "sjr_rh_session";

export function middleware(req) {
  const { pathname } = req.nextUrl;
  const isProtected =
    (pathname.startsWith("/admin") && pathname !== "/admin/login") ||
    pathname.startsWith("/api/admin");

  if (!isProtected) return NextResponse.next();

  const token = req.cookies.get(COOKIE)?.value;
  if (!token) {
    if (pathname.startsWith("/api/")) {
      return NextResponse.json({ error: "Non authentifié" }, { status: 401 });
    }
    const url = req.nextUrl.clone();
    url.pathname = "/admin/login";
    url.searchParams.set("next", pathname);
    return NextResponse.redirect(url);
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/admin/:path*", "/api/admin/:path*"],
};
