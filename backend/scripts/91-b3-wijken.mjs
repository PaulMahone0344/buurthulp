// HeitjeHulp B3 stap 2 — Tiel-West en Passewaaij worden ook regio-wijk
// (besluit Ibrahim 3 okt, OPEN-PUNTEN-B2: "zodat iedereen in Tiel alle
// klussen ziet"). Zet ALLEEN hh_wijken.regio = ja op die twee rijen (veld uit
// 81). Geen rij erbij of eraf, geen gebruiker of klus aangeraakt.
//
// Gevolg (lijst-rule 80 en accepteren via wijkenPassen): een regio-wijk past
// bij elke wijk in dezelfde gemeente. Met alle drie de Tiel-wijken op regio
// ziet een helper in Tiel-West dus ook de klussen in Passewaaij en omgekeerd.
// Alleen de seed-/testaccounts staan nog in die twee wijken (nieuwe
// aanmeldingen krijgen "Tiel en omstreken").
//
// CHECKS DIE HIERDOOR VERANDEREN (aangepast in B3, zie SCHEMA.txt):
//   04-rulecheck  "jongere 1 ziet Passewaaij niet" e.d. -> leest nu of de
//                 wijken regio zijn en verwacht dan het nieuwe gedrag
//   82-b2check    "oud gedrag: Tiel-West ziet Passewaaij niet" -> idem
//   50-koppelcheck blijft groen: andere_wijk kijkt naar het wijk-id
//
// DRAAIEN (eerst 00-backup.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/91-b3-wijken.mjs              (dry-run)
//   node scripts/91-b3-wijken.mjs --apply
//   node scripts/91-b3-wijken.mjs --terug --apply   (regio weer uit op de twee)

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

export const GEMEENTE = 'Tiel';
export const WIJKEN = ['Tiel-West', 'Passewaaij'];
const TERUG = process.argv.includes('--terug');

/// Welke rijen moeten veranderen om [doel] (true = regio) te bereiken.
/// Alleen de genoemde wijken in de gemeente; ontbreekt er een, dan meldt
/// [ontbreekt] dat (dan wijkt prod af en stopt het script).
export function teWijzigen(rijen, doel = true) {
  const gevonden = WIJKEN.map((naam) => rijen.find((r) => r.gemeente === GEMEENTE && r.wijk === naam) || null);
  return {
    ontbreekt: WIJKEN.filter((_, i) => !gevonden[i]),
    wijzig: gevonden.filter((r) => r && (r.regio === true) !== doel),
  };
}

async function main() {
  const pb = await superuserClient();
  logMode();
  const col = await pb.collections.getOne(assertHh('hh_wijken'));
  if (!col.fields.some((f) => f.name === 'regio')) throw new Error('hh_wijken.regio ontbreekt — eerst 81-b2-werkgebied.mjs --apply (B2).');

  const rijen = await pb.collection('hh_wijken').getFullList({ filter: pb.filter('gemeente = {:g}', { g: GEMEENTE }) });
  const doel = !TERUG;
  const { ontbreekt, wijzig } = teWijzigen(rijen, doel);
  if (ontbreekt.length) throw new Error(`Wijk(en) niet gevonden: ${ontbreekt.join(', ')} — prod wijkt af, niets veranderd.`);
  for (const r of rijen) {
    const komt = wijzig.includes(r);
    console.log(`  ${komt ? (APPLY ? '↻' : '+ ZOU') : '✓'} ${r.gemeente} / ${r.wijk}: regio ${r.regio === true ? 'ja' : 'nee'}${komt ? ` -> ${doel ? 'ja' : 'nee'}` : ''}`);
  }
  if (!wijzig.length) {
    console.log('\nNiets te doen.');
    return;
  }
  if (!APPLY) {
    console.log(`\nDRY-RUN: ${wijzig.length} wijk(en) zouden regio = ${doel ? 'ja' : 'nee'} krijgen. Draai met --apply.`);
    return;
  }
  for (const r of wijzig) {
    await pb.collection(assertHh('hh_wijken')).update(r.id, { regio: doel });
    const na = await pb.collection('hh_wijken').getOne(r.id);
    if ((na.regio === true) !== doel) throw new Error(`Na apply klopt ${r.wijk} niet`);
  }
  console.log(`\n✓ ${wijzig.length} wijk(en) bijgewerkt.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
