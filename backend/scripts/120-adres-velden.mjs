// HeitjeHulp ADRES stap 1 — velden voor het strengere adres (PDOK, 4 okt 2026).
// ADDITIEF en idempotent: wat er al staat wordt overgeslagen, bestaande velden
// worden nooit gewijzigd of verwijderd. Alleen hh_users (hard-guard). Geen
// datamigratie: bestaande accounts houden hun adres zoals het is.
//
//   hh_users  + toevoeging   tekst, max 6 ("A", "2", "a-01": huisletter en
//                            huisnummertoevoeging zoals BAG)
//             + lat, lon     getal: het exacte PDOK-punt van het adres
//                            (0/leeg = onbekend). Alleen server/coordinator
//                            (de hook weigert ze van anderen).
//             + adres_bron   keuze: pdok | handmatig | ongecontroleerd
//                              pdok            bevestigd door PDOK (BAG)
//                              handmatig       uitzondering door de meldkamer
//                              ongecontroleerd PDOK was onbereikbaar
//                            leeg = van vóór deze stap. Alleen server/coordinator.
//   (adres, postcode, plaats sinds M4; huisnummer sinds B1: overgeslagen)
//
// Waarom geen rule-wijziging: de hook (hh_aanmelden.pb.js + hh_adres_hulp.js)
// weigert lat/lon/adres_bron van een niet-coordinator al (400), net als hij
// straat/plaats overschrijft. Zo hoeven de gewikkelde hh_users-rules van
// 71/80 niet opnieuw (en hoeft niemand op de volgorde van rule-scripts te letten).
//
// DRAAIEN (eerst 00-backup.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/120-adres-velden.mjs            (dry-run)
//   node scripts/120-adres-velden.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

export const AL_AANWEZIG = ['adres', 'postcode', 'plaats', 'huisnummer', 'wijk', 'werkgebied_status'];

export const ADRES_BRONNEN = ['pdok', 'handmatig', 'ongecontroleerd'];

export const ADRES_VELDEN = [
  { name: 'toevoeging', type: 'text', max: 6 },
  { name: 'lat', type: 'number' },
  { name: 'lon', type: 'number' },
  { name: 'adres_bron', type: 'select', maxSelect: 1, values: ADRES_BRONNEN },
];

export const ADRES_VELDNAMEN = ADRES_VELDEN.map((f) => f.name);

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

  for (const n of AL_AANWEZIG) {
    console.log(bestaand.has(n) ? `  ✓ bestaat al (eerdere milestone): ${naam}.${n}` : `  ! ONTBREEKT (verwacht): ${naam}.${n}`);
  }

  const ontbreekt = [];
  for (const f of ADRES_VELDEN) {
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
  console.log(`\n✓ ${ontbreekt.length} veld(en) toegevoegd. Daarna: 123-hook-deploy.sh.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
