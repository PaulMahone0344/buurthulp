// HeitjeHulp M6 stap 2 — zet de achterdeur dicht in de API-rules. Bouwt op
// RULESET_M3 uit 06-screening-rules.mjs (dat bestand blijft ongewijzigd) en
// overschrijft alleen hh_klussen.updateRule en hh_klus_status.createRule.
//
// 1. hh_klussen.updateRule: de twee jongere-takken verdwijnen.
//    - "jongere accepteert" (toegewezen_jongere op zichzelf zetten): weg.
//      Accepteren gaat sinds M5 via POST /api/hh/klussen/{id}/accepteren; die
//      route serialiseert in een transactie, de rule-tak deed dat niet
//      (backend OPEN-PUNT 18, app M5:65).
//    - "jongere voert uit" (zelf de status wijzigen): weg. De statusmachine
//      loopt sinds M6 via POST /api/hh/klussen/{id}/status en
//      /annuleren.
//    Wat blijft: de oudere en het gekoppelde familielid mogen hun eigen klus
//    bijwerken (adres, omschrijving, tijd), en de coordinator mag alles. De
//    hook weigert daarbinnen elke statuswissel behalve concept -> open, en
//    elke wijziging van toegewezen_jongere.
//
// 2. hh_klus_status.createRule: alleen nog de coordinator. De logregels
//    schrijft de hook via $app (die loopt niet langs de rules); de app
//    schrijft er geen meer (app OPEN-PUNT M4:32, M5:66, backend 16).
//
// LET OP de volgorde: 02 -> 05 -> 06 -> 13. Draai 02-rules.mjs of
// 06-screening-rules.mjs NIET opnieuw met --apply na 13; dat zet deze twee
// regels terug naar M1/M3.
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/13-status-rules.mjs            (dry-run: toont het verschil)
//   node scripts/13-status-rules.mjs --apply

import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';
import { RULESET_M3 } from './06-screening-rules.mjs';

// Dezelfde bouwstenen als 02/06 (daar niet geëxporteerd; letterlijk gelijk).
const AUTH = '@request.auth.id != "" && @request.auth.collectionName = "hh_users"';
const COORD = '@request.auth.rol = "coordinator"';
const FAMILIE_VAN = (veld) =>
  `(@request.auth.rol = "familie" && @collection.hh_koppelingen.oudere ?= ${veld} && @collection.hh_koppelingen.familielid ?= @request.auth.id)`;

// Alleen de eigenaarstak blijft over; de jongere raakt hh_klussen niet meer
// via een record-update aan.
const KLUSSEN_UPDATE =
  `${AUTH} && (` +
  `((hulpvrager = @request.auth.id || ${FAMILIE_VAN('hulpvrager')}) && @request.body.hulpvrager:isset = false && @request.body.geplaatst_door:isset = false) || ` +
  `${COORD})`;

export const RULESET_M6 = {
  ...RULESET_M3,
  hh_klussen: {
    ...RULESET_M3.hh_klussen,
    updateRule: KLUSSEN_UPDATE,
  },
  hh_klus_status: {
    ...RULESET_M3.hh_klus_status,
    createRule: `${AUTH} && ${COORD}`,
  },
};

const RULE_KEYS = ['listRule', 'viewRule', 'createRule', 'updateRule', 'deleteRule'];

async function applyRules(pb, name, desired) {
  assertHh(name);
  for (const k of RULE_KEYS) {
    const r = desired[k];
    if (r === '') throw new Error(`${name}.${k} is leeg ("" = publiek) — geweigerd.`);
    if (r !== null && !r.includes('@request.auth')) throw new Error(`${name}.${k} vereist geen login — geweigerd.`);
  }
  const current = await pb.collections.getOne(name);
  const verschil = RULE_KEYS.filter((k) => (current[k] ?? null) !== (desired[k] ?? null));
  if (!verschil.length) {
    console.log(`✓ ${name}: regels al up-to-date`);
    return;
  }
  console.log(`${APPLY ? '↻' : '+ ZOU'} regels bijwerken op ${name}${APPLY ? '' : ' — dry-run'}`);
  for (const k of verschil) {
    console.log(`    ${k}:\n      was: ${JSON.stringify(current[k] ?? null)}\n      wordt: ${JSON.stringify(desired[k] ?? null)}`);
  }
  if (!APPLY) return;
  await pb.collections.update(current.id, desired);
  console.log(`↻ ${name}: regels bijgewerkt`);
}

async function main() {
  const pb = await superuserClient();
  logMode();
  for (const name of ['hh_klussen', 'hh_klus_status']) {
    await applyRules(pb, name, RULESET_M6[name]);
  }
  console.log(APPLY ? '\nKlaar. De achterdeur staat dicht op de server.' : '\nDry-run klaar. Niets geschreven.');
}

if (process.argv[1] && process.argv[1].endsWith('13-status-rules.mjs')) {
  main().catch(fail);
}
