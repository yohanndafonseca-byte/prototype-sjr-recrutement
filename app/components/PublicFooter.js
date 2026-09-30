export default function PublicFooter() {
  return (
    <footer className="mt-16 text-white" style={{ background: "var(--sjr-primary-dark)" }}>
      <div className="container-sjr grid gap-8 py-12 md:grid-cols-3">
        <div>
          <div className="flex items-center gap-2">
            <span className="grid h-9 w-9 place-items-center rounded-md bg-white/15 font-black">SJR</span>
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
