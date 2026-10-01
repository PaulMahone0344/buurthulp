// HeitjeHulp M8 stap 2 — zet de API-rules van hh_meldingen. Dit script raakt
// ALLEEN hh_meldingen aan; elke andere collectie blijft staan zoals hij op de
// server staat (02, 06 en 13 hebben elkaar al overschreven, dus we vertrouwen
// de server en niet de oude scripts).
//
// DE REGELS (PROMPT-M8, keuze 2)
//   lezen (list/view)  alleen de ontvanger zelf.
//   bijwerken          alleen de ontvanger, en alleen het veld gelezen_op:
//                      elk ander veld in de body maakt de rule onwaar
//                      (@request.body.X:isset = false). De hook
//                      hh_meldingen.pb.js zet bovendien elk ander veld terug
//                      naar de opgeslagen waarde — twee sluizen.
//   aanmaken           niemand via de API (null = alleen superuser). De hook
//                      schrijft de meldingen met $app; die loopt niet langs
//                      de rules.
//   verwijderen        niemand via de API. Meldingen verdwijnen mee met de
//                      gebruiker (cascadeDelete op ontvanger).
//
// Let op: "" zou PUBLIEK betekenen, null is superuser-only (memory
// reference_pb_api_rules). De guard hieronder weigert een lege string.
//
// DRAAIEN (na 30-meldingen-collectie.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/31-meldingen-rules.mjs            (dry-run: toont het verschil)
//   node scripts/31-meldingen-rules.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';
import { COLLECTIE } from './30-meldingen-collectie.mjs';

const AUTH = '@request.auth.id != "" && @request.auth.collectionName = "hh_users"';
const IK_BEN_ONTVANGER = 'ontvanger = @request.auth.id';

/// Alles behalve gelezen_op mag niet in de body zitten.
const ALLEEN_GELEZEN_OP = [
  'ontvanger',
  'soort',
  'klus',
  'incident',
  'titel',
  'tekst',
  'sleutel',
]
  .map((veld) => `@request.body.${veld}:isset = false`)
  .join(' && ');

export const MELDINGEN_RULES = {
  listRule: `${AUTH} && ${IK_BEN_ONTVANGER}`,
  viewRule: `${AUTH} && ${IK_BEN_ONTVANGER}`,
  createRule: null,
  updateRule: `${AUTH} && ${IK_BEN_ONTVANGER} && ${ALLEEN_GELEZEN_OP}`,
  deleteRule: null,
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
  await applyRules(pb, COLLECTIE, MELDINGEN_RULES);

  // Alleen LEZEN: de hook maakt bij elk nieuw incident meldingen aan, dus
  // het is goed om te zien dat hh_incidenten nog steeds door een gewone
  // gebruiker aangemaakt mag worden. Wordt niets aan gewijzigd.
  const incidenten = await pb.collections.getOne('hh_incidenten');
  console.log(`\nTer controle (niet gewijzigd) hh_incidenten.createRule:\n  ${JSON.stringify(incidenten.createRule ?? null)}`);

  console.log(APPLY ? '\nKlaar. hh_meldingen staat op slot behalve voor de ontvanger.' : '\nDry-run klaar. Niets geschreven.');
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
