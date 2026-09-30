# Plateforme de recrutement — Ville de Saint-Jean-de-la-Ruelle

Prototype **fonctionnel** (et non une simple maquette) d'une plateforme de recrutement
municipale, à faire tourner **en local**. Deux espaces :

- **Espace candidat** (public, sans compte) : recherche d'offres, consultation, candidature en ligne avec dépôt de pièces.
- **Espace RH** (connexion) : tableau de bord, gestion des offres, suivi des candidatures et des recrutements.

Toutes les fonctionnalités sont réellement opérationnelles : les données sont persistées dans une base
SQLite locale, les fichiers déposés sont enregistrés sur le disque, les statuts évoluent selon une vraie
logique métier, et les e-mails sont *simulés* (tracés dans l'historique de chaque candidature).

---

## Prérequis

- **Node.js 18.18+** (testé sur Node 20/22)
- npm

## Installation & lancement

```bash
npm install
npm run dev
```

Puis ouvrir **http://localhost:3000** — vous êtes redirigé vers l'espace candidat.

> Au tout premier lancement, la base est créée et **peuplée automatiquement** avec un jeu de données de
> démonstration (offres, candidatures, documents PDF, notes, historique). Aucune étape supplémentaire.

### Espace RH

- Accès : lien **« Accès agents »** en haut de l'espace candidat, ou directement **/admin/login**
- Identifiant : **`rh`**
- Mot de passe : **`mairie2026`**

## Scripts

| Commande            | Effet                                                            |
|---------------------|------------------------------------------------------------------|
| `npm run dev`       | Démarre le serveur de développement (port 3000)                  |
| `npm run build`     | Build de production                                              |
| `npm start`         | Démarre le serveur après un build                                |
| `npm run reset-db`  | Réinitialise la base et les fichiers déposés (repart d'un seed propre) |

---

## Logique métier implémentée

### Offres — cycle de vie
`brouillon → publiée → (expirée | pourvue)`

- Une offre **publiée** est visible côté candidat tant que sa **date limite** n'est pas dépassée
  et qu'il reste des postes à pourvoir.
- **Expiration automatique** : passée la date limite, l'offre disparaît de l'espace candidat mais
  reste consultable côté RH (statut *Expirée*).
- **Nombre de postes à pourvoir** : c'est la pièce centrale. Seul le passage d'une candidature au
  statut **Recruté** décrémente le nombre de postes restants. Quand il atteint 0, l'offre passe
  automatiquement en **Pourvue** et n'est plus proposée aux candidats.

### Candidatures — workflow
`nouvelle → à étudier → présélectionnée → entretien → retenue → recrutée`
(le statut **Refusée** est accessible à toute étape.)

- Ouvrir une candidature **nouvelle** la fait passer automatiquement en **à étudier**.
- **Distinction importante : « Retenue » ≠ « Recruté ».** « Retenue » n'a aucun effet sur le nombre de
  postes ; seul « Recruté » décompte un poste et peut clôturer l'offre.
- Chaque changement de statut est horodaté dans l'**historique** de la candidature, avec envoi
  d'e-mail simulé (accusé de réception, réponse positive/négative).

---

## Données de démonstration

- Arborescence **Secteur › Direction › Pôle** réaliste d'une collectivité.
- 10 offres couvrant tous les statuts (publiées, brouillons, une expirée, une pourvue automatiquement).
- ~35 candidatures réparties sur tous les statuts, avec **vrais fichiers PDF** téléchargeables
  (CV systématique, lettre de motivation et diplômes selon les cas), notes internes et historique.

## Stockage des fichiers

Les pièces déposées sont enregistrées sur le disque, à côté de la base, selon l'arborescence :

```
storage/candidatures/<ANNÉE>/<REFERENCE_OFFRE>/<NOM_Prénom_id>/cv.pdf …
```

Le téléchargement côté RH est protégé par l'authentification.

---

## Stack technique

- **Next.js 14** (App Router) — un seul service, un seul port
- **better-sqlite3** — base SQLite locale (fichier `data/recrutement.db`)
- **Tailwind CSS** — interface
- Authentification par **session en base + cookie httpOnly** (hash scrypt)

## Personnalisation de la charte

Les couleurs sont centralisées en variables CSS dans `app/globals.css` (`--sjr-primary`, `--sjr-accent`, …).
Il suffit d'y reporter les codes exacts de la charte de la Ville pour aligner l'identité visuelle.

## Structure du projet

```
app/                 Pages (espace candidat + /admin) et routes API
  recrutement/       Espace candidat : liste, détail, candidature
  admin/             Espace RH : login + tableau de bord, offres, candidatures, recrutements
  api/               Route Handlers (candidatures, auth, admin)
  components/        Composants d'interface
lib/                 Logique métier (offres, candidatures, auth, base, PDF, formats)
data/                Base SQLite (générée)
storage/             Documents déposés (générés)
```

## Réinitialiser

```bash
npm run reset-db
```

Supprime la base et les fichiers déposés ; ils seront régénérés au prochain lancement.

---

### Notes sur les choix par défaut

- **Polices système** (aucune dépendance réseau) : le prototype fonctionne hors-ligne.
- **PDF de démonstration générés** réellement, donc ouvrables/téléchargeables.
- Palette institutionnelle bleu/vert par défaut, entièrement pilotée par variables CSS.

---

## Synchronisation Google Sheets (miroir + statistiques)

Le site peut recopier automatiquement chaque candidature et chaque changement
d'étape dans un Google Sheets, pour garder une trace hors application et produire
des statistiques. La base du site reste la source de vérité ; le Sheet en est un miroir.

Mise en place (~5 min, sans Google Cloud ni clé technique) :
1. Créer un Google Sheet vierge.
2. Menu **Extensions ▸ Apps Script**, coller le contenu de `google-sheets/AppsScript.gs`,
   remplacer la valeur de `SECRET` par un mot de passe.
3. **Déployer ▸ Nouveau déploiement ▸ Application Web** (exécuter en tant que soi,
   accès « Tout le monde »), autoriser, copier l'URL finissant par `/exec`.
4. Renseigner `SHEETS_WEBHOOK_URL` (l'URL) et `SHEETS_WEBHOOK_SECRET` (le même secret)
   dans le fichier `.env.local`, puis relancer `npm run dev`.

Deux onglets se remplissent tout seuls : **Candidatures** (une ligne par candidat,
mise à jour à chaque étape) et **Journal** (une ligne par événement horodaté).
Tant que `.env.local` n'est pas renseigné, la synchro reste simplement inactive.

---

## Déploiement en ligne (gratuit) — Turso + Netlify

Le prototype utilise désormais **libSQL** : en local il crée un fichier `data/local.db`
automatiquement ; en ligne il se connecte à une base **Turso** hébergée. Les pièces des
candidats sont stockées **dans la base** (plus de disque), ce qui le rend compatible avec
un hébergement serverless comme Netlify.

### 1) Créer la base Turso (gratuit, sans carte)
1. Compte sur https://turso.tech (connexion via GitHub).
2. Créer une base de données ("Create Database"), région Europe de préférence.
3. Récupérer deux valeurs : l'**URL** de la base (commence par `libsql://…`) et un **token**
   d'authentification ("Create Token").

### 2) Pré-remplir la base depuis le Codespace (une fois)
1. Dans le Codespace, ouvrir `.env.local` et renseigner :
   ```
   TURSO_DATABASE_URL=libsql://xxxxx.turso.io
   TURSO_AUTH_TOKEN=xxxxx
   ```
2. Lancer `npm run dev`, ouvrir le site une fois : le jeu de démo se crée dans Turso.
   (Ainsi la version en ligne démarrera déjà remplie.)

### 3) Déployer sur Netlify (depuis le Codespace)
```bash
npx netlify-cli login          # ouvre un lien à autoriser
npx netlify-cli init           # crée le site (ou 'link' si déjà créé)
npx netlify-cli env:set TURSO_DATABASE_URL "libsql://xxxxx.turso.io"
npx netlify-cli env:set TURSO_AUTH_TOKEN "xxxxx"
npx netlify-cli deploy --build --prod
```
La dernière commande affiche l'URL publique (en `.netlify.app`), disponible 24/7,
indépendamment de ton PC.

> Les variables d'environnement définies sur Netlify priment : `.env.local` ne sert qu'en local
> et n'est pas poussé (voir `.gitignore`).

### Remarques
- **RGPD** : Turso héberge hors UE par défaut selon la région choisie ; pour un vrai déploiement
  municipal avec données réelles, valider l'hébergement avec la DSI/le DPO. Pour une démo, ça convient.
- La synchro Google Sheets et l'export Excel fonctionnent à l'identique une fois en ligne.
