import crypto from "crypto";
import { _raw } from "./db.js";
import { makeDemoPdf } from "./pdf.js";

const rr = _raw.rawRun;
const slug = (s) => String(s || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-zA-Z0-9]+/g, "_").replace(/^_+|_+$/g, "");
function dISO(offset) { const d = new Date(); d.setDate(d.getDate() + offset); return d.toISOString().slice(0, 10); }
function dtISO(offsetDays, hour = 9, min = 15) {
  const d = new Date(); d.setDate(d.getDate() + offsetDays); d.setHours(hour, min, 0, 0);
  return d.toISOString().slice(0, 19).replace("T", " ");
}
const M = (a) => a.join("\n");

export async function seedDatabase() {
  // ---------- Arborescence ----------
  const sectorTree = {
        "Pilotage et management des ressources": {
          "Direction des Ressources Humaines": ["Pôle Recrutement et carrières", "Pôle Formation et prévention"],
          "Direction des Finances": ["Pôle Comptabilité et budget"],
          "Direction des Systèmes d'information": ["Pôle Infrastructure et support"],
          "Direction de la Communication": ["Pôle Communication et évènementiel"],
        },
        "Politiques d'aménagement et de développement territorial": {
          "Direction de l'Urbanisme": ["Pôle Instruction des autorisations"],
          "Direction des Espaces publics": ["Pôle Voirie et propreté urbaine"],
        },
        "Interventions techniques": {
          "Direction des Services techniques": ["Pôle Bâtiments", "Pôle Espaces verts"],
          "Direction du Parc et logistique": ["Pôle Garage et matériel"],
        },
        "Services à la population": {
          "Direction de l'Éducation": ["Pôle Vie des écoles", "Pôle Restauration scolaire"],
          "Direction de la Petite enfance": ["Pôle Établissements d'accueil"],
          "Direction de la Culture et des sports": ["Pôle Médiathèques", "Pôle Équipements sportifs"],
          "Direction de la Relation aux usagers": ["Pôle État-civil et accueil"],
        },
        "Sécurité": {
          "Direction de la Tranquillité publique": ["Pôle Police municipale"],
        },
      };

  const P = {};
  let sort = 0;
  for (const [sName, dirs] of Object.entries(sectorTree)) {
    const sId = (await rr("INSERT INTO sectors (name, sort) VALUES (?,?)", [sName, sort++])).lastInsertRowid;
    for (const [dName, poles] of Object.entries(dirs)) {
      const dId = (await rr("INSERT INTO directions (sector_id, name) VALUES (?,?)", [sId, dName])).lastInsertRowid;
      for (const pName of poles) {
        const pId = (await rr("INSERT INTO poles (direction_id, name) VALUES (?,?)", [dId, pName])).lastInsertRowid;
        P[`${sName}|${dName}|${pName}`] = { sector_id: sId, direction_id: dId, pole_id: pId };
      }
    }
  }
  const loc = (s, d, p) => P[`${s}|${d}|${p}`];

  // ---------- Utilisateur RH ----------
  const salt = crypto.randomBytes(16).toString("hex");
  const hash = crypto.scryptSync("mairie2026", salt, 64).toString("hex");
  await rr("INSERT INTO users (username, password_hash, salt, display_name) VALUES (?,?,?,?)", ["rh", hash, salt, "Service RH"]);

  // ---------- Offres ----------
  const offers = [
        {
          reference: "OFF-2026-001", title: "Agent technique polyvalent",
          s: "Interventions techniques", d: "Direction des Services techniques", p: "Pôle Bâtiments",
          contract: "CDD", work: "Temps complet (35h)", positions: 3,
          deadline: dISO(28), published_at: dISO(-14), status: "publiee", createdOffset: -16,
          keywords: "maintenance, plomberie, électricité, second oeuvre, régie, bâtiment",
          missions: M(["Assurer la maintenance et les petites réparations du patrimoine bâti de la commune.",
            "Réaliser des interventions de second œuvre (peinture, plomberie, serrurerie, électricité de base).",
            "Participer à l'installation logistique des manifestations municipales.",
            "Signaler les dysfonctionnements et rendre compte de son activité."]),
          profile: M(["CAP/BEP technique ou expérience équivalente en régie bâtiment.",
            "Polyvalence, autonomie et sens du service public.",
            "Permis B exigé."]),
          conditions: M(["Poste à temps complet, du lundi au vendredi.",
            "Rémunération statutaire + régime indemnitaire.",
            "Astreintes techniques ponctuelles."]),
          extra: "Prise de poste dès que possible. Contact : service RH.",
        },
        {
          reference: "OFF-2026-002", title: "Assistant administratif — Ressources Humaines",
          s: "Pilotage et management des ressources", d: "Direction des Ressources Humaines", p: "Pôle Recrutement et carrières",
          contract: "Contractuel", work: "Temps complet (37h30)", positions: 1,
          deadline: dISO(20), published_at: dISO(-8), status: "publiee", createdOffset: -9,
          keywords: "administratif, gestion, paie, carrières, secrétariat, RH",
          missions: M(["Assurer le suivi administratif des dossiers du personnel.",
            "Préparer les actes de gestion (contrats, arrêtés).",
            "Contribuer au traitement des candidatures et à l'organisation des recrutements."]),
          profile: M(["Formation Bac+2 en gestion/administration.",
            "Rigueur, discrétion, maîtrise des outils bureautiques.",
            "La connaissance de la fonction publique territoriale est un plus."]),
          conditions: M(["Poste basé à l'Hôtel de Ville.", "Télétravail partiel possible après période d'essai."]),
        },
        {
          reference: "OFF-2026-003", title: "ATSEM",
          s: "Services à la population", d: "Direction de l'Éducation", p: "Pôle Vie des écoles",
          contract: "Titulaire", work: "Temps non complet (28h)", positions: 2,
          deadline: dISO(25), published_at: dISO(-6), status: "publiee", createdOffset: -7,
          keywords: "école, enfance, maternelle, atsem, périscolaire, éducation",
          missions: M(["Assister le personnel enseignant pour l'accueil et l'hygiène des jeunes enfants.",
            "Préparer et remettre en état les salles de classe et le matériel.",
            "Accompagner les enfants pendant le temps de restauration et de sieste."]),
          profile: M(["CAP Accompagnant éducatif petite enfance exigé.",
            "Patience, sens du contact avec les enfants et les familles."]),
          conditions: M(["Temps de travail annualisé sur le rythme scolaire."]),
        },
        {
          reference: "OFF-2026-004", title: "Agent des espaces verts",
          s: "Interventions techniques", d: "Direction des Services techniques", p: "Pôle Espaces verts",
          contract: "CDD", work: "Temps complet (35h)", positions: 2,
          deadline: dISO(9), published_at: dISO(-20), status: "publiee", createdOffset: -21,
          keywords: "jardinier, tonte, taille, fleurissement, espaces verts, nature",
          missions: M(["Entretenir les espaces verts, massifs et terrains de la commune.",
            "Réaliser la tonte, la taille, le désherbage et le fleurissement.",
            "Participer à la gestion différenciée et au zéro-phyto."]),
          profile: M(["CAPA travaux paysagers ou expérience.", "Permis B ; permis remorque apprécié."]),
          conditions: M(["Travail en extérieur.", "Équipements de protection fournis."]),
        },
        {
          reference: "OFF-2026-005", title: "Animateur périscolaire",
          s: "Services à la population", d: "Direction de l'Éducation", p: "Pôle Vie des écoles",
          contract: "Contractuel", work: "Temps non complet (17h30)", positions: 4,
          deadline: dISO(40), published_at: dISO(-3), status: "publiee", createdOffset: -3,
          keywords: "animation, BAFA, enfants, accueil de loisirs, périscolaire, jeunesse",
          missions: M(["Encadrer et animer les temps d'accueil périscolaire (matin, midi, soir).",
            "Concevoir et mener des activités adaptées à l'âge des enfants.",
            "Garantir la sécurité physique et affective des enfants."]),
          profile: M(["BAFA souhaité ou en cours.", "Dynamisme, créativité, esprit d'équipe."]),
          conditions: M(["Horaires fractionnés sur le temps scolaire."]),
        },
        {
          reference: "OFF-2026-006", title: "Gardien-brigadier de police municipale",
          s: "Sécurité", d: "Direction de la Tranquillité publique", p: "Pôle Police municipale",
          contract: "Titulaire", work: "Temps complet (35h)", positions: 1,
          deadline: dISO(18), published_at: dISO(-10), status: "publiee", createdOffset: -11,
          keywords: "police municipale, sécurité, prévention, tranquillité, voie publique",
          missions: M(["Assurer la surveillance de la voie publique et faire respecter les arrêtés du maire.",
            "Participer aux actions de prévention et de proximité.",
            "Rédiger les rapports et procès-verbaux."]),
          profile: M(["Concours de gardien-brigadier requis.", "Sens du service public et du contact."]),
          conditions: M(["Travail en brigade, y compris certains week-ends."]),
        },
        {
          reference: "OFF-2026-007", title: "Technicien informatique — support de proximité",
          s: "Pilotage et management des ressources", d: "Direction des Systèmes d'information", p: "Pôle Infrastructure et support",
          contract: "Contractuel", work: "Temps complet (37h30)", positions: 1,
          deadline: null, published_at: null, status: "brouillon", createdOffset: -2,
          keywords: "informatique, support, helpdesk, réseau, poste de travail",
          missions: M(["Assurer le support de premier niveau auprès des agents.",
            "Installer et maintenir les postes de travail et périphériques."]),
          profile: M(["Bac+2 informatique.", "Sens du service, autonomie."]),
          conditions: M(["Poste à pourvoir — publication à finaliser."]),
        },
        {
          reference: "OFF-2026-008", title: "Bibliothécaire — médiathèque",
          s: "Services à la population", d: "Direction de la Culture et des sports", p: "Pôle Médiathèques",
          contract: "Titulaire", work: "Temps complet (35h)", positions: 1,
          deadline: null, published_at: null, status: "brouillon", createdOffset: -1,
          keywords: "bibliothèque, médiathèque, culture, lecture publique, catalogage",
          missions: M(["Accueillir et conseiller les publics.", "Participer à la politique documentaire et à l'action culturelle."]),
          profile: M(["Formation métiers du livre appréciée."]),
          conditions: M(["Travail le samedi."]),
        },
        {
          reference: "OFF-2026-009", title: "Agent d'accueil et d'état-civil",
          s: "Services à la population", d: "Direction de la Relation aux usagers", p: "Pôle État-civil et accueil",
          contract: "CDD", work: "Temps complet (35h)", positions: 1,
          deadline: dISO(-6), published_at: dISO(-40), status: "publiee", createdOffset: -40,
          keywords: "accueil, état-civil, guichet, usagers, CNI, passeport",
          missions: M(["Accueillir, renseigner et orienter les usagers.",
            "Instruire les actes d'état-civil et les demandes de titres."]),
          profile: M(["Sens de l'accueil et rigueur administrative."]),
          conditions: M(["Poste au guichet unique."]),
        },
        {
          reference: "OFF-2026-010", title: "Chargé de communication",
          s: "Pilotage et management des ressources", d: "Direction de la Communication", p: "Pôle Communication et évènementiel",
          contract: "Contractuel", work: "Temps complet (37h30)", positions: 1,
          deadline: dISO(15), published_at: dISO(-25), status: "publiee", createdOffset: -26,
          keywords: "communication, réseaux sociaux, print, évènementiel, community management",
          missions: M(["Concevoir et diffuser les supports de communication de la Ville.",
            "Animer les réseaux sociaux et le site internet.",
            "Contribuer à l'organisation des évènements municipaux."]),
          profile: M(["Formation communication Bac+3/+5.", "Maîtrise des outils de PAO et du web."]),
          conditions: M(["Poste transverse rattaché à la Direction de la communication."]),
        },
      ];

  const offerIdByRef = {};
  for (const o of offers) {
    const l = loc(o.s, o.d, o.p);
    const info = await rr(`
      INSERT INTO offers (reference, title, sector_id, direction_id, pole_id, contract_type, work_time,
        location, positions_total, deadline, published_at, status, missions, profile, conditions,
        extra_info, keywords, created_at, updated_at)
      VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [o.reference, o.title, l.sector_id, l.direction_id, l.pole_id, o.contract, o.work,
       "Saint-Jean-de-la-Ruelle", o.positions, o.deadline || null, o.published_at || null, o.status,
       o.missions, o.profile, o.conditions, o.extra || null, o.keywords || null,
       dtISO(o.createdOffset ?? -20), dtISO(o.createdOffset ?? -20)]);
    offerIdByRef[o.reference] = info.lastInsertRowid;
  }

  // ---------- Candidatures ----------
  const firsts = ["Jean","Marie","Paul","Sophie","Karim","Nadia","Lucas","Emma","Thomas","Chloé","Mehdi","Julie","Antoine","Fatima","Hugo","Léa","Yanis","Camille","Nicolas","Sarah","Pierre","Aïcha","Julien","Manon"];
  const lasts = ["Dupont","Martin","Durand","Bernard","Moreau","Benali","Petit","Lefebvre","Garcia","Rousseau","Traoré","Faure","Girard","Nguyen","Bonnet","Lambert","Diallo","Fontaine","Roux","Vidal","Da Silva","Muller","Perrin","Blanc"];
  let ni = 0, li = 0;
  const nextName = () => { const f = firsts[ni % firsts.length]; const l = lasts[li % lasts.length]; ni++; li += 3; return { f, l }; };

  async function addApp(offerRef, status, createdOffset, opts = {}) {
    const offerId = offerIdByRef[offerRef];
    const offer = offers.find((o) => o.reference === offerRef);
    const { f, l } = opts.name || nextName();
    const ref = `CAND-2026-${crypto.randomBytes(3).toString("hex").toUpperCase()}`;
    const created = dtISO(createdOffset, 8 + (ni % 9), (ni * 7) % 60);
    const id = (await rr(`
      INSERT INTO applications (public_ref, offer_id, civility, last_name, first_name, address,
        postal_code, city, email, phone, status, created_at, updated_at)
      VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [ref, offerId, ni % 2 ? "Monsieur" : "Madame", l, f, `${3 + (ni % 40)} rue des Écoles`, "45140",
       "Saint-Jean-de-la-Ruelle",
       `${f}.${l}`.toLowerCase().normalize("NFD").replace(/[^a-z.]/g, "") + "@example.fr",
       "06 " + String(10000000 + ((ni * 1234567) % 89999999)).replace(/(\d{2})(?=\d)/g, "$1 ").trim(),
       status, created, created])).lastInsertRowid;

    const writeDoc = async (kind, label) => {
      const buf = makeDemoPdf(`${label} — ${f} ${l}`, [
        `Candidature : ${offer.title}`, `Référence offre : ${offerRef}`,
        `Candidat : ${f} ${l}`, "", "Document de démonstration généré par le prototype.",
      ]);
      await rr("INSERT INTO documents (application_id, kind, original_name, content, mime, size) VALUES (?,?,?,?,?,?)",
        [id, kind, `${label}_${l}.pdf`, buf.toString("base64"), "application/pdf", buf.length]);
    };
    await writeDoc("cv", "CV");
    if ((ni % 10) < 7) await writeDoc("lm", "Lettre de motivation");
    if ((ni % 10) < 4) await writeDoc("diplome", "Diplome");

    await rr("INSERT INTO events (application_id, type, message, created_at) VALUES (?,?,?,?)", [id, "creation", "Candidature reçue — statut initial : Nouvelle candidature.", created]);
    await rr("INSERT INTO events (application_id, type, message, created_at) VALUES (?,?,?,?)", [id, "email", "Accusé de réception envoyé au candidat (simulé).", created]);
    if (status !== "nouvelle") await rr("INSERT INTO events (application_id, type, message, created_at) VALUES (?,?,?,?)", [id, "statut", "Candidature prise en charge par la RH.", dtISO(createdOffset + 1, 10, 5)]);
    if (status === "recrute") await rr("INSERT INTO events (application_id, type, message, created_at) VALUES (?,?,?,?)", [id, "email", "Réponse positive envoyée au candidat (simulé).", dtISO(createdOffset + 3, 11, 0)]);
    if (status === "refusee") await rr("INSERT INTO events (application_id, type, message, created_at) VALUES (?,?,?,?)", [id, "email", "Réponse négative envoyée au candidat (simulé).", dtISO(createdOffset + 3, 11, 0)]);
    if (opts.note) await rr("INSERT INTO notes (application_id, body, created_at) VALUES (?,?,?)", [id, opts.note, dtISO(createdOffset + 1, 14, 30)]);
    return id;
  }

  // OFF-001 : 3 postes -> 1 recruté (2 restants), workflow riche
  addApp("OFF-2026-001", "recrute", -12, { name: { f: "Paul", l: "Durand" }, note: "Excellent profil technique, recruté après entretien." });
  addApp("OFF-2026-001", "retenue", -11, { note: "Retenu, en attente de confirmation administrative." });
  addApp("OFF-2026-001", "entretien", -10);
  addApp("OFF-2026-001", "preselectionnee", -9);
  addApp("OFF-2026-001", "a_etudier", -8);
  addApp("OFF-2026-001", "refusee", -9, { note: "Profil éloigné du poste." });
  addApp("OFF-2026-001", "nouvelle", -2);
  addApp("OFF-2026-001", "nouvelle", -1);

  // OFF-002 : RH
  addApp("OFF-2026-002", "entretien", -6, { note: "Bon relationnel, à confirmer sur la partie paie." });
  addApp("OFF-2026-002", "a_etudier", -5);
  addApp("OFF-2026-002", "nouvelle", -1);
  addApp("OFF-2026-002", "nouvelle", 0);

  // OFF-003 : ATSEM
  addApp("OFF-2026-003", "preselectionnee", -4);
  addApp("OFF-2026-003", "nouvelle", -1);
  addApp("OFF-2026-003", "nouvelle", 0);

  // OFF-004 : espaces verts (échéance proche)
  addApp("OFF-2026-004", "retenue", -14);
  addApp("OFF-2026-004", "entretien", -12);
  addApp("OFF-2026-004", "refusee", -13);
  addApp("OFF-2026-004", "nouvelle", -2);

  // OFF-005 : animateurs (4 postes)
  addApp("OFF-2026-005", "nouvelle", -2);
  addApp("OFF-2026-005", "nouvelle", -1);
  addApp("OFF-2026-005", "a_etudier", -2);

  // OFF-006 : police municipale
  addApp("OFF-2026-006", "entretien", -7);
  addApp("OFF-2026-006", "nouvelle", -1);

  // OFF-009 : offre expirée (garde son historique)
  addApp("OFF-2026-009", "refusee", -30);
  addApp("OFF-2026-009", "retenue", -28, { note: "Retenu mais recrutement non finalisé avant expiration." });
  addApp("OFF-2026-009", "a_etudier", -25);

  // OFF-010 : 1 poste -> recruté => offre devient POURVUE automatiquement
  addApp("OFF-2026-010", "recrute", -18, { name: { f: "Camille", l: "Fontaine" }, note: "Recrutée. Poste pourvu." });
  addApp("OFF-2026-010", "refusee", -17);
  addApp("OFF-2026-010", "refusee", -16);

  console.log("[seed] Jeu de démonstration inséré.");
}
