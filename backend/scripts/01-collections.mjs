// HeitjeHulp M1 stap 3 — maakt de dertien hh_-collecties aan op de gedeelde
// PocketBase (api.qawayahbase.com, v0.25.9, fields-API). Idempotent: bestaat
// een collectie al, dan wordt hij overgeslagen; ontbrekende velden en indexen
// worden wél bijgemaakt. Bestaande velden worden nooit verwijderd of gewijzigd.
//
// PREFIX IS hh_. Raakt geen enkele andere collectie op deze server aan; de
// hard-guard in _lib.mjs weigert elke naam zonder hh_-prefix.
//
// API-rules blijven hier op null (= alleen superuser). Die komen in 02-rules.mjs.
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/01-collections.mjs            (dry-run: print wat er ZOU gebeuren)
//   node scripts/01-collections.mjs --apply    (echt aanmaken)
//
// Volgorde: eerst collecties zonder relaties (hh_wijken, hh_klustypes), dan
// hh_users (→ hh_wijken), dan de rest (→ hh_users / hh_klustypes / hh_klussen).

import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

// Vaste enum-waarden, Nederlands, precies zoals hoofdstuk 4 / PROMPT-M1.
export const ROLLEN = ['hulpvrager', 'jongere', 'familie', 'coordinator'];
export const TALEN = ['nl', 'ar', 'tr', 'en'];
export const KLUS_STATUSSEN = ['concept', 'open', 'geaccepteerd', 'onderweg', 'bezig', 'afgerond', 'geannuleerd', 'probleem'];
export const BRONNEN = ['app', 'telefoon', 'familie'];
export const BETALING_STATUSSEN = ['open', 'betaald', 'mislukt', 'terugbetaald'];
// Onderstaande waarden staan niet letterlijk in hoofdstuk 4; keuze vastgelegd in
// SCHEMA.txt en OPEN-PUNTEN.txt.
export const SCREENING_STATUSSEN = ['nieuw', 'in_behandeling', 'goedgekeurd', 'afgewezen']; // M3-statusmachine
export const KOPPELING_RECHTEN = ['meekijken', 'plaatsen'];
export const VERGOEDING_STATUSSEN = ['open', 'uitbetaald', 'mislukt'];
export const INCIDENT_SOORTEN = ['nood', 'probleem', 'overig'];
export const PLATFORMS = ['ios', 'android'];

const AFBEELDING_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif', 'image/gif'];
const MB = 1024 * 1024;

// Elke collectie krijgt created + updated als autodate.
const AUTODATES = [
  { name: 'created', type: 'autodate', onCreate: true, onUpdate: false },
  { name: 'updated', type: 'autodate', onCreate: true, onUpdate: true },
];

const rel = (collectionId, extra = {}) => ({
  type: 'relation',
  collectionId,
  maxSelect: 1,
  cascadeDelete: false,
  ...extra,
});
const sel = (values, extra = {}) => ({ type: 'select', values, maxSelect: 1, ...extra });
const centen = (name) => ({ name, type: 'number', onlyInt: true, min: 0 }); // bedragen in centen, nooit required (0 is geldig)

// ids = { hh_users, hh_wijken, hh_klustypes, hh_klussen } — bij dry-run placeholders.
export const SPEC = [
  {
    name: 'hh_wijken',
    type: 'base',
    fields: () => [
      { name: 'gemeente', type: 'text', required: true, max: 100 },
      { name: 'wijk', type: 'text', required: true, max: 100 },
      { name: 'postcodes', type: 'json', maxSize: 4000 }, // lijst van postcode-prefixen, bv. ["4003","4004"]
      { name: 'actief', type: 'bool' },
    ],
    indexes: ['CREATE UNIQUE INDEX idx_hh_wijken_gemeente_wijk ON hh_wijken (gemeente, wijk)'],
  },
  {
    name: 'hh_klustypes',
    type: 'base',
    fields: () => [
      { name: 'naam', type: 'text', required: true, max: 100 },
      { name: 'icoon', type: 'text', max: 60 },
      { name: 'richtduur', type: 'number', onlyInt: true, min: 0 }, // minuten
      centen('richtvergoeding'),
    ],
    indexes: ['CREATE UNIQUE INDEX idx_hh_klustypes_naam ON hh_klustypes (naam)'],
  },
  {
    name: 'hh_users',
    type: 'auth',
    fields: (ids) => [
      { name: 'rol', ...sel(ROLLEN), required: true },
      { name: 'naam', type: 'text', required: true, max: 200 },
      { name: 'telefoon', type: 'text', max: 30 },
      { name: 'geboortedatum', type: 'date' },
      { name: 'foto', type: 'file', maxSelect: 1, maxSize: 5 * MB, mimeTypes: AFBEELDING_TYPES, thumbs: ['200x200'] },
      { name: 'wijk', ...rel(ids.hh_wijken) },
      { name: 'taal', ...sel(TALEN) }, // PocketBase kent geen default op select; app/seed zet "nl"
    ],
    indexes: [],
  },
  {
    name: 'hh_profielen',
    type: 'base',
    fields: (ids) => [
      { name: 'gebruiker', ...rel(ids.hh_users, { required: true, cascadeDelete: true }) },
      { name: 'verificatiestatus', ...sel(SCREENING_STATUSSEN) },
      { name: 'vog_status', ...sel(SCREENING_STATUSSEN) },
      { name: 'iban_geverifieerd', type: 'bool' },
      { name: 'straal_km', type: 'number', min: 0 },
      { name: 'beschikbaarheid', type: 'json', maxSize: 8000 },
      { name: 'klustypes', ...rel(ids.hh_klustypes, { maxSelect: 20 }) },
      { name: 'sterren_gemiddeld', type: 'number', min: 0, max: 5 },
      { name: 'klussen_aantal', type: 'number', onlyInt: true, min: 0 },
    ],
    indexes: ['CREATE UNIQUE INDEX idx_hh_profielen_gebruiker ON hh_profielen (gebruiker)'],
  },
  {
    name: 'hh_klussen',
    type: 'base',
    fields: (ids) => [
      { name: 'hulpvrager', ...rel(ids.hh_users, { required: true }) },
      { name: 'geplaatst_door', ...rel(ids.hh_users) },
      { name: 'klustype', ...rel(ids.hh_klustypes) },
      { name: 'omschrijving', type: 'text', max: 2000 },
      { name: 'adres', type: 'text', max: 300 },
      { name: 'lat', type: 'number' },
      { name: 'lon', type: 'number' },
      { name: 'wanneer_van', type: 'date' },
      { name: 'wanneer_tot', type: 'date' },
      { name: 'status', ...sel(KLUS_STATUSSEN), required: true },
      centen('bedrag_bruto'),
      centen('vergoeding_jongere'),
      centen('commissie'),
      { name: 'toegewezen_jongere', ...rel(ids.hh_users) },
      { name: 'bron', ...sel(BRONNEN) },
    ],
    indexes: [
      'CREATE INDEX idx_hh_klussen_status ON hh_klussen (status)',
      'CREATE INDEX idx_hh_klussen_hulpvrager ON hh_klussen (hulpvrager)',
      'CREATE INDEX idx_hh_klussen_toegewezen_jongere ON hh_klussen (toegewezen_jongere)',
    ],
  },
  {
    name: 'hh_klus_status',
    type: 'base',
    fields: (ids) => [
      { name: 'klus', ...rel(ids.hh_klussen, { required: true, cascadeDelete: true }) },
      { name: 'door', ...rel(ids.hh_users) }, // wie; "wanneer" = created
      { name: 'van', ...sel(KLUS_STATUSSEN) }, // leeg bij de eerste logregel
      { name: 'naar', ...sel(KLUS_STATUSSEN), required: true },
    ],
    indexes: ['CREATE INDEX idx_hh_klus_status_klus ON hh_klus_status (klus)'],
  },
  {
    name: 'hh_beoordelingen',
    type: 'base',
    fields: (ids) => [
      { name: 'klus', ...rel(ids.hh_klussen, { required: true }) },
      { name: 'van_gebruiker', ...rel(ids.hh_users, { required: true }) },
      { name: 'naar_gebruiker', ...rel(ids.hh_users, { required: true }) },
      { name: 'sterren', type: 'number', onlyInt: true, min: 1, max: 5 },
      { name: 'tekst', type: 'text', max: 1000 },
    ],
    // Eén beoordeling per klus per kant (M7).
    indexes: ['CREATE UNIQUE INDEX idx_hh_beoordelingen_klus_van ON hh_beoordelingen (klus, van_gebruiker)'],
  },
  {
    name: 'hh_koppelingen',
    type: 'base',
    fields: (ids) => [
      { name: 'oudere', ...rel(ids.hh_users, { required: true }) },
      { name: 'familielid', ...rel(ids.hh_users, { required: true }) },
      { name: 'rechten', ...sel(KOPPELING_RECHTEN, { maxSelect: KOPPELING_RECHTEN.length }) },
    ],
    indexes: ['CREATE UNIQUE INDEX idx_hh_koppelingen_oudere_familielid ON hh_koppelingen (oudere, familielid)'],
  },
  {
    name: 'hh_vertrouwd',
    type: 'base',
    fields: (ids) => [
      { name: 'oudere', ...rel(ids.hh_users, { required: true }) },
      { name: 'jongere', ...rel(ids.hh_users, { required: true }) },
    ],
    indexes: ['CREATE UNIQUE INDEX idx_hh_vertrouwd_oudere_jongere ON hh_vertrouwd (oudere, jongere)'],
  },
  {
    name: 'hh_betalingen',
    type: 'base',
    fields: (ids) => [
      { name: 'klus', ...rel(ids.hh_klussen, { required: true }) },
      { name: 'betaler', ...rel(ids.hh_users) },
      centen('bedrag'),
      { name: 'methode', type: 'text', max: 40 }, // bv. "ideal"
      { name: 'psp_id', type: 'text', max: 100 }, // Mollie payment-id (M16)
      { name: 'status', ...sel(BETALING_STATUSSEN), required: true },
      { name: 'betaald_op', type: 'date' },
    ],
    indexes: [
      'CREATE INDEX idx_hh_betalingen_klus ON hh_betalingen (klus)',
      'CREATE INDEX idx_hh_betalingen_psp_id ON hh_betalingen (psp_id)',
    ],
  },
  {
    name: 'hh_vergoedingen',
    type: 'base',
    fields: (ids) => [
      { name: 'jongere', ...rel(ids.hh_users, { required: true }) },
      { name: 'periode', type: 'text', max: 20 }, // bv. "2026-09"
      centen('bedrag'),
      { name: 'status', ...sel(VERGOEDING_STATUSSEN), required: true },
    ],
    indexes: ['CREATE INDEX idx_hh_vergoedingen_jongere ON hh_vergoedingen (jongere)'],
  },
  {
    name: 'hh_incidenten',
    type: 'base',
    fields: (ids) => [
      { name: 'klus', ...rel(ids.hh_klussen) }, // mag leeg: noodknop zonder klus
      { name: 'melder', ...rel(ids.hh_users, { required: true }) },
      { name: 'soort', ...sel(INCIDENT_SOORTEN), required: true },
      { name: 'omschrijving', type: 'text', max: 2000 },
      { name: 'afhandeling', type: 'text', max: 2000 }, // alleen coordinator
    ],
    indexes: ['CREATE INDEX idx_hh_incidenten_melder ON hh_incidenten (melder)'],
  },
  {
    name: 'hh_push_tokens',
    type: 'base',
    fields: (ids) => [
      { name: 'gebruiker', ...rel(ids.hh_users, { required: true, cascadeDelete: true }) },
      { name: 'token', type: 'text', required: true, max: 500 },
      { name: 'platform', ...sel(PLATFORMS) },
    ],
    indexes: ['CREATE UNIQUE INDEX idx_hh_push_tokens_token ON hh_push_tokens (token)'],
  },
];

const LOCKED_RULES = { listRule: null, viewRule: null, createRule: null, updateRule: null, deleteRule: null };

async function getOrNull(pb, name) {
  try {
    return await pb.collections.getOne(name);
  } catch {
    return null;
  }
}

function indexLabel(sql) {
  return sql.match(/INDEX\s+(\S+)\s+ON/i)?.[1] ?? sql;
}

function describeFields(fields) {
  return fields.map((f) => `${f.name}:${f.type}${f.required ? '*' : ''}`).join(', ');
}

async function ensureCollection(pb, spec, ids) {
  assertHh(spec.name);
  const existing = await getOrNull(pb, spec.name);
  const fields = spec.fields(ids);

  if (!existing) {
    if (!APPLY) {
      console.log(`+ ZOU ${spec.name} (${spec.type}) aanmaken — dry-run`);
      console.log(`    velden: ${describeFields(fields)}, created, updated`);
      for (const idx of spec.indexes) console.log(`    index:  ${indexLabel(idx)}`);
      return null;
    }
    const created = await pb.collections.create({
      name: spec.name,
      type: spec.type,
      fields: [...fields, ...AUTODATES],
      indexes: spec.indexes,
      ...LOCKED_RULES,
    });
    console.log(`＋ aangemaakt: ${spec.name} (${created.id}) — ${created.fields.length} velden, ${created.indexes.length} indexen`);
    return created;
  }

  console.log(`✓ bestaat al: ${spec.name} (${existing.id})`);
  const wanted = [...fields, ...AUTODATES];
  const have = new Set(existing.fields.map((f) => f.name));
  const missingFields = wanted.filter((f) => !have.has(f.name));
  const haveIdx = new Set((existing.indexes ?? []).map(indexLabel));
  const missingIdx = spec.indexes.filter((i) => !haveIdx.has(indexLabel(i)));

  if (!missingFields.length && !missingIdx.length) return existing;

  if (!APPLY) {
    if (missingFields.length) console.log(`    + ZOU velden toevoegen: ${describeFields(missingFields)} — dry-run`);
    for (const idx of missingIdx) console.log(`    + ZOU index ${indexLabel(idx)} toevoegen — dry-run`);
    return existing;
  }
  const updated = await pb.collections.update(existing.id, {
    fields: [...existing.fields, ...missingFields],
    indexes: [...(existing.indexes ?? []), ...missingIdx],
  });
  if (missingFields.length) console.log(`    ↻ velden toegevoegd: ${describeFields(missingFields)}`);
  for (const idx of missingIdx) console.log(`    ↻ index ${indexLabel(idx)} toegevoegd`);
  return updated;
}

async function main() {
  const pb = await superuserClient();
  logMode();

  const ids = {
    hh_users: '<hh_users>',
    hh_wijken: '<hh_wijken>',
    hh_klustypes: '<hh_klustypes>',
    hh_klussen: '<hh_klussen>',
  };
  // Bij dry-run: gebruik echte ids als de collectie al bestaat, anders placeholders.
  for (const key of Object.keys(ids)) {
    const c = await getOrNull(pb, key);
    if (c) ids[key] = c.id;
  }

  for (const spec of SPEC) {
    const result = await ensureCollection(pb, spec, ids);
    if (result && ids[spec.name] !== undefined) ids[spec.name] = result.id;
  }

  if (!APPLY) {
    console.log('\nDry-run klaar. Niets geschreven. Draai met --apply om de hh_-collecties echt aan te maken.');
    return;
  }
  const all = await pb.collections.getFullList();
  const hh = all.filter((c) => c.name.startsWith('hh_'));
  console.log(`\nKlaar. ${hh.length} hh_-collecties op de server; totaal ${all.length} collecties.`);
}

main().catch(fail);
