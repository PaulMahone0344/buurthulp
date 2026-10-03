// HeitjeHulp B4 stap 4 — de SEED-klussen ("[seed kNN]") goedkeuren en hun
// leeftijdsgrens zetten. Zonder dit zien de seed-helpers na 101 geen open
// klus meer en worden 04-rulecheck en 50-koppelcheck rood.
//
// Alleen klussen met "[seed k" in de omschrijving (testdata uit 03-seed).
// Per klus, alleen als het nog leeg is:
//   klus_goedgekeurd_op = nu (door: leeg = de server)
//   min_leeftijd / geboren_uiterlijk zoals de hook ze uitrekent
// Andere klussen (echte of test-klussen van vóór B4) worden NIET aangeraakt:
// die staan in het beheerpaneel bij "Klussen na te kijken" en de meldkamer
// beslist. De dry-run somt ze op.
//
// VOLGORDE: na 100 --apply, 103 en 101 --apply. Idempotent.
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/104-b4-seed-keuren.mjs            (dry-run)
//   node scripts/104-b4-seed-keuren.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';
import { plaatsHulp } from './100-b4-velden.mjs';

export const SEED_MERK = '[seed k';

/// Wat er op één klus moet veranderen (puur, voor de test). {} = niets.
export function seedPlan(klus, typeMinLeeftijd, nu = new Date()) {
  const plan = {};
  if (!String(klus.omschrijving ?? '').includes(SEED_MERK)) return plan;
  if (!String(klus.klus_goedgekeurd_op ?? '').trim()) plan.klus_goedgekeurd_op = nu.toISOString();
  const min = plaatsHulp.minLeeftijdVoorKlus({ typeMinLeeftijd, van: klus.wanneer_van, tot: klus.wanneer_tot });
  const grens = plaatsHulp.geborenUiterlijk(klus.wanneer_van || nu.toISOString(), min);
  if (klus.min_leeftijd !== min) plan.min_leeftijd = min;
  if (String(klus.geboren_uiterlijk ?? '') !== grens) plan.geboren_uiterlijk = grens;
  return plan;
}

async function main() {
  const pb = await superuserClient();
  logMode();
  const klussenCol = await pb.collections.getOne(assertHh('hh_klussen'));
  if (!klussenCol.fields.some((f) => f.name === 'geboren_uiterlijk')) {
    const melding = 'hh_klussen.geboren_uiterlijk ontbreekt — eerst 100-b4-velden.mjs --apply.';
    if (APPLY) throw new Error(melding);
    console.log(`! ${melding} (dry-run gaat door)`);
  }
  const types = new Map((await pb.collection('hh_klustypes').getFullList()).map((t) => [t.id, t]));
  const klussen = await pb.collection('hh_klussen').getFullList({ sort: 'created' });

  let teDoen = 0;
  const overig = [];
  for (const k of klussen) {
    if (!String(k.omschrijving ?? '').includes(SEED_MERK)) {
      if (k.status === 'open' && !k.klus_goedgekeurd_op) overig.push(k);
      continue;
    }
    const type = types.get(k.klustype);
    // Vóór 100 --apply heeft het type nog geen min_leeftijd: dan zoals 100 hem zet.
    const typeMin = type?.min_leeftijd ?? plaatsHulp.OUDE_KLUSTYPES_MIN_LEEFTIJD[type?.naam];
    const plan = seedPlan(k, typeMin);
    const velden = Object.keys(plan);
    const merk = String(k.omschrijving).match(/\[seed k\d+\]/)?.[0] ?? k.id;
    if (!velden.length) {
      console.log(`  ✓ ${merk} staat al goed`);
      continue;
    }
    teDoen++;
    console.log(`  ${APPLY ? '↻' : '~ ZOU'} ${merk} (${k.status}, ${type?.naam ?? 'geen type'}): ${velden.map((v) => `${v} = ${plan[v]}`).join(', ')}`);
    if (APPLY) await pb.collection(assertHh('hh_klussen')).update(k.id, plan);
  }
  for (const k of overig) {
    console.log(`  · NIET aangeraakt (open, ongekeurd; de meldkamer beslist): ${k.id} ${JSON.stringify(String(k.omschrijving).slice(0, 50))}`);
  }
  if (!teDoen) console.log('\nNiets te doen.');
  else if (!APPLY) console.log(`\nDRY-RUN: ${teDoen} seed-klus(sen) zouden goedgekeurd/bijgewerkt worden. Draai met --apply.`);
  else console.log(`\n✓ ${teDoen} seed-klus(sen) bijgewerkt.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
