// HeitjeHulp M9 stap 2 — dwingt de koppeling-met-toestemming en de rechten
// van het familielid af in de API-rules (backend OPEN-PUNT 2, 13 en 19).
//
// DEZE AANPAK: GERICHT WIKKELEN. De scripts 02, 06 en 13 (en M7's 21) hebben
// de rules al na elkaar gezet; de server is de waarheid. Dit script leest de
// actuele rules en verandert ALLEEN de familie-takken; al het andere blijft
// letterlijk staan. Staat een verwachte tak er niet, dan wordt die rule niet
// aangeraakt (en meldt het script dat).
//
// WAT ER VERANDERT
//   1. Elke familie-tak van de vorm (02: FAMILIE_VAN)
//        (@request.auth.rol = "familie" && @collection.hh_koppelingen.oudere ?= X
//         && @collection.hh_koppelingen.familielid ?= @request.auth.id)
//      krijgt er binnen de haakjes bij:
//        && @collection.hh_koppelingen.status ?= "actief"
//        && @collection.hh_koppelingen.rechten ?= "meekijken"   (list/view)
//        && @collection.hh_koppelingen.rechten ?= "plaatsen"    (create/update/delete)
//   2. De familie-tak van hh_klussen.createRule (plaatsen namens de oudere)
//      krijgt status actief en recht plaatsen.
//   3. hh_users (list/view): het familielid ziet de oudere pas als de
//      koppeling actief is; de oudere ziet het familielid altijd (ook bij
//      een aanvraag, om Ja of Nee te zeggen). EN er komt één stap bij
//      (OPEN-PUNT 13): het familielid ziet de toegewezen jongere op een klus
//      van zijn oudere, bij een actieve koppeling met recht meekijken.
//
// Alle voorwaarden op hh_koppelingen staan in hetzelfde pad (zelfde join),
// zodat ze voor DEZELFDE koppeling moeten gelden. 42-familiecheck bewijst op
// de server dat een aanvraag bij oudere B geen toegang geeft omdat er bij B
// een ander, actief familielid is.
//
// Idempotent: een al gewikkelde tak wordt herkend en overgeslagen.
// VOLGORDE: 40 --apply (status + terugvullen) VÓÓR 41 --apply, anders valt
// de bestaande seed-koppeling meteen dicht. Draai 02, 06 of 13 daarna niet
// opnieuw met --apply (dan valt de wikkel eraf; 41 opnieuw draaien zet hem
// terug).
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/41-familie-rules.mjs            (dry-run: toont het verschil)
//   node scripts/41-familie-rules.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

export const ACTIEF = '@collection.hh_koppelingen.status ?= "actief"';
export const MAG_MEEKIJKEN = '@collection.hh_koppelingen.rechten ?= "meekijken"';
export const MAG_PLAATSEN = '@collection.hh_koppelingen.rechten ?= "plaatsen"';

const RULE_KEYS = ['listRule', 'viewRule', 'createRule', 'updateRule', 'deleteRule'];
const LEES_KEYS = new Set(['listRule', 'viewRule']);

/// De collecties waarin 02/06/13 een familie-tak zetten. Andere collecties
/// worden niet eens gelezen.
export const COLLECTIES = [
  'hh_users',
  'hh_klussen',
  'hh_klus_status',
  'hh_beoordelingen',
  'hh_vertrouwd',
  'hh_betalingen',
  'hh_incidenten',
];

// 1. FAMILIE_VAN(X), nog niet gewikkeld: direct na "familielid ?= auth.id"
//    staat het sluithaakje.
const FAMILIE_TAK =
  /\(@request\.auth\.rol = "familie" && @collection\.hh_koppelingen\.oudere \?= ([^\s()]+) && @collection\.hh_koppelingen\.familielid \?= @request\.auth\.id\)/g;
const FAMILIE_TAK_GEWIKKELD =
  /@collection\.hh_koppelingen\.familielid \?= @request\.auth\.id && @collection\.hh_koppelingen\.status \?= "actief"/;

// 2. De plaats-tak van hh_klussen.createRule.
const PLAATS_TAK =
  /(@collection\.hh_koppelingen\.oudere \?= @request\.body\.hulpvrager && @collection\.hh_koppelingen\.familielid \?= @request\.auth\.id)(?! && @collection\.hh_koppelingen\.status)/g;

// 3. hh_users.
const USERS_OUDERE = 'hh_koppelingen_via_oudere.familielid ?= @request.auth.id';
const USERS_OUDERE_GEWIKKELD =
  '(hh_koppelingen_via_oudere.familielid ?= @request.auth.id && hh_koppelingen_via_oudere.status ?= "actief")';
const PAD = 'hh_klussen_via_toegewezen_jongere.hulpvrager.hh_koppelingen_via_oudere';
export const JONGERE_VAN_MIJN_OUDERE =
  `(${PAD}.familielid ?= @request.auth.id && ${PAD}.status ?= "actief" && ${PAD}.rechten ?= "meekijken")`;

/// Wikkelt de familie-takken in één rule. Geeft { rule, aantal, alGewikkeld }.
/// Puur: geen server, los te testen.
export function wikkelRule(collectie, key, rule) {
  if (rule === null || rule === undefined) return { rule, aantal: 0, alGewikkeld: false };
  if (String(rule).trim() === '') {
    throw new Error(`${collectie}.${key} is leeg ("" = publiek) — dit script wikkelt alleen bestaande rules.`);
  }
  const recht = LEES_KEYS.has(key) ? MAG_MEEKIJKEN : MAG_PLAATSEN;
  let uit = String(rule);
  let aantal = 0;

  uit = uit.replace(FAMILIE_TAK, (_, veld) => {
    aantal++;
    return (
      `(@request.auth.rol = "familie" && @collection.hh_koppelingen.oudere ?= ${veld} && ` +
      `@collection.hh_koppelingen.familielid ?= @request.auth.id && ${ACTIEF} && ${recht})`
    );
  });

  if (collectie === 'hh_klussen' && key === 'createRule') {
    uit = uit.replace(PLAATS_TAK, (_, tak) => {
      aantal++;
      return `${tak} && ${ACTIEF} && ${MAG_PLAATSEN}`;
    });
  }

  let usersGewikkeld = false;
  if (collectie === 'hh_users' && LEES_KEYS.has(key)) {
    if (uit.includes(USERS_OUDERE_GEWIKKELD)) {
      usersGewikkeld = true;
    } else if (uit.includes(USERS_OUDERE)) {
      uit = uit.replace(USERS_OUDERE, `${USERS_OUDERE_GEWIKKELD} || ${JONGERE_VAN_MIJN_OUDERE}`);
      aantal++;
    }
  }

  const alGewikkeld =
    aantal === 0 &&
    (usersGewikkeld ||
      FAMILIE_TAK_GEWIKKELD.test(uit) ||
      uit.includes(`@request.auth.id && ${ACTIEF} && ${MAG_PLAATSEN}`));
  return { rule: uit, aantal, alGewikkeld };
}

/// Alle rules van één collectie. Geeft { gewijzigd: {key: nieuweRule}, log }.
export function wikkelCollectie(collectie, rules) {
  const gewijzigd = {};
  const log = [];
  for (const key of RULE_KEYS) {
    const huidig = rules[key] ?? null;
    const { rule, aantal, alGewikkeld } = wikkelRule(collectie, key, huidig);
    if (aantal > 0) {
      gewijzigd[key] = rule;
      log.push(`${collectie}.${key}: ${aantal} familie-tak(ken) gewikkeld`);
    } else if (alGewikkeld) {
      log.push(`${collectie}.${key}: al gewikkeld`);
    }
  }
  return { gewijzigd, log };
}

async function main() {
  const pb = await superuserClient();
  logMode();
  let teDoen = 0;

  for (const naam of COLLECTIES) {
    assertHh(naam);
    let col;
    try {
      col = await pb.collections.getOne(naam);
    } catch (_) {
      console.log(`  · ${naam} bestaat niet op de server; overgeslagen`);
      continue;
    }
    const { gewijzigd, log } = wikkelCollectie(naam, col);
    for (const regel of log) console.log(`  ${regel}`);
    const keys = Object.keys(gewijzigd);
    if (!keys.length) continue;
    teDoen += keys.length;
    for (const k of keys) {
      console.log(`    ${k}:\n      was:   ${JSON.stringify(col[k])}\n      wordt: ${JSON.stringify(gewijzigd[k])}`);
    }
    if (APPLY) {
      await pb.collections.update(col.id, gewijzigd);
      console.log(`  ↻ ${naam}: ${keys.length} rule(s) bijgewerkt`);
    }
  }

  // Verwacht: hh_klussen list/view/create/update en hh_users list/view.
  // Een ontbrekende verwachte tak is een teken dat de server afwijkt van
  // wat 02/06/13 zetten: dan eerst kijken, niet doordrukken.
  if (!APPLY) {
    console.log(`\nDRY-RUN: ${teDoen} rule(s) zouden worden gewikkeld. Niets geschreven.`);
    return;
  }
  console.log(`\n✓ Klaar: ${teDoen} rule(s) gewikkeld.`);
}

// Alleen draaien als dit script zelf wordt gestart (42 en de test importeren).
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
