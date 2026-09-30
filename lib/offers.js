import { dbAll, dbGet, dbRun } from "./db.js";
import { OFFER_STATUS } from "./constants.js";

export function todayISO() {
  return new Date().toISOString().slice(0, 10);
}

const BASE_SELECT = `
  SELECT o.*,
    s.name AS sector_name,
    d.name AS direction_name,
    p.name AS pole_name,
    (SELECT COUNT(*) FROM applications a WHERE a.offer_id = o.id) AS applications_count,
    (SELECT COUNT(*) FROM applications a WHERE a.offer_id = o.id AND a.status = 'recrute') AS positions_filled
  FROM offers o
  LEFT JOIN sectors s ON s.id = o.sector_id
  LEFT JOIN directions d ON d.id = o.direction_id
  LEFT JOIN poles p ON p.id = o.pole_id
`;

function enrich(row) {
  if (!row) return row;
  row.positions_total = Number(row.positions_total);
  row.positions_filled = Number(row.positions_filled) || 0;
  row.positions_remaining = Math.max(0, row.positions_total - row.positions_filled);
  row.is_expired = row.deadline ? row.deadline < todayISO() : false;
  return row;
}

export async function syncOffer(id) {
  const row = enrich(await dbGet(BASE_SELECT + " WHERE o.id = ?", [id]));
  if (!row) return null;
  let newStatus = row.status;
  if (row.status === OFFER_STATUS.PUBLIEE) {
    if (row.positions_remaining <= 0) newStatus = OFFER_STATUS.POURVUE;
    else if (row.is_expired) newStatus = OFFER_STATUS.EXPIREE;
  } else if (row.status === OFFER_STATUS.POURVUE) {
    if (row.positions_remaining > 0 && !row.is_expired) newStatus = OFFER_STATUS.PUBLIEE;
    else if (row.positions_remaining > 0 && row.is_expired) newStatus = OFFER_STATUS.EXPIREE;
  }
  if (newStatus !== row.status) {
    await dbRun("UPDATE offers SET status = ?, updated_at = datetime('now') WHERE id = ?", [newStatus, id]);
    row.status = newStatus;
  }
  return row;
}

export async function syncAll() {
  const ids = await dbAll("SELECT id FROM offers");
  for (const { id } of ids) await syncOffer(id);
}

export async function getOffer(id) {
  await syncOffer(id);
  return enrich(await dbGet(BASE_SELECT + " WHERE o.id = ?", [id]));
}

export async function listPublicOffers(q = "") {
  await syncAll();
  const rows = (await dbAll(BASE_SELECT + " WHERE o.status = 'publiee' ORDER BY o.published_at DESC, o.id DESC"))
    .map(enrich)
    .filter((o) => !o.is_expired && o.positions_remaining > 0);
  const term = (q || "").trim().toLowerCase();
  if (!term) return rows;
  return rows.filter((o) => {
    const hay = [o.title, o.sector_name, o.direction_name, o.pole_name, o.contract_type, o.location, o.keywords, o.missions, o.profile]
      .filter(Boolean).join(" ").toLowerCase();
    return term.split(/\s+/).every((t) => hay.includes(t));
  });
}

export async function getPublicOffer(id) {
  const o = await getOffer(id);
  if (!o) return null;
  if (o.status !== "publiee" || o.is_expired || o.positions_remaining <= 0) return null;
  return o;
}

export async function listAdminOffers({ status = null, q = "" } = {}) {
  await syncAll();
  let rows = (await dbAll(BASE_SELECT + " ORDER BY o.updated_at DESC, o.id DESC")).map(enrich);
  if (status) rows = rows.filter((o) => o.status === status);
  const term = (q || "").trim().toLowerCase();
  if (term) {
    rows = rows.filter((o) =>
      [o.title, o.reference, o.sector_name, o.direction_name, o.pole_name]
        .filter(Boolean).join(" ").toLowerCase().includes(term)
    );
  }
  return rows;
}

export async function nextReference() {
  const year = new Date().getFullYear();
  const row = await dbGet("SELECT COUNT(*) AS n FROM offers");
  const seq = String(Number(row.n) + 1).padStart(3, "0");
  return `OFF-${year}-${seq}`;
}

const OFFER_FIELDS = ["title","sector_id","direction_id","pole_id","contract_type","work_time","location","positions_total","deadline","missions","profile","conditions","extra_info","keywords"];

export async function createOffer(data, { publish = false } = {}) {
  const reference = data.reference || (await nextReference());
  const status = publish ? "publiee" : "brouillon";
  const published_at = publish ? todayISO() : null;
  const args = [
    reference, data.title || "Sans titre", data.sector_id || null, data.direction_id || null,
    data.pole_id || null, data.contract_type || null, data.work_time || null,
    data.location || "Saint-Jean-de-la-Ruelle", Math.max(1, parseInt(data.positions_total) || 1),
    data.deadline || null, data.missions || null, data.profile || null, data.conditions || null,
    data.extra_info || null, data.keywords || null, status, published_at,
  ];
  const info = await dbRun(`
    INSERT INTO offers (reference, title, sector_id, direction_id, pole_id, contract_type,
      work_time, location, positions_total, deadline, missions, profile, conditions,
      extra_info, keywords, status, published_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`, args);
  return getOffer(info.lastInsertRowid);
}

export async function updateOffer(id, data) {
  const current = await dbGet("SELECT * FROM offers WHERE id = ?", [id]);
  if (!current) return null;
  const merged = { ...current };
  for (const f of OFFER_FIELDS) if (f in data && data[f] !== undefined) merged[f] = data[f];
  merged.positions_total = Math.max(1, parseInt(merged.positions_total) || 1);
  await dbRun(`
    UPDATE offers SET title=?, sector_id=?, direction_id=?, pole_id=?, contract_type=?, work_time=?,
      location=?, positions_total=?, deadline=?, missions=?, profile=?, conditions=?, extra_info=?,
      keywords=?, updated_at=datetime('now') WHERE id=?`,
    [merged.title, merged.sector_id, merged.direction_id, merged.pole_id, merged.contract_type,
     merged.work_time, merged.location, merged.positions_total, merged.deadline, merged.missions,
     merged.profile, merged.conditions, merged.extra_info, merged.keywords, id]);
  return getOffer(id);
}

export async function setOfferStatus(id, status, { setPublishedAt = false } = {}) {
  if (setPublishedAt) {
    await dbRun("UPDATE offers SET status=?, published_at=?, updated_at=datetime('now') WHERE id=?", [status, todayISO(), id]);
  } else {
    await dbRun("UPDATE offers SET status=?, updated_at=datetime('now') WHERE id=?", [status, id]);
  }
  return getOffer(id);
}

export async function publishOffer(id) {
  const o = await dbGet("SELECT published_at FROM offers WHERE id=?", [id]);
  return setOfferStatus(id, "publiee", { setPublishedAt: !o?.published_at });
}
export async function unpublishOffer(id) {
  return setOfferStatus(id, "brouillon");
}

export async function getMetaTree() {
  const sectors = await dbAll("SELECT * FROM sectors ORDER BY sort, name");
  const directions = await dbAll("SELECT * FROM directions ORDER BY name");
  const poles = await dbAll("SELECT * FROM poles ORDER BY name");
  return sectors.map((s) => ({
    ...s,
    directions: directions.filter((d) => d.sector_id === s.id).map((d) => ({
      ...d, poles: poles.filter((p) => p.direction_id === d.id),
    })),
  }));
}

export async function dashboardStats() {
  await syncAll();
  const newApps = Number((await dbGet("SELECT COUNT(*) AS n FROM applications WHERE status='nouvelle'")).n);
  const inProgress = Number((await dbGet("SELECT COUNT(*) AS n FROM applications WHERE status IN ('a_etudier','preselectionnee','entretien','retenue')")).n);
  const published = Number((await dbGet("SELECT COUNT(*) AS n FROM offers WHERE status='publiee'")).n);
  const soon = (await listAdminOffers({ status: "publiee" })).filter((o) => {
    if (!o.deadline) return false;
    const d = Math.ceil((new Date(o.deadline + "T23:59:59") - new Date()) / 86400000);
    return d >= 0 && d <= 14;
  });
  const totalOffers = Number((await dbGet("SELECT COUNT(*) AS n FROM offers")).n);
  const recruited = Number((await dbGet("SELECT COUNT(*) AS n FROM applications WHERE status='recrute'")).n);
  return { newApps, inProgress, published, soon, totalOffers, recruited };
}
