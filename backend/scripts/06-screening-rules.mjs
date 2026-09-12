// HeitjeHulp M3 stap 2 — past TWEE rules aan voor de screening. Bouwt op
// de bouwstenen van 02-rules.mjs (dat bestand zelf blijft ongewijzigd) en
// overschrijft alleen hh_profielen.updateRule en hh_klussen.listRule/viewRule.
//
// 1. hh_profielen.updateRule (eigenaar): verificatiestatus mag ALLEEN mee
//    als het profiel van nieuw naar in_behandeling gaat ("ter controle
//    aanbieden", J9). Een profiel dat de app zelf aanmaakt heeft een LEGE
//    verificatiestatus (PocketBase kent geen standaardwaarde op een
//    keuzeveld; de eigenaar mag het veld bij aanmaken niet meesturen), dus
//    leeg telt hier als nieuw. De overige geblokkeerde velden (gebruiker,
//    vog_status, iban_geverifieerd, sterren_gemiddeld, klussen_aantal)
//    blijven geblokkeerd. Coordinator blijft alles mogen.
// 2. hh_klussen.listRule/viewRule: de tak "jongere ziet open klussen in
//    eigen wijk" eist extra dat zijn profiel verificatiestatus = goedgekeurd
//    heeft (@collection-patroon). Toegewezen klussen blijven zichtbaar
//    ongeacht status.
//
// LET OP: na deze stap toont 02-rules.mjs (dry-run) een verschil op deze
// twee collecties; 02 NIET opnieuw met --apply draaien, anders vallen de
// screeningregels terug naar M1. 04-rulecheck.mjs moet groen blijven (218).
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/06-screening-rules.mjs            (dry-run: toont het verschil)
//   node scripts/06-screening-rules.mjs --apply

import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';
import { RULESET } from './02-rules.mjs';

// Dezelfde bouwstenen als 02-rules.mjs (daar niet geëxporteerd; letterlijk gelijk).
const AUTH = '@request.auth.id != "" && @request.auth.collectionName = "hh_users"';
const COORD = '@request.auth.rol = "coordinator"';
const FAMILIE_VAN = (veld) =>
  `(@request.auth.rol = "familie" && @collection.hh_koppelingen.oudere ?= ${veld} && @collection.hh_koppelingen.familielid ?= @request.auth.id)`;

// Eigenaar mag deze velden op zijn eigen hh_profielen nooit meesturen
// (verificatiestatus staat hier niet meer in; die krijgt zijn eigen regel).
const BLOK_PROFIEL_ZONDER_VERIFICATIE =
  '@request.body.gebruiker:isset = false && @request.body.vog_status:isset = false && ' +
  '@request.body.iban_geverifieerd:isset = false && @request.body.sterren_gemiddeld:isset = false && @request.body.klussen_aantal:isset = false';

// verificatiestatus: niet meesturen, óf de ene toegestane overgang.
const VERIFICATIE_OVERGANG =
  '(@request.body.verificatiestatus:isset = false || ' +
  '((verificatiestatus = "nieuw" || verificatiestatus = "") && @request.body.verificatiestatus = "in_behandeling"))';

// Jongere is goedgekeurd: zijn eigen profiel heeft verificatiestatus goedgekeurd.
const JONGERE_GOEDGEKEURD =
  '@collection.hh_profielen.gebruiker ?= @request.auth.id && @collection.hh_profielen.verificatiestatus ?= "goedgekeurd"';

// Wie ziet een klus (M3): als M1, plus de goedgekeurd-eis in de jongere-tak.
const ZIET_KLUS =
  'hulpvrager = @request.auth.id || toegewezen_jongere = @request.auth.id || ' +
  `(@request.auth.rol = "jongere" && status = "open" && @request.auth.wijk != "" && hulpvrager.wijk = @request.auth.wijk && ${JONGERE_GOEDGEKEURD}) || ` +
  `${FAMILIE_VAN('hulpvrager')} || ${COORD}`;

// De M1-RULESET met alleen deze twee collecties overschreven.
export const RULESET_M3 = {
  ...RULESET,
  hh_profielen: {
    ...RULESET.hh_profielen,
    updateRule: `${AUTH} && ((gebruiker = @request.auth.id && ${BLOK_PROFIEL_ZONDER_VERIFICATIE} && ${VERIFICATIE_OVERGANG}) || ${COORD})`,
  },
  hh_klussen: {
    ...RULESET.hh_klussen,
    listRule: `${AUTH} && (${ZIET_KLUS})`,
    viewRule: `${AUTH} && (${ZIET_KLUS})`,
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
  for (const name of ['hh_profielen', 'hh_klussen']) {
    await applyRules(pb, name, RULESET_M3[name]);
  }
  console.log(APPLY ? '\nKlaar. Screeningregels staan op de server.' : '\nDry-run klaar. Niets geschreven.');
}

if (process.argv[1] && process.argv[1].endsWith('06-screening-rules.mjs')) {
  main().catch(fail);
}
