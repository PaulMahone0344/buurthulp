// HeitjeHulp B5 stap 2 — zet de API-rules van hh_reacties (nieuwe eigen
// collectie, dus GEZET en niet gewikkeld). Raakt ALLEEN hh_reacties aan;
// GEEN bestaande rule verandert.
//
// DE REGELS (PROMPT-B5)
//   lezen (list/view)
//     - de helper zelf: al zijn eigen reacties (elke status)
//     - de bewoner van de klus (klus.hulpvrager): alleen status open en
//       gekozen. Wat op de ouder wacht (wacht_op_ouder) of afgewezen is, ziet
//       hij niet (punt 1: pas na "Goed" ziet de bewoner de reactie). Voor
//       KiesHelper (voornaam, leeftijd, sterren, ...) gebruikt de app de route
//       GET /api/hh/klussen/{id}/reacties; deze rule is voor het tellen en
//       realtime.
//     - de coordinator: alles
//     - NIET: andere helpers, familie, anoniem
//   aanmaken / bijwerken / verwijderen
//     - niemand via de API (null). Alles via de routes in hh_reacties.pb.js
//       ($app loopt niet langs de rules). Zo kan niemand zelf een status,
//       ouder_akkoord_op of token zetten.
//   token_hash is daarnaast "hidden" (130): ook de coordinator leest hem niet.
//
// Let op: "" zou PUBLIEK betekenen, null is superuser-only. De guard weigert
// een lege string.
//
// DRAAIEN (na 130-b5-reacties.mjs --apply):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/131-b5-rules.mjs            (dry-run: toont het verschil)
//   node scripts/131-b5-rules.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';
import { COLLECTIE } from './130-b5-reacties.mjs';

const AUTH = '@request.auth.id != "" && @request.auth.collectionName = "hh_users"';
const HELPER = 'helper = @request.auth.id';
const BEWONER = '(klus.hulpvrager = @request.auth.id && (status = "open" || status = "gekozen"))';
const COORDINATOR = '@request.auth.rol = "coordinator"';

export const LEZEN = `${AUTH} && (${HELPER} || ${BEWONER} || ${COORDINATOR})`;

export const REACTIE_RULES = {
  listRule: LEZEN,
  viewRule: LEZEN,
  createRule: null,
  updateRule: null,
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
    console.log(`! ${name} bestaat nog niet — eerst 130-b5-reacties.mjs --apply. (dry-run toont de gewenste rules)`);
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
  await applyRules(pb, COLLECTIE, REACTIE_RULES);
  console.log(APPLY ? '\nKlaar.' : '\nDry-run klaar. Niets geschreven.');
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
