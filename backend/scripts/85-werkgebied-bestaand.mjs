// HeitjeHulp B2-herstel — werkgebied voor BESTAANDE accounts (4 okt 2026)
//
// Het werkgebied (wijk "Tiel en omstreken" + werkgebied_status) wordt sinds B2
// alleen bepaald bij aanmelden of bij een andere postcode. Accounts van vóór B2
// (zonder wijk) kregen het nooit en zien "Nog niet in jouw buurt".
// Dit script zoekt hh_users met een postcode maar ZONDER wijk, geocodeert de
// postcode (4 cijfers of 4 cijfers + 2 letters) via Nominatim (1 verzoek per
// seconde, zelfde User-Agent als de hook) en zet wijk + werkgebied_status.
// Bestaande wijken worden NOOIT overschreven.
//
//   node scripts/85-werkgebied-bestaand.mjs           dry-run (schrijft niets)
//   node scripts/85-werkgebied-bestaand.mjs --apply   schrijft naar prod
// Superuser uit de omgeving: set -a; . /Users/h/Desktop/qawayhabase/.env; set +a

import { readFileSync } from "node:fs";
// Zelfde laadwijze als tests/hh_aanmelden_hulp.test.mjs (het hook-bestand is CommonJS).
const bron = readFileSync(new URL("../pb_hooks/hh_aanmelden_hulp.js", import.meta.url), "utf8");
const mod = { exports: {} };
new Function("module", "exports", bron)(mod, mod.exports);
const hulp = mod.exports;

const BASIS = process.env.PB_URL || "https://api.qawayahbase.com";
const APPLY = process.argv.includes("--apply");
const USER_AGENT = "HeitjeHulp/0.1 (info@heitjehulp.nl)";

const slaap = (ms) => new Promise((r) => setTimeout(r, ms));

async function api(pad, opties = {}, token) {
  const res = await fetch(BASIS + pad, {
    ...opties,
    headers: { "content-type": "application/json", ...(token ? { Authorization: token } : {}), ...(opties.headers || {}) },
  });
  const tekst = await res.text();
  let json = null;
  try { json = JSON.parse(tekst); } catch { /* leeg */ }
  if (!res.ok) throw new Error(`${opties.method || "GET"} ${pad} -> ${res.status} ${tekst.slice(0, 200)}`);
  return json;
}

function netjesPostcode(pc) {
  const m = /^([1-9]\d{3})\s*([A-Za-z]{2})?$/.exec(String(pc || "").trim());
  if (!m) return null;
  return m[2] ? `${m[1]} ${m[2].toUpperCase()}` : m[1];
}

async function geocode(postcode, plaats) {
  // 6 tekens: gestructureerd zoals de hook. Alleen 4 cijfers: Nominatim vindt
  // die niet los, dan vrije tekst "4001 Tiel" (met de plaats uit het account).
  const url = postcode.length > 4
    ? hulp.nominatimUrl("https://nominatim.openstreetmap.org/search", postcode)
    : "https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=nl&q=" + encodeURIComponent(postcode + " " + (plaats || ""));
  const res = await fetch(url, { headers: { "User-Agent": USER_AGENT, Accept: "application/json" } });
  if (!res.ok) return null;
  const lijst = await res.json();
  if (!Array.isArray(lijst) || lijst.length === 0) return null;
  const lat = parseFloat(lijst[0].lat), lon = parseFloat(lijst[0].lon);
  return isFinite(lat) && isFinite(lon) ? { lat, lon } : null;
}

const auth = await api("/api/collections/_superusers/auth-with-password", {
  method: "POST",
  body: JSON.stringify({ identity: process.env.PB_ADMIN_EMAIL, password: process.env.PB_ADMIN_PASSWORD }),
});
const token = auth.token;
console.log(`Verbonden met ${BASIS} (${APPLY ? "APPLY" : "DRY-RUN"})\n`);

const wijken = await api(`/api/collections/hh_wijken/records?perPage=200`, {}, token);
const wijkId = (gebied) => {
  const w = (wijken.items || []).find((x) => x.wijk === gebied.wijk && x.gemeente === gebied.gemeente && x.actief);
  return w ? w.id : "";
};

const filter = encodeURIComponent(`wijk = "" && postcode != "" && rol != "coordinator"`);
const users = await api(`/api/collections/hh_users/records?perPage=500&filter=${filter}`, {}, token);
let teller = { binnen: 0, buiten: 0, onbekend: 0, geschreven: 0 };

for (const u of users.items || []) {
  const pc = netjesPostcode(u.postcode);
  let status = "onbekend", wijk = "";
  if (pc) {
    await slaap(1100);
    const punt = await geocode(pc, u.plaats);
    if (punt) {
      const gebied = hulp.werkgebiedVoorPunt(punt);
      if (gebied) { wijk = wijkId(gebied); status = wijk ? "binnen" : "onbekend"; }
      else status = "buiten";
    }
  }
  teller[status]++;
  console.log(`  ${APPLY ? "↻ zet" : "+ ZOU zetten"}: ${u.id} ${u.naam} (${u.rol}) pc "${u.postcode}" -> ${status}${wijk ? " wijk " + wijk : ""}`);
  if (APPLY) {
    const body = { werkgebied_status: status };
    if (wijk) body.wijk = wijk;
    await api(`/api/collections/hh_users/records/${u.id}`, { method: "PATCH", body: JSON.stringify(body) }, token);
    teller.geschreven++;
  }
}

console.log(`\n${(users.items || []).length} account(s) zonder wijk: binnen ${teller.binnen}, buiten ${teller.buiten}, onbekend ${teller.onbekend}.`);
console.log(APPLY ? `✓ ${teller.geschreven} bijgewerkt.` : "DRY-RUN: niets geschreven. Draai met --apply.");
