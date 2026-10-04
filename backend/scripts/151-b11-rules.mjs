// HeitjeHulp B11 stap 2 — rules voor de meldkamer.
//
// 1. hh_partners (NIEUW): alles alleen de coordinator. De helper ziet de
//    lijst nooit; de hook zoekt de code op bij het aanmelden.
// 2. SLOTEN op hh_users create/update (gewikkeld, niet herschreven; patroon 21):
//      kennismaking_*  niemand via de API, ook de coordinator niet: die gaat
//                      via POST /api/hh/meldkamer/kennismaking/{id} (audit,
//                      blokkeren en annuleren in één transactie)
//      partner         alleen de coordinator; een helper zet hem via
//                      partner_code bij het aanmelden (hook)
// 3. hh_berichten list/view: de meldkamer leest ELKE chat (besluit Ibrahim
//    4 okt; jurist-vraag + privacyverklaring). Alleen het meldkamer-deel van
//    de rule verandert; de rest blijft letterlijk staan.
//    Draai 151 NA 02/06/13/21/61/111 (die zetten de oude rules terug; na 151
//    die nooit meer met --apply, of daarna 151 opnieuw).
//
// DRAAIEN (na 150 --apply):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/151-b11-rules.mjs            (dry-run)
//   node scripts/151-b11-rules.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';
import { metSlot } from './141-b9-rules.mjs';
import { PARTNERS } from './150-b11-velden.mjs';

const AUTH = '@request.auth.id != "" && @request.auth.collectionName = "hh_users"';
const COORDINATOR = `${AUTH} && @request.auth.rol = "coordinator"`;

export const PARTNER_RULES = {
  listRule: COORDINATOR,
  viewRule: COORDINATOR,
  createRule: COORDINATOR,
  updateRule: COORDINATOR,
  deleteRule: COORDINATOR,
};

export const USERS_SLOT_KENNISMAKING =
  '@request.body.kennismaking_status:isset = false && @request.body.kennismaking_op:isset = false && ' +
  '@request.body.kennismaking_door:isset = false && @request.body.kennismaking_notitie:isset = false';
export const USERS_SLOT_PARTNER =
  '((@request.auth.collectionName = "hh_users" && @request.auth.rol = "coordinator") || (@request.body.partner:isset = false))';

export const BERICHTEN_OUD = '(@request.auth.rol = "coordinator" && @collection.hh_incidenten.klus ?= klus)';
export const BERICHTEN_NIEUW = '(@request.auth.rol = "coordinator")';

const RULE_KEYS = ['listRule', 'viewRule', 'createRule', 'updateRule', 'deleteRule'];
const SLOT_KEYS = ['createRule', 'updateRule'];
const CHAT_KEYS = ['listRule', 'viewRule'];

/// Vervangt het meldkamer-deel van een hh_berichten-rule. Null blijft null,
/// al omgezet blijft gelijk; een onbekende rule -> fout (niets gokken).
export function chatVoorMeldkamer(rule) {
  if (rule === null || rule === undefined) return null;
  const r = String(rule);
  if (r.includes(BERICHTEN_OUD)) return r.split(BERICHTEN_OUD).join(BERICHTEN_NIEUW);
  if (r.includes(BERICHTEN_NIEUW)) return r;
  throw new Error('hh_berichten-rule niet herkend; niets aangepast. Kijk 111/SCHEMA na.');
}

async function partnerRules(pb) {
  assertHh(PARTNERS);
  let col;
  try {
    col = await pb.collections.getOne(PARTNERS);
  } catch (_) {
    console.log(`! ${PARTNERS} bestaat nog niet — eerst 150-b11-velden.mjs --apply.`);
    if (APPLY) throw new Error(`${PARTNERS} ontbreekt.`);
    return 0;
  }
  const verschil = RULE_KEYS.filter((k) => (col[k] ?? null) !== PARTNER_RULES[k]);
  if (!verschil.length) {
    console.log(`✓ ${PARTNERS}: regels al up-to-date`);
    return 0;
  }
  console.log(`${APPLY ? '↻' : '+ ZOU'} regels bijwerken op ${PARTNERS}${APPLY ? '' : ' — dry-run'}`);
  for (const k of verschil) console.log(`    ${k}:\n      was:   ${JSON.stringify(col[k] ?? null)}\n      wordt: ${JSON.stringify(PARTNER_RULES[k])}`);
  if (APPLY) await pb.collections.update(col.id, PARTNER_RULES);
  return verschil.length;
}

/// Zet nieuwe rule-teksten per sleutel en controleert na apply.
async function zet(pb, naam, keys, maak, controle) {
  assertHh(naam);
  const col = await pb.collections.getOne(naam);
  const gewenst = {};
  for (const k of keys) {
    const huidig = col[k] ?? null;
    const nieuw = maak(huidig);
    if (huidig === nieuw) {
      console.log(`✓ ${naam}.${k}: staat er al${huidig === null ? ' (dicht)' : ''}`);
      continue;
    }
    gewenst[k] = nieuw;
    console.log(`${APPLY ? '↻' : '+ ZOU'} ${naam}.${k} bijwerken${APPLY ? '' : ' — dry-run'}`);
    console.log(`    was:   ${JSON.stringify(huidig)}`);
    console.log(`    wordt: ${JSON.stringify(nieuw)}`);
  }
  const n = Object.keys(gewenst).length;
  if (!n || !APPLY) return n;
  await pb.collections.update(col.id, gewenst);
  const na = await pb.collections.getOne(naam);
  const mis = keys.filter((k) => na[k] !== null && !controle(String(na[k])));
  if (mis.length) throw new Error(`Na apply klopt ${naam} nog niet: ${mis.join(', ')}`);
  console.log(`↻ ${naam}: bijgewerkt`);
  return n;
}

async function main() {
  const pb = await superuserClient();
  logMode();
  let n = 0;
  n += await partnerRules(pb);
  n += await zet(
    pb,
    'hh_users',
    SLOT_KEYS,
    (r) => metSlot(metSlot(r, USERS_SLOT_KENNISMAKING), USERS_SLOT_PARTNER),
    (r) => r.includes(USERS_SLOT_KENNISMAKING) && r.includes(USERS_SLOT_PARTNER)
  );
  n += await zet(pb, 'hh_berichten', CHAT_KEYS, chatVoorMeldkamer, (r) => r.includes(BERICHTEN_NIEUW) && !r.includes(BERICHTEN_OUD));
  if (!n) console.log('\nNiets te doen: alle B11-regels staan er al.');
  else console.log(APPLY ? '\nKlaar.' : `\nDRY-RUN: ${n} regel(s). Draai met --apply.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
