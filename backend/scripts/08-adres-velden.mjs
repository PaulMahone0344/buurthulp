// HeitjeHulp M4 stap 1 — voegt ADDITIEF vijf tekstvelden toe aan hh_users:
// adres, postcode, plaats, contact_naam, contact_telefoon. Niets anders wordt
// aangeraakt: geen bestaand veld, geen index, geen API-rule (de eigenaar mag
// zichzelf al bijwerken zonder rol mee te sturen, zie 02-rules.mjs).
//
// Idempotent: een veld dat al bestaat wordt overgeslagen; bestaande velden
// worden nooit gewijzigd of verwijderd. Alleen op hh_users (hard-guard).
//
// DRAAIEN (eerst 00-backup.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/08-adres-velden.mjs            (dry-run: print wat er ZOU gebeuren)
//   node scripts/08-adres-velden.mjs --apply    (echt toevoegen)

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

const COLLECTIE = 'hh_users';

// Precies de vijf velden uit PROMPT-M4 deel A.
export const ADRES_VELDEN = [
  { name: 'adres', type: 'text', max: 200 }, // straat + huisnummer
  { name: 'postcode', type: 'text', max: 7 }, // "4003 AB"
  { name: 'plaats', type: 'text', max: 100 },
  { name: 'contact_naam', type: 'text', max: 100 }, // contactpersoon (O12)
  { name: 'contact_telefoon', type: 'text', max: 20 },
];

async function main() {
  assertHh(COLLECTIE);
  const pb = await superuserClient();
  logMode();

  const col = await pb.collections.getOne(COLLECTIE);
  const bestaand = new Set(col.fields.map((f) => f.name));
  const ontbreekt = ADRES_VELDEN.filter((f) => !bestaand.has(f.name));

  for (const f of ADRES_VELDEN) {
    if (bestaand.has(f.name)) console.log(`  ✓ bestaat al: ${COLLECTIE}.${f.name}`);
    else console.log(`  ${APPLY ? '＋ voeg toe' : '+ ZOU toevoegen'}: ${COLLECTIE}.${f.name} (text, max ${f.max})`);
  }

  if (!ontbreekt.length) {
    console.log('\nNiets te doen: alle vijf velden staan al op hh_users.');
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
  const mist = ADRES_VELDEN.filter((f) => !naNamen.has(f.name)).map((f) => f.name);
  if (mist.length) throw new Error(`Na apply ontbreken nog: ${mist.join(', ')}`);
  console.log(`\n✓ ${ontbreekt.length} veld(en) toegevoegd; hh_users heeft nu ${na.fields.length} velden.`);
}

// Alleen draaien als dit script zelf wordt gestart (09 importeert ADRES_VELDEN).
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
