// HeitjeHulp B9 stap 1 — XP, badges, niveaus en verdiensten: drie nieuwe
// collecties (hh_xp, hh_badges, hh_verklaringen), additieve velden op
// hh_profielen en hh_beoordelingen, en de soort "beloning" op
// hh_meldingen.soort. Idempotent en additief: bestaat iets al, dan wordt
// alleen wat ontbreekt bijgemaakt; bestaande velden en keuzewaarden worden
// nooit gewijzigd of verwijderd. GEEN datamigratie: XP voor al afgeronde
// klussen boekt pas script 144 (apart, met dry-run). Hard-guard op hh_.
//
// API-rules van de nieuwe collecties blijven hier op null (= alleen
// superuser). Die, plus de sloten op de nieuwe velden, zet 141-b9-rules.mjs.
//
// hh_xp  (elke boeking één rij, nooit wissen; zie pb_hooks/hh_xp_hulp.js)
//   helper       relatie hh_users, verplicht; verdwijnt mee met het account
//   klus         relatie hh_klussen, optioneel, GEEN cascade (klus weg =
//                veld leeg, de punten blijven herleidbaar via bron)
//   beoordeling  relatie hh_beoordelingen, optioneel, geen cascade
//   bron         tekst: "klaar:<klus>" | "herboeking:<klus>" | "eerste" |
//                "beoordeling:<id>"
//   soort        klus_klaar | eerste_klus | herboeking | beoordeling |
//                tegenboeking
//   punten       geheel getal (negatief bij een tegenboeking; NIET verplicht,
//                want PocketBase weigert 0 bij een verplicht getal)
//   sleutel      bron + "#" + volgnummer
//   UNIEK (helper, sleutel): twee hooks tegelijk boeken nooit dubbel
// hh_badges  (prestatie-badges; de vertrouwensbadges rekent de hook uit)
//   helper (cascade), code (zie hh_xp_regels.BADGES), behaald_op
//   UNIEK (helper, code)
// hh_verklaringen  ("Verklaring van inzet", punt 19)
//   helper (cascade), code "XXXXX-XXXXX" UNIEK, gegevens (json snapshot)
//
// EXTRA VELDEN (additief)
//   hh_profielen.xp_totaal            getal (de hook schrijft; slot in 141)
//   hh_profielen.niveau               nieuw | ervaren | top | geverifieerd
//   hh_profielen.idin_geverifieerd_op datum (iDIN bestaat nog niet; nooit
//                                     automatisch, alleen superuser)
//   hh_beoordelingen.verborgen_op     datum: de meldkamer verborg de recensie
//   hh_beoordelingen.verborgen_door   relatie hh_users (geen cascade)
//   hh_beoordelingen.verborgen_reden  tekst, max 300
//   hh_meldingen.soort + "beloning"
//
// DRAAIEN (eerst 00-backup.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/140-b9-xp.mjs            (dry-run)
//   node scripts/140-b9-xp.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';
import { metKeuze } from './130-b5-reacties.mjs';

export const XP = 'hh_xp';
export const BADGES = 'hh_badges';
export const VERKLARINGEN = 'hh_verklaringen';
export const XP_SOORTEN = ['klus_klaar', 'eerste_klus', 'herboeking', 'beoordeling', 'tegenboeking'];
export const BADGE_CODES = ['eerste_klus', 'vijf_klussen', 'tien_klussen', 'vijfentwintig_klussen', 'vijf_sterren_reeks', 'herboekt', 'drie_buren'];
export const NIVEAU_CODES = ['nieuw', 'ervaren', 'top', 'geverifieerd'];
export const MELDING_SOORT_BELONING = 'beloning';

const AUTODATES = [
  { name: 'created', type: 'autodate', onCreate: true, onUpdate: false },
  { name: 'updated', type: 'autodate', onCreate: true, onUpdate: true },
];

export function xpVelden(ids) {
  return [
    { name: 'helper', type: 'relation', collectionId: ids.hh_users, maxSelect: 1, required: true, cascadeDelete: true },
    { name: 'klus', type: 'relation', collectionId: ids.hh_klussen, maxSelect: 1, required: false, cascadeDelete: false },
    { name: 'beoordeling', type: 'relation', collectionId: ids.hh_beoordelingen, maxSelect: 1, required: false, cascadeDelete: false },
    { name: 'bron', type: 'text', required: true, min: 1, max: 80 },
    { name: 'soort', type: 'select', values: XP_SOORTEN, maxSelect: 1, required: true },
    { name: 'punten', type: 'number', onlyInt: true, required: false },
    { name: 'sleutel', type: 'text', required: true, min: 1, max: 100 },
    ...AUTODATES,
  ];
}

export function badgeVelden(ids) {
  return [
    { name: 'helper', type: 'relation', collectionId: ids.hh_users, maxSelect: 1, required: true, cascadeDelete: true },
    { name: 'code', type: 'select', values: BADGE_CODES, maxSelect: 1, required: true },
    { name: 'behaald_op', type: 'date' },
    ...AUTODATES,
  ];
}

export function verklaringVelden(ids) {
  return [
    { name: 'helper', type: 'relation', collectionId: ids.hh_users, maxSelect: 1, required: true, cascadeDelete: true },
    { name: 'code', type: 'text', required: true, min: 11, max: 11, pattern: '^[A-Z2-9]{5}-[A-Z2-9]{5}$' },
    { name: 'gegevens', type: 'json', maxSize: 20000 },
    ...AUTODATES,
  ];
}

export const NIEUWE_COLLECTIES = [
  {
    naam: XP,
    velden: xpVelden,
    indexen: [`CREATE UNIQUE INDEX idx_hh_xp_sleutel ON ${XP} (helper, sleutel)`, `CREATE INDEX idx_hh_xp_helper ON ${XP} (helper)`],
  },
  {
    naam: BADGES,
    velden: badgeVelden,
    indexen: [`CREATE UNIQUE INDEX idx_hh_badges_uniek ON ${BADGES} (helper, code)`],
  },
  {
    naam: VERKLARINGEN,
    velden: verklaringVelden,
    indexen: [`CREATE UNIQUE INDEX idx_hh_verklaringen_code ON ${VERKLARINGEN} (code)`, `CREATE INDEX idx_hh_verklaringen_helper ON ${VERKLARINGEN} (helper)`],
  },
];

export function extraVelden(ids) {
  return {
    hh_profielen: [
      { name: 'xp_totaal', type: 'number', onlyInt: true },
      { name: 'niveau', type: 'select', values: NIVEAU_CODES, maxSelect: 1 },
      { name: 'idin_geverifieerd_op', type: 'date' },
    ],
    hh_beoordelingen: [
      { name: 'verborgen_op', type: 'date' },
      { name: 'verborgen_door', type: 'relation', collectionId: ids.hh_users, maxSelect: 1, required: false, cascadeDelete: false },
      { name: 'verborgen_reden', type: 'text', max: 300 },
    ],
  };
}

function omschrijf(f) {
  if (f.type === 'select') return `select: ${f.values.join(' | ')}`;
  if (f.type === 'relation') return `relation${f.cascadeDelete ? ', cascade' : ''}`;
  return f.max ? `${f.type}, max ${f.max}` : f.type;
}

async function haalIds(pb) {
  const ids = {};
  for (const naam of ['hh_users', 'hh_klussen', 'hh_beoordelingen']) {
    assertHh(naam);
    ids[naam] = (await pb.collections.getOne(naam)).id;
  }
  return ids;
}

const norm = (s) => s.replace(/[`"]/g, '').replace(/\s+/g, ' ').trim();

async function collectie(pb, def, ids) {
  assertHh(def.naam);
  const gewenst = def.velden(ids);
  let bestaand = null;
  try {
    bestaand = await pb.collections.getOne(def.naam);
  } catch (_) {
    bestaand = null;
  }
  if (!bestaand) {
    console.log(`  ${APPLY ? '＋ maak aan' : '+ ZOU aanmaken'}: ${def.naam} (base, ${gewenst.length} velden)`);
    for (const f of gewenst) console.log(`      ${f.name} (${omschrijf(f)})`);
    for (const idx of def.indexen) console.log(`      index: ${idx}`);
    if (!APPLY) return 1;
    await pb.collections.create({
      name: def.naam,
      type: 'base',
      fields: gewenst,
      indexes: def.indexen,
      // Dicht tot 141-b9-rules.mjs draait.
      listRule: null,
      viewRule: null,
      createRule: null,
      updateRule: null,
      deleteRule: null,
    });
    const na = await pb.collections.getOne(def.naam);
    console.log(`  ✓ ${def.naam} aangemaakt met ${na.fields.length} velden en ${na.indexes.length} index(en).`);
    return 1;
  }
  const aanwezig = new Set(bestaand.fields.map((f) => f.name));
  const ontbreekt = gewenst.filter((f) => !aanwezig.has(f.name));
  for (const f of ontbreekt) console.log(`  ${APPLY ? '＋ voeg toe' : '+ ZOU toevoegen'}: ${def.naam}.${f.name} (${omschrijf(f)})`);
  const huidig = bestaand.indexes || [];
  const nieuweIdx = def.indexen.filter((idx) => !huidig.some((h) => norm(h) === norm(idx)));
  for (const idx of nieuweIdx) console.log(`  ${APPLY ? '＋ index' : '+ ZOU index'}: ${idx}`);
  if (!ontbreekt.length && !nieuweIdx.length) {
    console.log(`  ✓ ${def.naam} staat er al`);
    return 0;
  }
  if (!APPLY) return ontbreekt.length + nieuweIdx.length;
  await pb.collections.update(bestaand.id, { fields: [...bestaand.fields, ...ontbreekt], indexes: [...huidig, ...nieuweIdx] });
  console.log(`  ✓ ${def.naam} bijgewerkt.`);
  return ontbreekt.length + nieuweIdx.length;
}

async function velden(pb, ids) {
  let aantal = 0;
  for (const [naam, lijst] of Object.entries(extraVelden(ids))) {
    assertHh(naam);
    const col = await pb.collections.getOne(naam);
    const bestaand = new Map(col.fields.map((f) => [f.name, f]));
    const ontbreekt = [];
    for (const f of lijst) {
      const er = bestaand.get(f.name);
      if (er) {
        console.log(`  ✓ bestaat al: ${naam}.${f.name} (${er.type})${er.type === f.type ? '' : ` — LET OP: verwacht ${f.type}, niet aangepast`}`);
        continue;
      }
      ontbreekt.push(f);
      console.log(`  ${APPLY ? '＋ voeg toe' : '+ ZOU toevoegen'}: ${naam}.${f.name} (${omschrijf(f)})`);
    }
    if (!ontbreekt.length) continue;
    aantal += ontbreekt.length;
    if (!APPLY) continue;
    await pb.collections.update(col.id, { fields: [...col.fields, ...ontbreekt] });
    const na = new Set((await pb.collections.getOne(naam)).fields.map((f) => f.name));
    const mist = ontbreekt.filter((f) => !na.has(f.name)).map((f) => f.name);
    if (mist.length) throw new Error(`Na apply ontbreken nog op ${naam}: ${mist.join(', ')}`);
    console.log(`  ✓ ${naam}: ${ontbreekt.length} veld(en) toegevoegd`);
  }
  return aantal;
}

async function meldingSoort(pb) {
  const naam = 'hh_meldingen';
  assertHh(naam);
  const col = await pb.collections.getOne(naam);
  const veld = col.fields.find((f) => f.name === 'soort');
  if (!veld) throw new Error(`${naam}.soort bestaat niet.`);
  const nieuw = metKeuze(veld.values, MELDING_SOORT_BELONING);
  if (nieuw.length === veld.values.length) {
    console.log(`  ✓ ${naam}.soort kent "${MELDING_SOORT_BELONING}" al`);
    return 0;
  }
  console.log(`  ${APPLY ? '＋ keuze' : '+ ZOU keuze toevoegen'}: ${naam}.soort "${MELDING_SOORT_BELONING}"`);
  console.log(`      was:    ${veld.values.join(' | ')}`);
  console.log(`      wordt:  ${nieuw.join(' | ')}`);
  if (!APPLY) return 1;
  const lijst = col.fields.map((f) => (f.name === 'soort' ? { ...f, values: nieuw } : f));
  await pb.collections.update(col.id, { fields: lijst });
  const na = (await pb.collections.getOne(naam)).fields.find((f) => f.name === 'soort');
  if (!na.values.includes(MELDING_SOORT_BELONING)) throw new Error('Na apply ontbreekt "beloning" nog.');
  console.log(`  ✓ ${naam}.soort: ${na.values.join(' | ')}`);
  return 1;
}

async function main() {
  const pb = await superuserClient();
  logMode();
  const ids = await haalIds(pb);
  let n = 0;
  for (const def of NIEUWE_COLLECTIES) n += await collectie(pb, def, ids);
  n += await velden(pb, ids);
  n += await meldingSoort(pb);
  if (!n) console.log('\nNiets te doen: hh_xp, hh_badges, hh_verklaringen, de extra velden en de meldingsoort staan er al.');
  else if (!APPLY) console.log(`\nDRY-RUN: ${n} wijziging(en). Draai met --apply.`);
  else console.log('\nKlaar. Rules: 141-b9-rules.mjs.');
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
