// HeitjeHulp B4 stap 3 — API-rules voor klus plaatsen.
//
// (a) Een helper ziet een open klus pas als de meldkamer hem goedkeurde EN
//     hij oud genoeg is (besluiten punt 6, 7 en 8). hh_klussen.listRule en
//     viewRule: in de helper-tak, direct achter de B2-voorwaarde
//       (@request.auth.ouder_toestemming_op != "" || @collection.hh_profielen.vog_gezien_op ?!= "")
//     komt erbij:
//       && klus_goedgekeurd_op != "" && geboren_uiterlijk != ""
//       && @request.auth.geboortedatum != "" && @request.auth.geboortedatum <= geboren_uiterlijk
//     Een rule kan geen leeftijd uitrekenen. Daarom zet de hook op elke klus
//     geboren_uiterlijk = de (Nederlandse) klusdag min min_leeftijd jaar; de
//     rule vergelijkt alleen twee datums. min_leeftijd = de categorie, of 18
//     als de tijden buiten 07:00-19:00 / 2 uur vallen. Zelfde regel in de
//     accepteer-route (reden "leeftijd") en voor de melding "nieuwe klus".
//     Eigen (toegewezen) klussen en die van de bewoner zelf: andere takken,
//     blijven zichtbaar; de bewoner ziet zijn klus dus ook ongekeurd.
// (b) Alleen de coordinator (of de server) zet de keur-velden en de velden
//     die de hook uitrekent. hh_klussen.createRule en updateRule, GEWIKKELD:
//       (huidig) && ((coordinator) || (keur- en rekenvelden niet in de body))
//
// Werkwijze zoals 61/71/80: de LIVE rule blijft letterlijk staan, (a) GERICHT
// aangevuld, (b) gewikkeld. Idempotent. Staat het anker van (a) er niet
// precies één keer, dan stopt het script (prod wijkt af van git).
//
// VOLGORDE: na 100 --apply (de velden) en 103 (de hook die ze vult). Draai
// 02, 06, 13, 41 of 80 daarna niet meer met --apply zonder 101 opnieuw.
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/101-b4-rules.mjs            (dry-run: toont oud en nieuw)
//   node scripts/101-b4-rules.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';
import { COORD } from './61-beheer-rules.mjs';
import { KLUS_VOORWAARDE, metExtra } from './80-b2-rules.mjs';
import { B4_VELDNAMEN } from './100-b4-velden.mjs';

/// Het anker: de B2-voorwaarde in de helper-tak (staat op prod sinds 3 okt).
export const B4_ANKER = KLUS_VOORWAARDE;
export const B4_HELPER_VOORWAARDE =
  'klus_goedgekeurd_op != "" && geboren_uiterlijk != "" && ' +
  '@request.auth.geboortedatum != "" && @request.auth.geboortedatum <= geboren_uiterlijk';

/// Velden die alleen de coordinator of de server zet.
export const SERVER_VELDEN = [
  'klus_goedgekeurd_op',
  'klus_goedgekeurd_door',
  'klus_afgekeurd_op',
  'klus_afkeur_reden',
  'controle_markering',
  'min_leeftijd',
  'geboren_uiterlijk',
];
export const KEUR_SLOT = `((${COORD}) || (${SERVER_VELDEN.map((v) => `@request.body.${v}:isset = false`).join(' && ')}))`;

/// Zet [B4_HELPER_VOORWAARDE] direct achter het anker. Idempotent.
export function metB4Voorwaarde(huidig) {
  if (huidig === null || huidig === undefined) return null;
  const regel = String(huidig);
  const aangevuld = `${B4_ANKER} && ${B4_HELPER_VOORWAARDE}`;
  if (regel.includes(aangevuld)) return regel;
  const aantal = regel.split(B4_ANKER).length - 1;
  if (aantal !== 1) {
    throw new Error(`Anker "${B4_ANKER}" staat ${aantal}x in de rule (verwacht 1; staat B2 op de server?) — niets veranderd.`);
  }
  return regel.replace(B4_ANKER, aangevuld);
}

export const B4_WIJZIGINGEN = [
  { collectie: 'hh_klussen', rule: 'listRule', nieuw: (r) => metB4Voorwaarde(r) },
  { collectie: 'hh_klussen', rule: 'viewRule', nieuw: (r) => metB4Voorwaarde(r) },
  { collectie: 'hh_klussen', rule: 'createRule', nieuw: (r) => metExtra(r, KEUR_SLOT) },
  { collectie: 'hh_klussen', rule: 'updateRule', nieuw: (r) => metExtra(r, KEUR_SLOT) },
];

async function main() {
  const pb = await superuserClient();
  logMode();

  const klussen = await pb.collections.getOne(assertHh('hh_klussen'));
  const mist = B4_VELDNAMEN.hh_klussen.filter((v) => !klussen.fields.some((f) => f.name === v));
  if (mist.length) {
    const melding = `hh_klussen: velden ontbreken (${mist.join(', ')}) — eerst 100-b4-velden.mjs --apply.`;
    if (APPLY) throw new Error(melding);
    console.log(`! ${melding} (dry-run gaat door)`);
  }

  const nieuw = {};
  let totaal = 0;
  for (const w of B4_WIJZIGINGEN) {
    const huidig = klussen[w.rule] ?? null;
    const gewenst = w.nieuw(huidig);
    if (gewenst === huidig) {
      console.log(`✓ ${w.collectie}.${w.rule}: de B4-aanvulling staat er al (of de rule is null)`);
      continue;
    }
    totaal++;
    nieuw[w.rule] = gewenst;
    console.log(`${APPLY ? '↻' : '+ ZOU'} ${w.collectie}.${w.rule} aanvullen${APPLY ? '' : ' — dry-run'}`);
    console.log(`  - oud:   ${JSON.stringify(huidig)}`);
    console.log(`  + nieuw: ${JSON.stringify(gewenst)}`);
  }

  if (!totaal) {
    console.log('\nNiets te doen.');
    return;
  }
  if (!APPLY) {
    console.log(`\nDRY-RUN: ${totaal} rule(s) zouden veranderen. Draai met --apply.`);
    return;
  }
  await pb.collections.update(klussen.id, nieuw);
  const na = await pb.collections.getOne('hh_klussen');
  for (const [rule, gewenst] of Object.entries(nieuw)) {
    if (na[rule] !== gewenst) throw new Error(`Na apply klopt hh_klussen.${rule} niet`);
  }
  console.log(`\n✓ ${totaal} rule(s) bijgewerkt.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
