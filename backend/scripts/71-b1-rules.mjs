// HeitjeHulp B1 stap 2 — API-rules voor de nieuwe B1-velden.
//
// Alleen de coordinator (of de server via een hook/$app) zet:
//   hh_users      ouder_toestemming_op, ouder_iban_ok
//   hh_profielen  id_gecontroleerd_op, id_gecontroleerd_door, vog_gezien_op
// De eigenaar mag ouder_email, ouder_telefoon en huisnummer gewoon meesturen
// bij aanmaken/bijwerken: daarvoor hoeft niets te veranderen (de bestaande
// rules laten onbekende velden door).
//
// Werkwijze zoals 61: de rule die LIVE op de server staat wordt GEWIKKELD,
// niet herschreven:
//   nieuw = "(" + huidig + ") && ((coordinator) || (veld:isset = false && ...))"
// Alles van eerdere milestones (02, 06, 13, 21, 41, 44, 45, 61) blijft
// letterlijk staan. Idempotent: staat het slot er al, dan gebeurt er niets.
// null blijft null; een lege rule ("" = publiek) wordt geweigerd. list/view/
// delete worden niet aangeraakt.
//
// VOLGORDE: na 70-b1-velden.mjs --apply. Draai 02, 06, 13, 21 of 61 daarna
// niet meer met --apply zonder 71 opnieuw te draaien.
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/71-b1-rules.mjs            (dry-run: toont oud en nieuw)
//   node scripts/71-b1-rules.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';
import { metSlot, slot } from './61-beheer-rules.mjs';

/// Welke B1-velden op welke collectie alleen de coordinator zet.
export const B1_SLOT_VELDEN = {
  hh_users: ['ouder_toestemming_op', 'ouder_iban_ok'],
  hh_profielen: ['id_gecontroleerd_op', 'id_gecontroleerd_door', 'vog_gezien_op'],
};
/// Velden die de eigenaar zelf mag meesturen (niet in het slot).
export const B1_VRIJ = {
  hh_users: ['ouder_email', 'ouder_telefoon', 'huisnummer'],
};
const SLOT_RULES = ['createRule', 'updateRule'];

export { slot };

/// Simpele woord-diff: toont alleen wat er bij komt (het deel na het oude).
function verschil(oud, nieuw) {
  if (oud && nieuw.startsWith(`(${oud}) && `)) return `(OUD) && ${nieuw.slice(oud.length + 6)}`;
  return nieuw;
}

async function wikkel(pb, naam, velden) {
  assertHh(naam);
  const col = await pb.collections.getOne(naam);
  const bestaand = new Set(col.fields.map((f) => f.name));
  const mist = velden.filter((v) => !bestaand.has(v));
  if (mist.length) {
    if (APPLY) throw new Error(`${naam}: velden ontbreken (${mist.join(', ')}) — draai eerst 70-b1-velden.mjs --apply.`);
    console.log(`! ${naam}: velden ontbreken nog (${mist.join(', ')}) — draai eerst 70 --apply; PocketBase weigert een rule op een onbekend veld.`);
  }
  const gewenst = {};
  for (const k of SLOT_RULES) {
    const huidig = col[k] ?? null;
    const nieuw = metSlot(huidig, velden);
    if (nieuw === huidig) {
      console.log(`✓ ${naam}.${k}: het B1-slot staat er al (of de rule is null)`);
      continue;
    }
    gewenst[k] = nieuw;
    console.log(`${APPLY ? '↻' : '+ ZOU'} ${naam}.${k} wikkelen${APPLY ? '' : ' — dry-run'}`);
    console.log(`  - oud:   ${JSON.stringify(huidig)}`);
    console.log(`  + nieuw: ${JSON.stringify(nieuw)}`);
    console.log(`  = erbij: ${verschil(huidig, nieuw)}`);
  }
  const aantal = Object.keys(gewenst).length;
  if (!aantal || !APPLY) return aantal;
  await pb.collections.update(col.id, gewenst);
  const na = await pb.collections.getOne(naam);
  const zonder = Object.keys(gewenst).filter((k) => !String(na[k] ?? '').includes(slot(velden)));
  if (zonder.length) throw new Error(`Na apply mist het slot nog op ${naam}: ${zonder.join(', ')}`);
  return aantal;
}

async function main() {
  const pb = await superuserClient();
  logMode();
  let totaal = 0;
  for (const [naam, velden] of Object.entries(B1_SLOT_VELDEN)) totaal += await wikkel(pb, naam, velden);
  console.log(`\nVrij voor de eigenaar (geen rule-wijziging nodig): ${Object.entries(B1_VRIJ).map(([n, v]) => `${n}: ${v.join(', ')}`).join('; ')}`);
  if (!totaal) console.log('\nNiets te doen.');
  else if (!APPLY) console.log(`\nDRY-RUN: ${totaal} regel(s) zouden veranderen. Draai met --apply.`);
  else console.log(`\n✓ ${totaal} regel(s) bijgewerkt.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
