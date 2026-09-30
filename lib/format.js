const MONTHS = ["janv.","févr.","mars","avr.","mai","juin","juil.","août","sept.","oct.","nov.","déc."];

export function fmtDate(iso) {
  if (!iso) return "—";
  const d = new Date(iso.length <= 10 ? iso + "T00:00:00" : iso);
  if (isNaN(d)) return iso;
  return `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
}

export function fmtDateTime(iso) {
  if (!iso) return "—";
  const d = new Date(iso.replace(" ", "T") + (iso.includes("T") || iso.includes("Z") ? "" : "Z"));
  if (isNaN(d)) return iso;
  const hh = String(d.getHours()).padStart(2, "0");
  const mm = String(d.getMinutes()).padStart(2, "0");
  return `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()} à ${hh}h${mm}`;
}

export function daysUntil(iso) {
  if (!iso) return null;
  const d = new Date(iso + "T23:59:59");
  const now = new Date();
  return Math.ceil((d - now) / (1000 * 60 * 60 * 24));
}

export function fmtBytes(n) {
  if (!n && n !== 0) return "";
  if (n < 1024) return n + " o";
  if (n < 1024 * 1024) return (n / 1024).toFixed(0) + " Ko";
  return (n / 1024 / 1024).toFixed(1) + " Mo";
}

export function initials(first, last) {
  return ((first?.[0] || "") + (last?.[0] || "")).toUpperCase();
}
