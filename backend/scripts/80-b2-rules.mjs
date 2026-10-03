// HeitjeHulp B2 stap 1 — API-rules voor aanmelden zonder screening.
//
// (a) B1-gat 1: na goedkeuring kan de helper GEEN nieuwe ID-foto meer
//     uploaden. hh_profielen.updateRule krijgt erbij:
//       ((coordinator) || (verificatiestatus != "goedgekeurd" ||
//                          @request.body.document_foto:isset = false))
//     verificatiestatus is hier de waarde OP DE SERVER (vóór het verzoek).
// (b) Een helper ziet geen open klussen zolang hij niet klaar is.
//     hh_klussen.listRule en viewRule: in de helper-tak (open klussen in de
//     wijk, goedgekeurd) komt erbij:
//       && (@request.auth.ouder_toestemming_op != "" ||
//           @collection.hh_profielen.vog_gezien_op ?!= "")
//     Een rule kan niet rekenen met datums (geen "nu min 18 jaar"); daarom
//     filtert de LIJST op "ouder gaf toestemming OF VOG gezien" en doet de
//     accepteer-hook (hh_klussen.pb.js + hh_aanmelden_hulp.js) de precieze
//     check op leeftijd: onder 18 ouder-toestemming, vanaf 18 VOG. Beide
//     velden zet alleen de coordinator/server (slot uit 71). De eigen
//     (toegewezen) klussen blijven zichtbaar: dat is een andere tak.
//     De @collection.hh_profielen-join is dezelfde als die van
//     "gebruiker ?= auth.id && verificatiestatus ?= goedgekeurd" ernaast:
//     één join, dus hetzelfde profiel (bewezen in 82).
// (c) De leeftijd telt: alleen de coordinator wijzigt geboortedatum na het
//     aanmaken (hh_users.updateRule). Registreren (createRule) blijft vrij.
// (d) Werkgebied (besluit 3 okt): wijk en werkgebied_status zet alleen de
//     server (hh_aanmelden.pb.js, uit de postcode) of de coordinator, bij
//     aanmaken en bijwerken (hh_users.createRule/updateRule).
// (e) De wijk-vergelijking in de helper-tak van hh_klussen.listRule/viewRule
//     wordt ruimer: zelfde wijk OF dezelfde gemeente als een van de twee een
//     regio-wijk is ("Tiel en omstreken", 81):
//       hulpvrager.wijk = @request.auth.wijk
//     wordt
//       (hulpvrager.wijk = @request.auth.wijk || (hulpvrager.wijk.gemeente =
//        @request.auth.wijk.gemeente && (hulpvrager.wijk.regio = true ||
//        @request.auth.wijk.regio = true)))
//     Tiel-West en Passewaaij blijven elk apart (oud gedrag, 04 en 50 blijven
//     kloppen); nieuwe aanmeldingen (regio) passen bij beide. Geen
//     datamigratie. De accepteer-hook doet hetzelfde (wijkenPassen).
//
// Werkwijze zoals 61/71: de LIVE rule wordt GEWIKKELD (a, c) of GERICHT
// aangevuld (b, zoals 41), nooit herschreven. Idempotent. null blijft null;
// een lege rule ("" = publiek) wordt geweigerd. Staat het anker van (b) er
// niet precies één keer, dan stopt het script (prod wijkt af van git).
//
// VOLGORDE: na B1 (70/71, staat op prod) en na 81-b2-werkgebied.mjs --apply. Draai 02, 06, 13, 21, 61 of 71
// daarna niet meer met --apply zonder 80 opnieuw.
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/80-b2-rules.mjs            (dry-run: toont oud en nieuw)
//   node scripts/80-b2-rules.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';
import { COORD } from './61-beheer-rules.mjs';

export const ID_SLOT = `((${COORD}) || (verificatiestatus != "goedgekeurd" || @request.body.document_foto:isset = false))`;
export const GEBOORTEDATUM_SLOT = `((${COORD}) || (@request.body.geboortedatum:isset = false))`;

export const WERKGEBIED_SLOT = `((${COORD}) || (@request.body.wijk:isset = false && @request.body.werkgebied_status:isset = false))`;

export const WIJK_ANKER = 'hulpvrager.wijk = @request.auth.wijk';
export const WIJK_RUIM =
  '(hulpvrager.wijk = @request.auth.wijk || (hulpvrager.wijk.gemeente = @request.auth.wijk.gemeente && ' +
  '(hulpvrager.wijk.regio = true || @request.auth.wijk.regio = true)))';

export const KLUS_ANKER = '@collection.hh_profielen.verificatiestatus ?= "goedgekeurd"';
export const KLUS_VOORWAARDE =
  '(@request.auth.ouder_toestemming_op != "" || @collection.hh_profielen.vog_gezien_op ?!= "")';

/// Wikkelt [huidig] met [extra]: "(huidig) && extra". Idempotent.
export function metExtra(huidig, extra) {
  if (huidig === null || huidig === undefined) return null;
  if (String(huidig).includes(extra)) return huidig;
  if (String(huidig).trim() === '') {
    throw new Error('Lege rule ("" = publiek) — geweigerd, dit script wikkelt alleen bestaande rules.');
  }
  return `(${huidig}) && ${extra}`;
}

/// Zet [KLUS_VOORWAARDE] direct achter het anker in de helper-tak.
export function metKlusVoorwaarde(huidig) {
  if (huidig === null || huidig === undefined) return null;
  const regel = String(huidig);
  const aangevuld = `${KLUS_ANKER} && ${KLUS_VOORWAARDE}`;
  if (regel.includes(aangevuld)) return regel;
  const aantal = regel.split(KLUS_ANKER).length - 1;
  if (aantal !== 1) {
    throw new Error(`Anker "${KLUS_ANKER}" staat ${aantal}x in de rule (verwacht 1) — prod wijkt af, niets veranderd.`);
  }
  return regel.replace(KLUS_ANKER, aangevuld);
}

/// Vervangt [WIJK_ANKER] precies één keer door [WIJK_RUIM]. Idempotent.
export function metRuimeWijk(huidig) {
  if (huidig === null || huidig === undefined) return null;
  const regel = String(huidig);
  if (regel.includes(WIJK_RUIM)) return regel;
  const aantal = regel.split(WIJK_ANKER).length - 1;
  if (aantal !== 1) {
    throw new Error(`Anker "${WIJK_ANKER}" staat ${aantal}x in de rule (verwacht 1) — prod wijkt af, niets veranderd.`);
  }
  return regel.replace(WIJK_ANKER, WIJK_RUIM);
}

/// Wat 80 per collectie en rule doet.
export const B2_WIJZIGINGEN = [
  { collectie: 'hh_profielen', rule: 'updateRule', nieuw: (r) => metExtra(r, ID_SLOT), velden: ['document_foto', 'verificatiestatus'] },
  { collectie: 'hh_klussen', rule: 'listRule', nieuw: (r) => metRuimeWijk(metKlusVoorwaarde(r)), velden: [] },
  { collectie: 'hh_klussen', rule: 'viewRule', nieuw: (r) => metRuimeWijk(metKlusVoorwaarde(r)), velden: [] },
  { collectie: 'hh_users', rule: 'createRule', nieuw: (r) => metExtra(r, WERKGEBIED_SLOT), velden: [] },
  {
    collectie: 'hh_users',
    rule: 'updateRule',
    nieuw: (r) => metExtra(metExtra(r, GEBOORTEDATUM_SLOT), WERKGEBIED_SLOT),
    velden: [],
  },
];

/// Velden waar de nieuwe rules op leunen (PocketBase weigert een rule op een
/// onbekend veld).
const NODIG = {
  hh_profielen: ['document_foto', 'verificatiestatus', 'vog_gezien_op'],
  hh_users: ['geboortedatum', 'ouder_toestemming_op', 'wijk', 'werkgebied_status'],
  hh_wijken: ['gemeente', 'regio'],
};

async function main() {
  const pb = await superuserClient();
  logMode();

  for (const [naam, velden] of Object.entries(NODIG)) {
    const col = await pb.collections.getOne(assertHh(naam));
    const mist = velden.filter((v) => !col.fields.some((f) => f.name === v));
    if (mist.length) {
      const melding = `${naam}: velden ontbreken (${mist.join(', ')}) — eerst B1 (70) en 81-b2-werkgebied.mjs --apply.`;
      if (APPLY) throw new Error(melding);
      console.log(`! ${melding} (dry-run gaat door)`);
    }
  }

  let totaal = 0;
  const perCollectie = {};
  for (const w of B2_WIJZIGINGEN) {
    assertHh(w.collectie);
    const col = await pb.collections.getOne(w.collectie);
    const huidig = col[w.rule] ?? null;
    const nieuw = w.nieuw(huidig);
    if (nieuw === huidig) {
      console.log(`✓ ${w.collectie}.${w.rule}: de B2-aanvulling staat er al (of de rule is null)`);
      continue;
    }
    totaal++;
    (perCollectie[w.collectie] ??= { id: col.id, rules: {} }).rules[w.rule] = nieuw;
    console.log(`${APPLY ? '↻' : '+ ZOU'} ${w.collectie}.${w.rule} aanvullen${APPLY ? '' : ' — dry-run'}`);
    console.log(`  - oud:   ${JSON.stringify(huidig)}`);
    console.log(`  + nieuw: ${JSON.stringify(nieuw)}`);
  }

  if (!totaal) {
    console.log('\nNiets te doen.');
    return;
  }
  if (!APPLY) {
    console.log(`\nDRY-RUN: ${totaal} rule(s) zouden veranderen. Draai met --apply.`);
    return;
  }
  for (const [naam, { id, rules }] of Object.entries(perCollectie)) {
    await pb.collections.update(id, rules);
    const na = await pb.collections.getOne(naam);
    for (const [rule, gewenst] of Object.entries(rules)) {
      if (na[rule] !== gewenst) throw new Error(`Na apply klopt ${naam}.${rule} niet`);
    }
  }
  console.log(`\n✓ ${totaal} rule(s) bijgewerkt.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
