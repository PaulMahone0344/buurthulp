// HeitjeHulp B6 stap 1 — de chat: nieuwe collectie hh_berichten, en de soort
// "bericht" erbij op hh_meldingen.soort. Idempotent en additief: bestaat de
// collectie al, dan worden alleen ontbrekende velden en indexen bijgemaakt;
// bestaande velden en keuzewaarden worden nooit gewijzigd of verwijderd.
// Raakt alleen hh_berichten en hh_meldingen aan (hard-guard op hh_).
//
// API-rules van hh_berichten blijven hier op null (= alleen superuser). Die
// komen in 111-b6-rules.mjs.
//
// VELDEN hh_berichten (PROMPT-B6, plus drie die de prompt impliciet vraagt):
//   klus            relatie hh_klussen, verplicht; verdwijnt mee met de klus
//   afzender        relatie hh_users, verplicht; GEEN cascade (zoals
//                   hh_klussen.hulpvrager: berichten blijven als bewijs)
//   helper          relatie hh_users: de helper van DIT gesprek. De hook zet
//                   hem bij aanmaken op klus.toegewezen_jongere. Zo leest een
//                   nieuwe helper (na teruggeven) het gesprek van de vorige
//                   niet mee. Niemand stuurt hem zelf mee (rule 111).
//   tekst           tekst, verplicht, max 500 (na het filter van de hook)
//   soort           keuze: tekst | snel (snelknop; nooit een statuswissel)
//   gelezen_op      datum (leeg = ongelezen); alleen de ontvanger zet hem
//   gefilterd       ja/nee: de hook verving een nummer, mailadres of link
//                   door "•••" (markering voor de meldkamer)
//   contactverzoek  ja/nee: "heb je whatsapp/snap/insta, je nummer?"
//                   (alleen gemarkeerd, niet geblokkeerd; alleen de
//                   coordinator ziet dit veld, zie hh_chat.pb.js)
//   created/updated automatisch
//
// INDEXEN
//   idx_hh_berichten_klus    (klus, created)  — het gesprek per klus
//   idx_hh_berichten_helper  (helper)         — de rule op de helper
//
// hh_meldingen.soort + "bericht": de melding "Nieuw bericht van ..." die de
// hook bij een nieuw bericht maakt. De live keuzelijst wordt gelezen en
// alleen aangevuld (een andere milestone kan er intussen iets bij hebben
// gezet; dat blijft staan).
//
// DRAAIEN (eerst 00-backup.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/110-b6-berichten.mjs            (dry-run)
//   node scripts/110-b6-berichten.mjs --apply    (echt aanmaken)

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

export const COLLECTIE = 'hh_berichten';
export const MELDINGEN = 'hh_meldingen';
export const MELDING_SOORT_BERICHT = 'bericht';
export const BERICHT_SOORTEN = ['tekst', 'snel'];
export const MAX_TEKST = 500;

const AUTODATES = [
  { name: 'created', type: 'autodate', onCreate: true, onUpdate: false },
  { name: 'updated', type: 'autodate', onCreate: true, onUpdate: true },
];

export function berichtVelden(ids) {
  return [
    { name: 'klus', type: 'relation', collectionId: ids.hh_klussen, maxSelect: 1, required: true, cascadeDelete: true },
    { name: 'afzender', type: 'relation', collectionId: ids.hh_users, maxSelect: 1, required: true, cascadeDelete: false },
    { name: 'helper', type: 'relation', collectionId: ids.hh_users, maxSelect: 1, required: false, cascadeDelete: false },
    { name: 'tekst', type: 'text', required: true, min: 1, max: MAX_TEKST },
    { name: 'soort', type: 'select', values: BERICHT_SOORTEN, maxSelect: 1, required: true },
    { name: 'gelezen_op', type: 'date' },
    { name: 'gefilterd', type: 'bool' },
    { name: 'contactverzoek', type: 'bool' },
    ...AUTODATES,
  ];
}

export const BERICHT_INDEXEN = [
  `CREATE INDEX idx_hh_berichten_klus ON ${COLLECTIE} (klus, created)`,
  `CREATE INDEX idx_hh_berichten_helper ON ${COLLECTIE} (helper)`,
];

/// De live keuzelijst van hh_meldingen.soort, aangevuld met "bericht".
/// Niets wordt weggehaald of herschikt.
export function metSoortBericht(live) {
  const lijst = Array.isArray(live) ? [...live] : [];
  return lijst.includes(MELDING_SOORT_BERICHT) ? lijst : [...lijst, MELDING_SOORT_BERICHT];
}

async function haalIds(pb) {
  const ids = {};
  for (const naam of ['hh_users', 'hh_klussen']) {
    assertHh(naam);
    ids[naam] = (await pb.collections.getOne(naam)).id;
  }
  return ids;
}

async function berichten(pb) {
  assertHh(COLLECTIE);
  const gewenst = berichtVelden(await haalIds(pb));
  let bestaand = null;
  try {
    bestaand = await pb.collections.getOne(COLLECTIE);
  } catch (_) {
    bestaand = null;
  }

  if (!bestaand) {
    console.log(`  ${APPLY ? '＋ maak aan' : '+ ZOU aanmaken'}: ${COLLECTIE} (base, ${gewenst.length} velden)`);
    for (const f of gewenst) console.log(`      ${f.name} (${f.type}${f.values ? ': ' + f.values.join(' | ') : ''})`);
    for (const idx of BERICHT_INDEXEN) console.log(`      index: ${idx}`);
    if (!APPLY) return 1;
    await pb.collections.create({
      name: COLLECTIE,
      type: 'base',
      fields: gewenst,
      indexes: BERICHT_INDEXEN,
      // Dicht tot 111-b6-rules.mjs draait.
      listRule: null,
      viewRule: null,
      createRule: null,
      updateRule: null,
      deleteRule: null,
    });
    const na = await pb.collections.getOne(COLLECTIE);
    console.log(`  ✓ ${COLLECTIE} aangemaakt met ${na.fields.length} velden en ${na.indexes.length} index(en).`);
    return 1;
  }

  const aanwezig = new Set(bestaand.fields.map((f) => f.name));
  const ontbreekt = gewenst.filter((f) => !aanwezig.has(f.name));
  for (const f of gewenst) {
    if (aanwezig.has(f.name)) console.log(`  ✓ bestaat al: ${COLLECTIE}.${f.name}`);
    else console.log(`  ${APPLY ? '＋ voeg toe' : '+ ZOU toevoegen'}: ${COLLECTIE}.${f.name} (${f.type})`);
  }
  const huidig = bestaand.indexes || [];
  const nieuweIdx = BERICHT_INDEXEN.filter((idx) => !huidig.some((h) => h.replace(/\s+/g, ' ') === idx));
  for (const idx of nieuweIdx) console.log(`  ${APPLY ? '＋ index' : '+ ZOU index'}: ${idx}`);
  if (!ontbreekt.length && !nieuweIdx.length) return 0;
  if (!APPLY) return ontbreekt.length + nieuweIdx.length;
  await pb.collections.update(bestaand.id, {
    fields: [...bestaand.fields, ...ontbreekt],
    indexes: [...huidig, ...nieuweIdx],
  });
  console.log(`  ✓ ${COLLECTIE} bijgewerkt.`);
  return ontbreekt.length + nieuweIdx.length;
}

async function meldingSoort(pb) {
  assertHh(MELDINGEN);
  const col = await pb.collections.getOne(MELDINGEN);
  const veld = col.fields.find((f) => f.name === 'soort');
  if (!veld) throw new Error(`${MELDINGEN}.soort bestaat niet — eerst M8 (30-meldingen-collectie.mjs).`);
  const nieuw = metSoortBericht(veld.values);
  if (nieuw.length === veld.values.length) {
    console.log(`  ✓ ${MELDINGEN}.soort kent "${MELDING_SOORT_BERICHT}" al`);
    return 0;
  }
  console.log(`  ${APPLY ? '＋ keuze' : '+ ZOU keuze toevoegen'}: ${MELDINGEN}.soort "${MELDING_SOORT_BERICHT}"`);
  console.log(`      was:    ${veld.values.join(' | ')}`);
  console.log(`      wordt:  ${nieuw.join(' | ')}`);
  if (!APPLY) return 1;
  // Alleen de keuzelijst van dit ene veld; alle andere velden letterlijk terug.
  const velden = col.fields.map((f) => (f.name === 'soort' ? { ...f, values: nieuw } : f));
  await pb.collections.update(col.id, { fields: velden });
  const na = (await pb.collections.getOne(MELDINGEN)).fields.find((f) => f.name === 'soort');
  if (!na.values.includes(MELDING_SOORT_BERICHT)) throw new Error('Na apply ontbreekt "bericht" nog.');
  console.log(`  ✓ ${MELDINGEN}.soort: ${na.values.join(' | ')}`);
  return 1;
}

async function main() {
  const pb = await superuserClient();
  logMode();
  const a = await berichten(pb);
  const b = await meldingSoort(pb);
  if (!a && !b) console.log('\nNiets te doen: hh_berichten en de meldingsoort staan er al.');
  else if (!APPLY) console.log(`\nDRY-RUN: ${a + b} wijziging(en). Draai met --apply.`);
  else console.log('\nKlaar. Rules van hh_berichten: 111-b6-rules.mjs.');
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
