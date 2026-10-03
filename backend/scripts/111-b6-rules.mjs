// HeitjeHulp B6 stap 2 — zet de API-rules van hh_berichten (nieuwe eigen
// collectie, dus GEZET en niet gewikkeld). Raakt ALLEEN hh_berichten aan.
//
// DE REGELS (PROMPT-B6)
//   lezen (list/view)
//     - de bewoner van de klus (klus.hulpvrager)
//     - de helper van DIT gesprek, zolang hij nog de toegewezen helper is
//       (helper = ik && klus.toegewezen_jongere = ik). Geeft hij de klus
//       terug, dan leest hij niets meer; een nieuwe helper leest het gesprek
//       van de vorige niet (ander "helper").
//     - de coordinator ALLEEN als er een incident (hh_incidenten) op die klus
//       is (voorstel prompt, gekozen). Zonder melding geen inzage.
//     - NIET: familie/ouder (besluit: ouder leest niet mee), andere helpers.
//   aanmaken
//     - alleen de bewoner of de toegewezen helper van de klus, met
//       afzender = jijzelf, en alleen als de klus een helper heeft en op
//       geaccepteerd/onderweg/bezig/probleem staat, of op afgerond/
//       geannuleerd (de hook hh_chat.pb.js sluit die na 72 uur: een rule kan
//       niet met datums rekenen).
//     - helper, gelezen_op, gefilterd en contactverzoek niet meesturen (die
//       zet de hook). De coordinator schrijft niet in de chat.
//   bijwerken
//     - alleen wie het bericht mag lezen en NIET de afzender is (de
//       ontvanger), en alleen gelezen_op. De hook zet de rest ook terug.
//   verwijderen
//     - niemand via de API (null). Berichten verdwijnen mee met de klus.
//
// Let op: "" zou PUBLIEK betekenen, null is superuser-only. De guard weigert
// een lege string.
//
// DRAAIEN (na 110-b6-berichten.mjs --apply):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/111-b6-rules.mjs            (dry-run: toont het verschil)
//   node scripts/111-b6-rules.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';
import { COLLECTIE } from './110-b6-berichten.mjs';

const AUTH = '@request.auth.id != "" && @request.auth.collectionName = "hh_users"';
const BEWONER = 'klus.hulpvrager = @request.auth.id';
const HELPER_NU = '(helper = @request.auth.id && klus.toegewezen_jongere = @request.auth.id)';
const DEELNEMER_KLUS = '(klus.hulpvrager = @request.auth.id || klus.toegewezen_jongere = @request.auth.id)';

/// Inzage voor de meldkamer: alleen bij een melding op die klus.
export const COORDINATOR_INZAGE = '(@request.auth.rol = "coordinator" && @collection.hh_incidenten.klus ?= klus)';

/// Statussen waarin schrijven mag (de hook doet de 72 uur na afloop).
export const STATUS_SCHRIJVEN = ['geaccepteerd', 'onderweg', 'bezig', 'probleem', 'afgerond', 'geannuleerd'];

export const LEZEN = `${AUTH} && (${BEWONER} || ${HELPER_NU} || ${COORDINATOR_INZAGE})`;

const nietMeesturen = (velden) => velden.map((v) => `@request.body.${v}:isset = false`).join(' && ');

const SCHRIJVEN = [
  AUTH,
  '@request.body.afzender = @request.auth.id',
  DEELNEMER_KLUS,
  'klus.toegewezen_jongere != ""',
  `(${STATUS_SCHRIJVEN.map((s) => `klus.status = "${s}"`).join(' || ')})`,
  nietMeesturen(['helper', 'gelezen_op', 'gefilterd', 'contactverzoek']),
].join(' && ');

const GELEZEN_ZETTEN = [
  AUTH,
  `(${BEWONER} || ${HELPER_NU})`,
  'afzender != @request.auth.id',
  nietMeesturen(['klus', 'afzender', 'helper', 'tekst', 'soort', 'gefilterd', 'contactverzoek']),
].join(' && ');

export const BERICHTEN_RULES = {
  listRule: LEZEN,
  viewRule: LEZEN,
  createRule: SCHRIJVEN,
  updateRule: GELEZEN_ZETTEN,
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
  let current;
  try {
    current = await pb.collections.getOne(name);
  } catch (_) {
    console.log(`! ${name} bestaat nog niet — eerst 110-b6-berichten.mjs --apply. (dry-run toont de gewenste rules)`);
    for (const k of RULE_KEYS) console.log(`    ${k}: ${JSON.stringify(desired[k])}`);
    if (APPLY) throw new Error(`${name} ontbreekt.`);
    return;
  }
  const verschil = RULE_KEYS.filter((k) => (current[k] ?? null) !== (desired[k] ?? null));
  if (!verschil.length) {
    console.log(`✓ ${name}: regels al up-to-date`);
    return;
  }
  console.log(`${APPLY ? '↻' : '+ ZOU'} regels bijwerken op ${name}${APPLY ? '' : ' — dry-run'}`);
  for (const k of verschil) {
    console.log(`    ${k}:\n      was:   ${JSON.stringify(current[k] ?? null)}\n      wordt: ${JSON.stringify(desired[k] ?? null)}`);
  }
  if (!APPLY) return;
  await pb.collections.update(current.id, desired);
  console.log(`↻ ${name}: regels bijgewerkt`);
}

async function main() {
  const pb = await superuserClient();
  logMode();
  await applyRules(pb, COLLECTIE, BERICHTEN_RULES);
  console.log(APPLY ? '\nKlaar.' : '\nDry-run klaar. Niets geschreven.');
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
