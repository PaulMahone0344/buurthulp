// HeitjeHulp M14 stap 2 — API-rules voor het beheerpaneel.
//
// 1. NIEUWE collecties (eigen, dus GEZET):
//    hh_instellingen  lezen, aanmaken, bijwerken, verwijderen: alleen
//                     coordinator.
//    hh_auditlog      lezen: alleen coordinator. Aanmaken, bijwerken,
//                     verwijderen: niemand via de API (null); de hook
//                     hh_beheer.pb.js schrijft via $app. Een logboek dat je
//                     kunt wijzigen is geen logboek.
//
// 2. BESTAANDE collecties: de rule die op de server staat wordt GEWIKKELD,
//    niet herschreven (02, 06, 13, 21, 41, 44 en 45 hebben er al aan
//    gezeten; de server is de waarheid):
//      nieuw = "(" + huidig + ") && " + slot
//    met slot = (coordinator || velden niet in de body). Zo blijft alles van
//    eerdere milestones letterlijk staan en mag alleen de coordinator de
//    nieuwe velden zetten:
//      hh_users.createRule/updateRule      geblokkeerd
//      hh_profielen.createRule/updateRule  screening_notitie, vog_geldig_tot
//    Idempotent: staat het slot er al, dan gebeurt er niets. null blijft
//    null; een lege rule ("" = publiek) wordt geweigerd.
//
// VOLGORDE: na 60-beheer-velden.mjs --apply. Draai 02, 06, 13 of 21 daarna
// niet meer met --apply zonder 61 opnieuw te draaien (dan valt het slot eraf).
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/61-beheer-rules.mjs            (dry-run: toont het verschil)
//   node scripts/61-beheer-rules.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

export const AUTH = '@request.auth.id != "" && @request.auth.collectionName = "hh_users"';
export const COORD = '@request.auth.collectionName = "hh_users" && @request.auth.rol = "coordinator"';
const ALLEEN_COORD = `${AUTH} && ${COORD}`;

export const NIEUWE_RULES = {
  hh_instellingen: {
    listRule: ALLEEN_COORD,
    viewRule: ALLEEN_COORD,
    createRule: ALLEEN_COORD,
    updateRule: ALLEEN_COORD,
    deleteRule: ALLEEN_COORD,
  },
  hh_auditlog: {
    listRule: ALLEEN_COORD,
    viewRule: ALLEEN_COORD,
    createRule: null,
    updateRule: null,
    deleteRule: null,
  },
};

/// Welke velden op welke bestaande collectie alleen de coordinator zet.
export const SLOT_VELDEN = {
  hh_users: ['geblokkeerd'],
  hh_profielen: ['screening_notitie', 'vog_geldig_tot'],
};
const SLOT_RULES = ['createRule', 'updateRule'];

export function slot(velden) {
  const niet = velden.map((v) => `@request.body.${v}:isset = false`).join(' && ');
  return `((${COORD}) || (${niet}))`;
}

/// Wikkelt [huidig] in het slot voor [velden].
export function metSlot(huidig, velden) {
  if (huidig === null || huidig === undefined) return null;
  const s = slot(velden);
  if (String(huidig).includes(s)) return huidig;
  if (String(huidig).trim() === '') {
    throw new Error('Lege rule ("" = publiek) — geweigerd, dit script wikkelt alleen bestaande rules.');
  }
  return `(${huidig}) && ${s}`;
}

const RULE_KEYS = ['listRule', 'viewRule', 'createRule', 'updateRule', 'deleteRule'];

async function zetNieuw(pb, naam, gewenst) {
  assertHh(naam);
  for (const k of RULE_KEYS) {
    const r = gewenst[k];
    if (r === '') throw new Error(`${naam}.${k} is leeg ("" = publiek) — geweigerd.`);
    if (r !== null && !r.includes('@request.auth')) throw new Error(`${naam}.${k} vereist geen login — geweigerd.`);
  }
  const col = await pb.collections.getOne(naam);
  const verschil = RULE_KEYS.filter((k) => (col[k] ?? null) !== (gewenst[k] ?? null));
  if (!verschil.length) {
    console.log(`✓ ${naam}: regels al up-to-date`);
    return 0;
  }
  console.log(`${APPLY ? '↻' : '+ ZOU'} regels zetten op ${naam}${APPLY ? '' : ' — dry-run'}`);
  for (const k of verschil) {
    console.log(`    ${k}:\n      was:   ${JSON.stringify(col[k] ?? null)}\n      wordt: ${JSON.stringify(gewenst[k] ?? null)}`);
  }
  if (APPLY) await pb.collections.update(col.id, gewenst);
  return verschil.length;
}

async function wikkel(pb, naam, velden) {
  assertHh(naam);
  const col = await pb.collections.getOne(naam);
  const gewenst = {};
  for (const k of SLOT_RULES) {
    const huidig = col[k] ?? null;
    const nieuw = metSlot(huidig, velden);
    if (nieuw === huidig) {
      console.log(`✓ ${naam}.${k}: het slot staat er al (of de rule is null)`);
      continue;
    }
    gewenst[k] = nieuw;
    console.log(`${APPLY ? '↻' : '+ ZOU'} ${naam}.${k} wikkelen${APPLY ? '' : ' — dry-run'}`);
    console.log(`    was:   ${JSON.stringify(huidig)}`);
    console.log(`    wordt: ${JSON.stringify(nieuw)}`);
  }
  const aantal = Object.keys(gewenst).length;
  if (!aantal || !APPLY) return aantal;
  await pb.collections.update(col.id, gewenst);
  const na = await pb.collections.getOne(naam);
  const mist = Object.keys(gewenst).filter((k) => !String(na[k] ?? '').includes(slot(velden)));
  if (mist.length) throw new Error(`Na apply mist het slot nog op ${naam}: ${mist.join(', ')}`);
  return aantal;
}

async function main() {
  const pb = await superuserClient();
  logMode();
  let totaal = 0;
  for (const [naam, rules] of Object.entries(NIEUWE_RULES)) totaal += await zetNieuw(pb, naam, rules);
  for (const [naam, velden] of Object.entries(SLOT_VELDEN)) totaal += await wikkel(pb, naam, velden);
  if (!totaal) console.log('\nNiets te doen.');
  else if (!APPLY) console.log(`\nDRY-RUN: ${totaal} regel(s) zouden veranderen. Draai met --apply.`);
  else console.log(`\n✓ ${totaal} regel(s) bijgewerkt.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
