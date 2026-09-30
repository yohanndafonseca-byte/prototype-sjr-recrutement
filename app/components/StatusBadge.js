import { OFFER_STATUS_LABEL, APP_STATUS_LABEL } from "@/lib/constants";

const OFFER_STYLE = {
  brouillon: "bg-slate-100 text-slate-600",
  publiee: "bg-emerald-50 text-emerald-700",
  expiree: "bg-amber-50 text-amber-700",
  pourvue: "bg-indigo-50 text-indigo-700",
};
const APP_STYLE = {
  nouvelle: "bg-sky-50 text-sky-700",
  a_etudier: "bg-blue-50 text-blue-700",
  preselectionnee: "bg-violet-50 text-violet-700",
  entretien: "bg-amber-50 text-amber-700",
  retenue: "bg-teal-50 text-teal-700",
  recrute: "bg-emerald-50 text-emerald-700",
  refusee: "bg-rose-50 text-rose-700",
};
const DOT = {
  brouillon: "bg-slate-400", publiee: "bg-emerald-500", expiree: "bg-amber-500", pourvue: "bg-indigo-500",
  nouvelle: "bg-sky-500", a_etudier: "bg-blue-500", preselectionnee: "bg-violet-500",
  entretien: "bg-amber-500", retenue: "bg-teal-500", recrute: "bg-emerald-500", refusee: "bg-rose-500",
};

export function OfferBadge({ status }) {
  return (
    <span className={`badge ${OFFER_STYLE[status] || "bg-slate-100 text-slate-600"}`}>
      <span className={`h-1.5 w-1.5 rounded-full ${DOT[status] || "bg-slate-400"}`} />
      {OFFER_STATUS_LABEL[status] || status}
    </span>
  );
}
export function AppBadge({ status }) {
  return (
    <span className={`badge ${APP_STYLE[status] || "bg-slate-100 text-slate-600"}`}>
      <span className={`h-1.5 w-1.5 rounded-full ${DOT[status] || "bg-slate-400"}`} />
      {APP_STATUS_LABEL[status] || status}
    </span>
  );
}
