// HeitjeHulp B9 stap 2 — rules voor XP en badges.
//
// 1. De drie NIEUWE collecties (hh_xp, hh_badges, hh_verklaringen):
//      lezen      de helper zelf of de coordinator
//      schrijven  niemand via de API (null): alleen de hooks via $app
//    De bewoner ziet niveau/"Nieuw in de buurt" alleen via de KiesHelper-
//    route (B5) en de verklaring alleen via de controlecode-route.
// 2. SLOTEN op bestaande rules (gewikkeld, niet herschreven; patroon 21):
//      hh_profielen     create/update  (huidig) && xp_totaal/niveau/
//                       idin_geverifieerd_op :isset = false
//      hh_beoordelingen create/update  (huidig) && verborgen_op/_door/
//                       _reden :isset = false
//    Niemand zet die velden via de API, ook de coordinator niet: XP en niveau
//    schrijft de hook, verbergen gaat via POST /api/hh/beoordelingen/{id}/
//    verbergen (die rekent sterren en XP meteen opnieuw uit). Een dichte rule
//    (null) blijft null.
//    Draai 141 NA 02/06/13/21/61 (die zetten de oude rules terug; na 141
//    die nooit meer met --apply, of daarna 141 opnieuw).
//
// DRAAIEN (na 140 --apply):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/141-b9-rules.mjs            (dry-run)
//   node scripts/141-b9-rules.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';
import { XP, BADGES, VERKLARINGEN } from './140-b9-xp.mjs';

const AUTH = '@request.auth.id != "" && @request.auth.collectionName = "hh_users"';
export const LEZEN = `${AUTH} && (helper = @request.auth.id || @request.auth.rol = "coordinator")`;

export const NIEUWE_RULES = {
  listRule: LEZEN,
  viewRule: LEZEN,
  createRule: null,
  updateRule: null,
  deleteRule: null,
};

export const PROFIEL_SLOT =
  '@request.body.xp_totaal:isset = false && @request.body.niveau:isset = false && @request.body.idin_geverifieerd_op:isset = false';
export const BEOORDELING_SLOT =
  '@request.body.verborgen_op:isset = false && @request.body.verborgen_door:isset = false && @request.body.verborgen_reden:isset = false';

export const SLOTEN = [
  { naam: 'hh_profielen', slot: PROFIEL_SLOT },
  { naam: 'hh_beoordelingen', slot: BEOORDELING_SLOT },
];

const RULE_KEYS = ['listRule', 'viewRule', 'createRule', 'updateRule', 'deleteRule'];
const SLOT_KEYS = ['createRule', 'updateRule'];

/// Wikkelt [huidig] in [slot]. Null blijft null; staat het slot er al, dan
/// blijft de rule gelijk (tweede run = niets te doen).
export function metSlot(huidig, slot) {
  if (huidig === null || huidig === undefined) return null;
  if (String(huidig).includes(slot)) return huidig;
  if (String(huidig).trim() === '') {
    throw new Error('Lege rule ("" = publiek) — geweigerd, dit script wikkelt alleen bestaande rules.');
  }
  return `(${huidig}) && ${slot}`;
}

async function nieuweRules(pb, naam) {
  assertHh(naam);
  for (const k of RULE_KEYS) {
    const r = NIEUWE_RULES[k];
    if (r === '') throw new Error(`${naam}.${k} is leeg ("" = publiek) — geweigerd.`);
    if (r !== null && !r.includes('@request.auth')) throw new Error(`${naam}.${k} vereist geen login — geweigerd.`);
  }
  let col;
  try {
    col = await pb.collections.getOne(naam);
  } catch (_) {
    console.log(`! ${naam} bestaat nog niet — eerst 140-b9-xp.mjs --apply.`);
    if (APPLY) throw new Error(`${naam} ontbreekt.`);
    return 0;
  }
  const verschil = RULE_KEYS.filter((k) => (col[k] ?? null) !== (NIEUWE_RULES[k] ?? null));
  if (!verschil.length) {
    console.log(`✓ ${naam}: regels al up-to-date`);
    return 0;
  }
  console.log(`${APPLY ? '↻' : '+ ZOU'} regels bijwerken op ${naam}${APPLY ? '' : ' — dry-run'}`);
  for (const k of verschil) console.log(`    ${k}:\n      was:   ${JSON.stringify(col[k] ?? null)}\n      wordt: ${JSON.stringify(NIEUWE_RULES[k])}`);
  if (!APPLY) return verschil.length;
  await pb.collections.update(col.id, NIEUWE_RULES);
  console.log(`↻ ${naam}: regels bijgewerkt`);
  return verschil.length;
}

async function slot(pb, { naam, slot: s }) {
  assertHh(naam);
  const col = await pb.collections.getOne(naam);
  const gewenst = {};
  for (const k of SLOT_KEYS) {
    const huidig = col[k] ?? null;
    const nieuw = metSlot(huidig, s);
    if (huidig === nieuw) {
      console.log(`✓ ${naam}.${k}: het B9-slot staat er al${huidig === null ? ' (dicht)' : ''}`);
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
  const mist = SLOT_KEYS.filter((k) => na[k] !== null && !String(na[k]).includes(s));
  if (mist.length) throw new Error(`Na apply mist het slot nog op ${naam}: ${mist.join(', ')}`);
  console.log(`↻ ${naam}: slot gezet`);
  return n;
}

async function main() {
  const pb = await superuserClient();
  logMode();
  let n = 0;
  for (const naam of [XP, BADGES, VERKLARINGEN]) n += await nieuweRules(pb, naam);
  for (const s of SLOTEN) n += await slot(pb, s);
  if (!n) console.log('\nNiets te doen: alle B9-regels staan er al.');
  else console.log(APPLY ? '\nKlaar.' : `\nDRY-RUN: ${n} regel(s). Draai met --apply.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
