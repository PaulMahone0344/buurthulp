// HeitjeHulp M8 stap 1 — maakt de collectie hh_meldingen aan (laag 1: melding
// IN de app). Idempotent: bestaat de collectie al, dan worden alleen
// ontbrekende velden en indexen bijgemaakt; bestaande velden worden nooit
// gewijzigd of verwijderd. Raakt geen enkele andere collectie aan
// (hard-guard op hh_).
//
// API-rules blijven hier op null (= alleen superuser). Die komen in
// 31-meldingen-rules.mjs.
//
// VELDEN (PROMPT-M8, keuze 2) plus één veld dat de prompt niet noemt:
//   sleutel — de idempotentiesleutel. De prompt eist "(ontvanger + soort +
//   klus + logregel) nooit dubbel", maar noemt geen veld waarin de logregel
//   past. Zonder zo'n veld is die eis niet af te dwingen. De hook zet er
//   "klusstatus:<id van de hh_klus_status-regel>" of "incident:<id>" in.
//   Dat staat ook in OPEN-PUNTEN-M8 en in SCHEMA.txt.
//
// INDEXEN
//   idx_hh_meldingen_ontvanger        — de lijst per gebruiker (de prompt).
//   idx_hh_meldingen_uniek (UNIQUE)   — (ontvanger, soort, sleutel). De hook
//   controleert zelf al op dubbel; deze index is de harde tweede sluis voor
//   het geval twee wissels tegelijk binnenkomen. Een botsing gooit BINNEN de
//   try/catch van de trigger en kan een statuswissel dus nooit breken.
//
// DRAAIEN (eerst 00-backup.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/30-meldingen-collectie.mjs            (dry-run)
//   node scripts/30-meldingen-collectie.mjs --apply    (echt aanmaken)

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

export const COLLECTIE = 'hh_meldingen';

/// De zes soorten uit PROMPT-M8. nieuwe_klus gaat naar de jongeren in de
/// wijk; de andere vijf naar een deelnemer of een coordinator.
export const MELDING_SOORTEN = [
  'nieuwe_klus',
  'toegewezen',
  'onderweg',
  'afgerond',
  'geannuleerd',
  'incident',
];

const AUTODATES = [
  { name: 'created', type: 'autodate', onCreate: true, onUpdate: false },
  { name: 'updated', type: 'autodate', onCreate: true, onUpdate: true },
];

/// De velden, in dezelfde volgorde als PROMPT-M8 ze noemt.
export function meldingVelden(ids) {
  return [
    {
      name: 'ontvanger',
      type: 'relation',
      collectionId: ids.hh_users,
      maxSelect: 1,
      required: true,
      // "verdwijnt mee": wordt de gebruiker verwijderd, dan zijn meldingen ook weg.
      cascadeDelete: true,
    },
    { name: 'soort', type: 'select', values: MELDING_SOORTEN, maxSelect: 1, required: true },
    { name: 'klus', type: 'relation', collectionId: ids.hh_klussen, maxSelect: 1, cascadeDelete: false },
    { name: 'incident', type: 'relation', collectionId: ids.hh_incidenten, maxSelect: 1, cascadeDelete: false },
    { name: 'titel', type: 'text', max: 200 },
    { name: 'tekst', type: 'text', max: 600 },
    // De idempotentiesleutel; zie de kop van dit bestand.
    { name: 'sleutel', type: 'text', max: 200 },
    { name: 'gelezen_op', type: 'date' },
    ...AUTODATES,
  ];
}

export const MELDING_INDEXEN = [
  `CREATE INDEX idx_hh_meldingen_ontvanger ON ${COLLECTIE} (ontvanger)`,
  `CREATE UNIQUE INDEX idx_hh_meldingen_uniek ON ${COLLECTIE} (ontvanger, soort, sleutel)`,
];

/// De id's van de collecties waar hh_meldingen naar verwijst. Bij dry-run
/// zonder bestaande collectie geeft dit een duidelijke fout in plaats van
/// een onbruikbare placeholder.
async function haalIds(pb) {
  const ids = {};
  for (const naam of ['hh_users', 'hh_klussen', 'hh_incidenten']) {
    assertHh(naam);
    const col = await pb.collections.getOne(naam);
    ids[naam] = col.id;
  }
  return ids;
}

async function main() {
  assertHh(COLLECTIE);
  const pb = await superuserClient();
  logMode();

  const ids = await haalIds(pb);
  const gewenst = meldingVelden(ids);

  let bestaand = null;
  try {
    bestaand = await pb.collections.getOne(COLLECTIE);
  } catch (_) {
    bestaand = null;
  }

  if (!bestaand) {
    console.log(`  ${APPLY ? '＋ maak aan' : '+ ZOU aanmaken'}: ${COLLECTIE} (base, ${gewenst.length} velden)`);
    for (const f of gewenst) console.log(`      ${f.name} (${f.type})`);
    for (const idx of MELDING_INDEXEN) console.log(`      index: ${idx}`);
    if (!APPLY) {
      console.log('\nDRY-RUN: de collectie zou worden aangemaakt. Draai met --apply.');
      return;
    }
    await pb.collections.create({
      name: COLLECTIE,
      type: 'base',
      fields: gewenst,
      indexes: MELDING_INDEXEN,
      // Rules blijven dicht tot 31-meldingen-rules.mjs draait.
      listRule: null,
      viewRule: null,
      createRule: null,
      updateRule: null,
      deleteRule: null,
    });
    const na = await pb.collections.getOne(COLLECTIE);
    console.log(`\n✓ ${COLLECTIE} aangemaakt met ${na.fields.length} velden en ${na.indexes.length} index(en).`);
    return;
  }

  // Bestaat al: alleen aanvullen.
  const aanwezig = new Set(bestaand.fields.map((f) => f.name));
  const ontbreekt = gewenst.filter((f) => !aanwezig.has(f.name));
  for (const f of gewenst) {
    if (aanwezig.has(f.name)) console.log(`  ✓ bestaat al: ${COLLECTIE}.${f.name}`);
    else console.log(`  ${APPLY ? '＋ voeg toe' : '+ ZOU toevoegen'}: ${COLLECTIE}.${f.name} (${f.type})`);
  }

  const huidigeIndexen = bestaand.indexes || [];
  const nieuweIndexen = MELDING_INDEXEN.filter(
    (idx) => !huidigeIndexen.some((h) => h.replace(/\s+/g, ' ') === idx.replace(/\s+/g, ' ')),
  );
  for (const idx of nieuweIndexen) console.log(`  ${APPLY ? '＋ index' : '+ ZOU index'}: ${idx}`);

  if (!ontbreekt.length && !nieuweIndexen.length) {
    console.log('\nNiets te doen: collectie, velden en indexen staan er al.');
    return;
  }
  if (!APPLY) {
    console.log(`\nDRY-RUN: ${ontbreekt.length} veld(en) en ${nieuweIndexen.length} index(en) zouden erbij komen.`);
    return;
  }

  await pb.collections.update(bestaand.id, {
    fields: [...bestaand.fields, ...ontbreekt],
    indexes: [...huidigeIndexen, ...nieuweIndexen],
  });
  const na = await pb.collections.getOne(COLLECTIE);
  const naNamen = new Set(na.fields.map((f) => f.name));
  const mist = gewenst.filter((f) => !naNamen.has(f.name)).map((f) => f.name);
  if (mist.length) throw new Error(`Na apply ontbreken nog: ${mist.join(', ')}`);
  console.log(`\n✓ ${COLLECTIE} bijgewerkt: ${na.fields.length} velden, ${na.indexes.length} index(en).`);
}

// Alleen draaien als dit script zelf wordt gestart (32 importeert de constanten).
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
