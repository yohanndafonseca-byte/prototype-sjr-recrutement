// ---- Statuts d'offre ----
export const OFFER_STATUS = {
  BROUILLON: "brouillon",
  PUBLIEE: "publiee",
  EXPIREE: "expiree",
  POURVUE: "pourvue",
};

export const OFFER_STATUS_LABEL = {
  brouillon: "Brouillon",
  publiee: "Publiée",
  expiree: "Expirée",
  pourvue: "Pourvue",
};

// ---- Statuts de candidature (workflow V1) ----
export const APP_STATUS = {
  NOUVELLE: "nouvelle",
  A_ETUDIER: "a_etudier",
  PRESELECTIONNEE: "preselectionnee",
  ENTRETIEN: "entretien",
  RETENUE: "retenue",
  RECRUTE: "recrute",
  REFUSEE: "refusee",
};

export const APP_STATUS_LABEL = {
  nouvelle: "Nouvelle candidature",
  a_etudier: "À étudier",
  preselectionnee: "Présélectionnée",
  entretien: "Entretien",
  retenue: "Retenue",
  recrute: "Recruté",
  refusee: "Refusée",
};

// Ordre normal du processus (Refusée est transverse)
export const APP_FLOW = [
  "nouvelle",
  "a_etudier",
  "preselectionnee",
  "entretien",
  "retenue",
  "recrute",
];

// Transitions autorisées depuis un statut donné.
// Refusée est atteignable depuis n'importe quelle étape non finale.
export function allowedTransitions(current) {
  if (current === "recrute") return ["retenue"]; // possibilité d'annuler un recrutement
  if (current === "refusee") return ["a_etudier"]; // ré-ouvrir une candidature refusée
  const idx = APP_FLOW.indexOf(current);
  const next = [];
  if (idx >= 0 && idx < APP_FLOW.length - 1) next.push(APP_FLOW[idx + 1]);
  if (idx > 0) next.push(APP_FLOW[idx - 1]); // revenir en arrière
  next.push("refusee");
  return [...new Set(next)];
}

export const DOC_KINDS = {
  cv: { label: "CV", required: true, hint: "obligatoire" },
  lm: { label: "Lettre de motivation", required: false, hint: "recommandée" },
  diplome: { label: "Diplôme(s)", required: false, hint: "recommandé" },
  autre: { label: "Autres documents", required: false, hint: "facultatif" },
};

export const CONTRACT_TYPES = ["CDI", "CDD", "Titulaire", "Contractuel", "Apprentissage", "Stage"];
export const WORK_TIMES = ["Temps complet (35h)", "Temps complet (37h30)", "Temps non complet (28h)", "Temps non complet (17h30)"];

export const MAX_FILE_MB = 8;
export const ACCEPTED_EXT = [".pdf", ".doc", ".docx", ".png", ".jpg", ".jpeg"];
