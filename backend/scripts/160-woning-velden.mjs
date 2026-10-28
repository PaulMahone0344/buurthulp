// HeitjeHulp feedbackronde 1 punt F — de woning van de bewoner op Mijn
// gegevens (28 okt 2026). ADDITIEF en idempotent: wat er al staat wordt
// overgeslagen, bestaande velden worden nooit gewijzigd of verwijderd. Alleen
// hh_users (hard-guard). Geen datamigratie: leeg = niet ingevuld.
//
//   hh_users  + woning_type     keuze: huis | appartement | anders
//             + verdieping      tekst, max 10 (de app stuurt alleen cijfers)
//             + lift            keuze: ja | nee
//             + trap            keuze: ja | nee
//             + bereikbaarheid  tekst, max 300 ("bel aan bij de achterdeur")
//
// Waarom geen rule- of hook-wijziging: de eigenaar mag zichzelf al bijwerken
// en de hook (hh_aanmelden.pb.js) kijkt alleen naar adres en geboortedatum.
// Wie de rij mag zien, ziet ook de woning, net als het adres: een strijder
// dus alleen van een bewoner op wie hij is toegewezen.
//
// DRAAIEN (eerst 00-backup.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/160-woning-velden.mjs            (dry-run)
//   node scripts/160-woning-velden.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

export const WONING_TYPES = ['huis', 'appartement', 'anders'];
export const JA_NEE = ['ja', 'nee'];

export const WONING_VELDEN = [
  { name: 'woning_type', type: 'select', maxSelect: 1, values: WONING_TYPES },
  { name: 'verdieping', type: 'text', max: 10 },
  { name: 'lift', type: 'select', maxSelect: 1, values: JA_NEE },
  { name: 'trap', type: 'select', maxSelect: 1, values: JA_NEE },
  { name: 'bereikbaarheid', type: 'text', max: 300 },
];

export const WONING_VELDNAMEN = WONING_VELDEN.map((f) => f.name);

function omschrijf(f) {
  if (f.type === 'select') return `select: ${f.values.join(' | ')}`;
  return f.max ? `${f.type}, max ${f.max}` : f.type;
}

async function main() {
  const pb = await superuserClient();
  logMode();
  const naam = assertHh('hh_users');
  const col = await pb.collections.getOne(naam);
  const bestaand = new Map(col.fields.map((f) => [f.name, f]));

  const ontbreekt = [];
  for (const f of WONING_VELDEN) {
    const er = bestaand.get(f.name);
    if (er) {
      const zelfde = er.type === f.type;
      console.log(`  ✓ bestaat al: ${naam}.${f.name} (${er.type})${zelfde ? '' : ` — LET OP: verwacht ${f.type}, niet aangepast`}`);
      continue;
    }
    ontbreekt.push(f);
    console.log(`  ${APPLY ? '＋ voeg toe' : '+ ZOU toevoegen'}: ${naam}.${f.name} (${omschrijf(f)})`);
  }

  if (!ontbreekt.length) {
    console.log('\nNiets te doen: alles staat er al.');
    return;
  }
  if (!APPLY) {
    console.log(`\nDRY-RUN: ${ontbreekt.length} veld(en) zouden worden toegevoegd. Draai met --apply.`);
    return;
  }
  await pb.collections.update(col.id, { fields: [...col.fields, ...ontbreekt] });
  const na = await pb.collections.getOne(naam);
  const naNamen = new Set(na.fields.map((f) => f.name));
  const mist = ontbreekt.filter((f) => !naNamen.has(f.name)).map((f) => f.name);
  if (mist.length) throw new Error(`Na apply ontbreken nog op ${naam}: ${mist.join(', ')}`);
  console.log(`\n✓ ${ontbreekt.length} veld(en) toegevoegd. Geen hook-deploy nodig.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
