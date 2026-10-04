// HeitjeHulp B11 stap 1 — meldkamer: nieuwe collectie hh_partners, additieve
// velden op hh_users (kennismaking + partner) en de vier B11-instellingen in
// hh_instellingen (alleen als ze er nog niet zijn; een bestaande waarde
// blijft staan). Idempotent en additief; bestaande velden en rijen worden
// nooit gewijzigd. GEEN datamigratie: bestaande bewoners op "gesproken"
// zetten doet script 154 (apart, eigen JA). Hard-guard op hh_.
//
// hh_partners  (jongerenwerk-organisaties, besluit 4 okt: ALLEEN TELLEN)
//   naam     tekst, verplicht, 2-80
//   code     tekst, verplicht, ^[A-Z0-9-]{3,20}$, UNIEK
//   actief   ja/nee (niet actief = code werkt niet meer bij aanmelden)
//   notitie  tekst, max 500
//   Rules blijven hier null (alleen superuser); 151 zet ze.
//
// EXTRA VELDEN hh_users
//   kennismaking_status   nog | gesproken | geweigerd
//   kennismaking_op       datum
//   kennismaking_door     relatie hh_users (geen cascade)
//   kennismaking_notitie  tekst, max 500
//   partner               relatie hh_partners (geen cascade, niet verplicht)
//
// INSTELLINGEN (hh_instellingen, alleen nieuwe sleutels)
//   b11_kennismaking_verplicht false, b11_zelfde_paar_aan false,
//   b11_zelfde_paar_aantal 4, b11_zelfde_paar_dagen 30
//
// DRAAIEN (eerst 00-backup.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/150-b11-velden.mjs            (dry-run)
//   node scripts/150-b11-velden.mjs --apply

import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

const hier = path.dirname(fileURLToPath(import.meta.url));

/// De hook-hulp zoals de JSVM hem laadt (module.exports): één bron voor de
/// keuzes en startwaarden.
function laadHookHulp(naam) {
  const bron = readFileSync(path.join(hier, '..', 'pb_hooks', naam), 'utf8');
  const m = { exports: {} };
  new Function('module', 'exports', 'require', bron)(m, m.exports, () => ({}));
  return m.exports;
}
export const HULP = laadHookHulp('hh_meldkamer_hulp.js');

export const PARTNERS = 'hh_partners';

const AUTODATES = [
  { name: 'created', type: 'autodate', onCreate: true, onUpdate: false },
  { name: 'updated', type: 'autodate', onCreate: true, onUpdate: true },
];

export function partnerVelden() {
  return [
    { name: 'naam', type: 'text', required: true, min: 2, max: 80 },
    { name: 'code', type: 'text', required: true, min: 3, max: 20, pattern: '^[A-Z0-9-]{3,20}$' },
    { name: 'actief', type: 'bool' },
    { name: 'notitie', type: 'text', max: 500 },
    ...AUTODATES,
  ];
}

export const NIEUWE_COLLECTIES = [
  { naam: PARTNERS, velden: partnerVelden, indexen: [`CREATE UNIQUE INDEX idx_hh_partners_code ON ${PARTNERS} (code)`] },
];

export function userVelden(ids) {
  return [
    { name: 'kennismaking_status', type: 'select', values: HULP.KENNISMAKING_STATUSSEN, maxSelect: 1 },
    { name: 'kennismaking_op', type: 'date' },
    { name: 'kennismaking_door', type: 'relation', collectionId: ids.hh_users, maxSelect: 1, required: false, cascadeDelete: false },
    { name: 'kennismaking_notitie', type: 'text', max: HULP.NOTITIE_MAX },
    { name: 'partner', type: 'relation', collectionId: ids.hh_partners, maxSelect: 1, required: false, cascadeDelete: false },
  ];
}

function omschrijf(f) {
  if (f.type === 'select') return `select: ${f.values.join(' | ')}`;
  if (f.type === 'relation') return `relation${f.cascadeDelete ? ', cascade' : ''}`;
  return f.max ? `${f.type}, max ${f.max}` : f.type;
}

async function collectie(pb, def) {
  assertHh(def.naam);
  let bestaand = null;
  try {
    bestaand = await pb.collections.getOne(def.naam);
  } catch (_) {
    bestaand = null;
  }
  const gewenst = def.velden();
  if (bestaand) {
    const aanwezig = new Set(bestaand.fields.map((f) => f.name));
    const mist = gewenst.filter((f) => !aanwezig.has(f.name)).map((f) => f.name);
    console.log(`  ✓ ${def.naam} staat er al${mist.length ? ` — LET OP: mist ${mist.join(', ')} (niet aangepast)` : ''}`);
    return 0;
  }
  console.log(`  ${APPLY ? '＋ maak aan' : '+ ZOU aanmaken'}: ${def.naam} (base, ${gewenst.length} velden)`);
  for (const f of gewenst) console.log(`      ${f.name} (${omschrijf(f)})`);
  for (const idx of def.indexen) console.log(`      index: ${idx}`);
  if (!APPLY) return 1;
  await pb.collections.create({
    name: def.naam,
    type: 'base',
    fields: gewenst,
    indexes: def.indexen,
    // Dicht tot 151-b11-rules.mjs draait.
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
  });
  console.log(`  ✓ ${def.naam} aangemaakt.`);
  return 1;
}

async function velden(pb) {
  assertHh('hh_users');
  const col = await pb.collections.getOne('hh_users');
  let partnersId = 'hh_partners-ontbreekt';
  try {
    partnersId = (await pb.collections.getOne(PARTNERS)).id;
  } catch (_) {
    if (APPLY) throw new Error(`${PARTNERS} ontbreekt na het aanmaken.`);
  }
  const bestaand = new Map(col.fields.map((f) => [f.name, f]));
  const ontbreekt = [];
  for (const f of userVelden({ hh_users: col.id, hh_partners: partnersId })) {
    const er = bestaand.get(f.name);
    if (er) {
      console.log(`  ✓ bestaat al: hh_users.${f.name} (${er.type})${er.type === f.type ? '' : ` — LET OP: verwacht ${f.type}, niet aangepast`}`);
      continue;
    }
    ontbreekt.push(f);
    console.log(`  ${APPLY ? '＋ voeg toe' : '+ ZOU toevoegen'}: hh_users.${f.name} (${omschrijf(f)})`);
  }
  if (!ontbreekt.length || !APPLY) return ontbreekt.length;
  await pb.collections.update(col.id, { fields: [...col.fields, ...ontbreekt] });
  const na = new Set((await pb.collections.getOne('hh_users')).fields.map((f) => f.name));
  const mist = ontbreekt.filter((f) => !na.has(f.name)).map((f) => f.name);
  if (mist.length) throw new Error(`Na apply ontbreken nog op hh_users: ${mist.join(', ')}`);
  console.log(`  ✓ hh_users: ${ontbreekt.length} veld(en) toegevoegd`);
  return ontbreekt.length;
}

async function instellingen(pb) {
  assertHh('hh_instellingen');
  let n = 0;
  for (const { sleutel, waarde } of HULP.STANDAARD_INSTELLINGEN) {
    const er = await pb.collection('hh_instellingen').getList(1, 1, { filter: pb.filter('sleutel = {:s}', { s: sleutel }) });
    if (er.items.length) {
      console.log(`  ✓ instelling ${sleutel} bestaat al (${JSON.stringify(er.items[0].waarde)}), blijft staan`);
      continue;
    }
    n++;
    console.log(`  ${APPLY ? '＋ instelling' : '+ ZOU instelling'}: ${sleutel} = ${JSON.stringify(waarde)}`);
    if (APPLY) await pb.collection('hh_instellingen').create({ sleutel, waarde });
  }
  return n;
}

async function main() {
  const pb = await superuserClient();
  logMode();
  let n = 0;
  for (const def of NIEUWE_COLLECTIES) n += await collectie(pb, def);
  n += await velden(pb);
  n += await instellingen(pb);
  if (!n) console.log('\nNiets te doen: hh_partners, de hh_users-velden en de B11-instellingen staan er al.');
  else if (!APPLY) console.log(`\nDRY-RUN: ${n} wijziging(en). Draai met --apply.`);
  else console.log('\nKlaar. Rules: 151-b11-rules.mjs.');
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
