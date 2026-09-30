import "./globals.css";

export const metadata = {
  title: "Recrutement — Ville de Saint-Jean-de-la-Ruelle",
  description: "Espace recrutement de la Ville de Saint-Jean-de-la-Ruelle : offres d'emploi et candidatures en ligne.",
};

export default function RootLayout({ children }) {
  return (
    <html lang="fr">
      <body className="min-h-screen antialiased">{children}</body>
    </html>
  );
}
