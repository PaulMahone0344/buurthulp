// HeitjeHulp M16 stap 1 — voegt ADDITIEF één tekstveld toe aan hh_betalingen:
// vergoeding_periode (max 7, "JJJJ-MM"). Daarin staat in welke maandperiode
// van hh_vergoedingen de vergoeding van deze betaling geboekt is, zodat
// GET /api/hh/vergoedingen/mijn per klus de uitbetaalstatus kan tonen zonder
// dat de jongere hh_betalingen zelf mag lezen (M16, keuze 4).
//
// Niets anders wordt aangeraakt: geen bestaand veld, geen index, geen
// API-rule. De rules van hh_betalingen en hh_vergoedingen blijven zoals ze
// zijn (de hook schrijft via $app en loopt niet langs de rules); dit script
// LEEST ze alleen en meldt het als ze afwijken van backend/SCHEMA.txt.
//
// Idempotent: een veld dat al bestaat wordt overgeslagen; bestaande velden
// worden nooit gewijzigd of verwijderd. Alleen op hh_betalingen (hard-guard).
//
// DRAAIEN (eerst 00-backup.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/70-betaal-velden.mjs            (dry-run: print wat er ZOU gebeuren)
//   node scripts/70-betaal-velden.mjs --apply    (echt toevoegen)

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

const COLLECTIE = 'hh_betalingen';

/// "2026-09" is 7 tekens; langer hoeft nooit.
export const PERIODE_MAX = 7;

export const BETAAL_VELDEN = [
  { name: 'vergoeding_periode', type: 'text', max: PERIODE_MAX },
];

/// Alleen om te LEZEN en te melden: zo horen de regels te staan volgens
/// backend/SCHEMA.txt. Dit script schrijft nooit een regel.
const VERWACHTE_RULES = {
  hh_betalingen: 'alleen coordinator mag aanmaken/bijwerken/verwijderen',
  hh_vergoedingen: 'alleen coordinator mag aanmaken/bijwerken/verwijderen; de jongere leest zijn eigen rijen',
};

const RULE_KEYS = ['listRule', 'viewRule', 'createRule', 'updateRule', 'deleteRule'];

async function toonRules(pb, naam) {
  const col = await pb.collections.getOne(naam);
  console.log(`\n${naam} — regels zoals ze NU op de server staan:`);
  console.log(`  (verwacht: ${VERWACHTE_RULES[naam]})`);
  for (const k of RULE_KEYS) {
    console.log(`    ${k}: ${JSON.stringify(col[k] ?? null)}`);
  }
  return col;
}

async function main() {
  assertHh(COLLECTIE);
  const pb = await superuserClient();
  logMode();

  const col = await pb.collections.getOne(COLLECTIE);
  const bestaand = new Set(col.fields.map((f) => f.name));
  const ontbreekt = BETAAL_VELDEN.filter((f) => !bestaand.has(f.name));

  for (const f of BETAAL_VELDEN) {
    if (bestaand.has(f.name)) console.log(`  ✓ bestaat al: ${COLLECTIE}.${f.name}`);
    else console.log(`  ${APPLY ? '＋ voeg toe' : '+ ZOU toevoegen'}: ${COLLECTIE}.${f.name} (text, max ${f.max})`);
  }

  // Alleen lezen: de hoofdsessie ziet zo of de rules nog kloppen.
  await toonRules(pb, 'hh_betalingen');
  await toonRules(pb, 'hh_vergoedingen');

  if (!ontbreekt.length) {
    console.log('\nNiets te doen: het veld staat al op hh_betalingen.');
    return;
  }
  if (!APPLY) {
    console.log(`\nDRY-RUN: ${ontbreekt.length} veld(en) zouden worden toegevoegd. Draai met --apply.`);
    return;
  }

  // Bestaande velden ongewijzigd meesturen; alleen de ontbrekende erbij.
  await pb.collections.update(col.id, { fields: [...col.fields, ...ontbreekt] });

  const na = await pb.collections.getOne(COLLECTIE);
  const naNamen = new Set(na.fields.map((f) => f.name));
  const mist = BETAAL_VELDEN.filter((f) => !naNamen.has(f.name)).map((f) => f.name);
  if (mist.length) throw new Error(`Na apply ontbreken nog: ${mist.join(', ')}`);
  console.log(`\n✓ ${ontbreekt.length} veld(en) toegevoegd; ${COLLECTIE} heeft nu ${na.fields.length} velden.`);
}

// Alleen draaien als dit script zelf wordt gestart (72 importeert de velden).
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
