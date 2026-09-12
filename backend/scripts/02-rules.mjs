// HeitjeHulp M1 stap 4 — zet de API-rules op de dertien hh_-collecties.
// Vereist dat 01-collections.mjs al gedraaid is (--apply).
//
// PocketBase v0.25.9: syntax is @request.body.<veld> (niet @request.data).
// Bekende valkuilen (reference_pb_api_rules.md) die hier gelden:
//   - `~` is substring, geen OR → rol-checks altijd met = en ||.
//   - `@request.body.X:isset = false` blokkeert het MEESTUREN van veld X;
//     de app moet zo'n veld dus weglaten uit de update, niet leeg meesturen.
//   - Lege rule "" = publiek. Hier nergens; null = alleen superuser.
//   - Multi-relatievelden vergelijk je met `.id ?=`. Alle relaties hieronder
//     zijn enkelvoudig behalve hh_profielen.klustypes (niet in een rule).
//   - `@collection.X.a ?= ... && @collection.X.b ?= ...` als correlated-EXISTS
//     werkt op deze server (bewezen in obycom_activities + rulecheck).
//   - Mislukte update/delete → 404; mislukte view → 404; list is een filter
//     (200 met lege lijst). De rulecheck test dus op inhoud, niet op code.
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/02-rules.mjs            (dry-run: toont het verschil)
//   node scripts/02-rules.mjs --apply

import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

// Bouwstenen. Elke rule begint met AUTH: ingelogd én uit hh_users (op de
// gedeelde server bestaan ook andere auth-collecties).
const AUTH = '@request.auth.id != "" && @request.auth.collectionName = "hh_users"';
const COORD = '@request.auth.rol = "coordinator"';

// Familielid dat gekoppeld is aan de oudere in <veld> (via hh_koppelingen).
const FAMILIE_VAN = (veld) =>
  `(@request.auth.rol = "familie" && @collection.hh_koppelingen.oudere ?= ${veld} && @collection.hh_koppelingen.familielid ?= @request.auth.id)`;

// Deelnemer van de klus in <klus>: de oudere, de toegewezen jongere of een gekoppeld familielid.
const DEELNEMER_VAN = (klus) =>
  `(${klus}.hulpvrager = @request.auth.id || ${klus}.toegewezen_jongere = @request.auth.id || ${FAMILIE_VAN(`${klus}.hulpvrager`)})`;

// Jongere mag deze velden op hh_klussen nooit meesturen.
const BLOK_JONGERE =
  '@request.body.bedrag_bruto:isset = false && @request.body.vergoeding_jongere:isset = false && ' +
  '@request.body.commissie:isset = false && @request.body.hulpvrager:isset = false && @request.body.geplaatst_door:isset = false';

// Gebruiker mag deze velden op zijn eigen hh_profielen nooit meesturen (screening/reputatie = coordinator/hook).
const BLOK_PROFIEL =
  '@request.body.gebruiker:isset = false && @request.body.verificatiestatus:isset = false && @request.body.vog_status:isset = false && ' +
  '@request.body.iban_geverifieerd:isset = false && @request.body.sterren_gemiddeld:isset = false && @request.body.klussen_aantal:isset = false';

// Nieuwe klus: alleen concept of open, nog zonder jongere.
const NIEUWE_KLUS = '(@request.body.status = "concept" || @request.body.status = "open") && @request.body.toegewezen_jongere:isset = false';

// Wie ziet een klus.
const ZIET_KLUS =
  'hulpvrager = @request.auth.id || toegewezen_jongere = @request.auth.id || ' +
  '(@request.auth.rol = "jongere" && status = "open" && @request.auth.wijk != "" && hulpvrager.wijk = @request.auth.wijk) || ' +
  `${FAMILIE_VAN('hulpvrager')} || ${COORD}`;

const alleenCoord = `${AUTH} && ${COORD}`;

export const RULESET = {
  hh_users: {
    // Jezelf; coordinator alles; verder alleen wie bij je hoort via een klus of koppeling.
    listRule:
      `${AUTH} && (id = @request.auth.id || ${COORD} || ` +
      'hh_klussen_via_toegewezen_jongere.hulpvrager ?= @request.auth.id || ' +
      'hh_klussen_via_hulpvrager.toegewezen_jongere ?= @request.auth.id || ' +
      'hh_koppelingen_via_oudere.familielid ?= @request.auth.id || ' +
      'hh_koppelingen_via_familielid.oudere ?= @request.auth.id)',
    viewRule: null, // gelijk aan listRule, wordt hieronder gekopieerd
    // Zelfregistratie (ook anoniem) mag met hulpvrager/jongere/familie;
    // een coordinator-account maakt alleen een coordinator aan.
    createRule:
      '(@request.body.rol = "hulpvrager" || @request.body.rol = "jongere" || @request.body.rol = "familie") || ' +
      `(${AUTH} && ${COORD})`,
    // Jezelf bijwerken zonder rol mee te sturen (anti-escalatie); coordinator alles.
    updateRule: `${AUTH} && ((id = @request.auth.id && @request.body.rol:isset = false) || ${COORD})`,
    deleteRule: `${AUTH} && (id = @request.auth.id || ${COORD})`,
  },
  hh_wijken: {
    listRule: AUTH,
    viewRule: AUTH,
    createRule: alleenCoord,
    updateRule: alleenCoord,
    deleteRule: alleenCoord,
  },
  hh_klustypes: {
    listRule: AUTH,
    viewRule: AUTH,
    createRule: alleenCoord,
    updateRule: alleenCoord,
    deleteRule: alleenCoord,
  },
  hh_profielen: {
    listRule: `${AUTH} && (gebruiker = @request.auth.id || ${COORD})`,
    viewRule: `${AUTH} && (gebruiker = @request.auth.id || ${COORD})`,
    createRule:
      `${AUTH} && ((@request.body.gebruiker = @request.auth.id && ` +
      BLOK_PROFIEL.replace('@request.body.gebruiker:isset = false && ', '') +
      `) || ${COORD})`,
    updateRule: `${AUTH} && ((gebruiker = @request.auth.id && ${BLOK_PROFIEL}) || ${COORD})`,
    deleteRule: `${AUTH} && (gebruiker = @request.auth.id || ${COORD})`,
  },
  hh_klussen: {
    listRule: `${AUTH} && (${ZIET_KLUS})`,
    viewRule: `${AUTH} && (${ZIET_KLUS})`,
    createRule:
      `${AUTH} && (` +
      '(@request.auth.rol = "hulpvrager" && @request.body.hulpvrager = @request.auth.id && @request.body.geplaatst_door = @request.auth.id && ' +
      `@request.body.bron = "app" && ${NIEUWE_KLUS}) || ` +
      '(@request.auth.rol = "familie" && @request.body.geplaatst_door = @request.auth.id && @request.body.bron = "familie" && ' +
      '@collection.hh_koppelingen.oudere ?= @request.body.hulpvrager && @collection.hh_koppelingen.familielid ?= @request.auth.id && ' +
      `${NIEUWE_KLUS}) || ` +
      `${COORD})`,
    updateRule:
      `${AUTH} && (` +
      // oudere of gekoppeld familielid: eigen klus, eigenaarsvelden niet meesturen
      `((hulpvrager = @request.auth.id || ${FAMILIE_VAN('hulpvrager')}) && @request.body.hulpvrager:isset = false && @request.body.geplaatst_door:isset = false) || ` +
      // jongere accepteert een open klus in eigen wijk: toegewezen_jongere leeg → zichzelf
      '(@request.auth.rol = "jongere" && status = "open" && toegewezen_jongere = "" && @request.body.toegewezen_jongere = @request.auth.id && ' +
      `@request.auth.wijk != "" && hulpvrager.wijk = @request.auth.wijk && ${BLOK_JONGERE}) || ` +
      // jongere werkt zijn eigen toegewezen klus bij (status), zonder toewijzing of bedragen te wijzigen
      `(@request.auth.rol = "jongere" && toegewezen_jongere = @request.auth.id && @request.body.toegewezen_jongere:isset = false && ${BLOK_JONGERE}) || ` +
      `${COORD})`,
    // Klussen verdwijnen nooit stil: alleen een eigen concept, of de coordinator.
    deleteRule: `${AUTH} && ((hulpvrager = @request.auth.id && status = "concept") || ${COORD})`,
  },
  hh_klus_status: {
    listRule: `${AUTH} && (${DEELNEMER_VAN('klus')} || ${COORD})`,
    viewRule: `${AUTH} && (${DEELNEMER_VAN('klus')} || ${COORD})`,
    createRule: `${AUTH} && ((@request.body.door = @request.auth.id && ${DEELNEMER_VAN('klus')}) || ${COORD})`,
    updateRule: alleenCoord,
    deleteRule: alleenCoord,
  },
  hh_beoordelingen: {
    listRule: `${AUTH} && (van_gebruiker = @request.auth.id || naar_gebruiker = @request.auth.id || ${FAMILIE_VAN('klus.hulpvrager')} || ${COORD})`,
    viewRule: `${AUTH} && (van_gebruiker = @request.auth.id || naar_gebruiker = @request.auth.id || ${FAMILIE_VAN('klus.hulpvrager')} || ${COORD})`,
    // Alleen na afronden, alleen door een deelnemer, alleen over de andere deelnemer.
    createRule:
      `${AUTH} && ((@request.body.van_gebruiker = @request.auth.id && klus.status = "afgerond" && ` +
      '(klus.hulpvrager = @request.auth.id || klus.toegewezen_jongere = @request.auth.id) && ' +
      '@request.body.naar_gebruiker != @request.auth.id && ' +
      `(@request.body.naar_gebruiker = klus.hulpvrager || @request.body.naar_gebruiker = klus.toegewezen_jongere)) || ${COORD})`,
    updateRule:
      `${AUTH} && ((van_gebruiker = @request.auth.id && @request.body.klus:isset = false && ` +
      `@request.body.van_gebruiker:isset = false && @request.body.naar_gebruiker:isset = false) || ${COORD})`,
    deleteRule: alleenCoord,
  },
  hh_koppelingen: {
    listRule: `${AUTH} && (oudere = @request.auth.id || familielid = @request.auth.id || ${COORD})`,
    viewRule: `${AUTH} && (oudere = @request.auth.id || familielid = @request.auth.id || ${COORD})`,
    // Alleen de oudere zelf (of coordinator) koppelt een familielid; een familielid kan zichzelf niet koppelen.
    createRule: `${AUTH} && ((@request.auth.rol = "hulpvrager" && @request.body.oudere = @request.auth.id && familielid.rol = "familie") || ${COORD})`,
    updateRule: `${AUTH} && ((oudere = @request.auth.id && @request.body.oudere:isset = false && @request.body.familielid:isset = false) || ${COORD})`,
    deleteRule: `${AUTH} && (oudere = @request.auth.id || familielid = @request.auth.id || ${COORD})`,
  },
  hh_vertrouwd: {
    listRule: `${AUTH} && (oudere = @request.auth.id || jongere = @request.auth.id || ${FAMILIE_VAN('oudere')} || ${COORD})`,
    viewRule: `${AUTH} && (oudere = @request.auth.id || jongere = @request.auth.id || ${FAMILIE_VAN('oudere')} || ${COORD})`,
    createRule: `${AUTH} && ((@request.auth.rol = "hulpvrager" && @request.body.oudere = @request.auth.id && jongere.rol = "jongere") || ${COORD})`,
    updateRule: alleenCoord,
    deleteRule: `${AUTH} && (oudere = @request.auth.id || ${COORD})`,
  },
  hh_betalingen: {
    listRule: `${AUTH} && (betaler = @request.auth.id || klus.hulpvrager = @request.auth.id || ${FAMILIE_VAN('klus.hulpvrager')} || ${COORD})`,
    viewRule: `${AUTH} && (betaler = @request.auth.id || klus.hulpvrager = @request.auth.id || ${FAMILIE_VAN('klus.hulpvrager')} || ${COORD})`,
    createRule: alleenCoord, // Mollie-hook komt in M16
    updateRule: alleenCoord,
    deleteRule: alleenCoord,
  },
  hh_vergoedingen: {
    listRule: `${AUTH} && (jongere = @request.auth.id || ${COORD})`,
    viewRule: `${AUTH} && (jongere = @request.auth.id || ${COORD})`,
    createRule: alleenCoord,
    updateRule: alleenCoord,
    deleteRule: alleenCoord,
  },
  hh_incidenten: {
    listRule: `${AUTH} && (melder = @request.auth.id || ${COORD})`,
    viewRule: `${AUTH} && (melder = @request.auth.id || ${COORD})`,
    // Elke deelnemer van de klus (of iedereen zonder klus: noodknop); afhandeling is van de coordinator.
    createRule:
      `${AUTH} && ((@request.body.melder = @request.auth.id && @request.body.afhandeling:isset = false && ` +
      `(klus = "" || ${DEELNEMER_VAN('klus')})) || ${COORD})`,
    updateRule: alleenCoord,
    deleteRule: alleenCoord,
  },
  hh_push_tokens: {
    listRule: `${AUTH} && gebruiker = @request.auth.id`,
    viewRule: `${AUTH} && gebruiker = @request.auth.id`,
    createRule: `${AUTH} && @request.body.gebruiker = @request.auth.id`,
    updateRule: `${AUTH} && gebruiker = @request.auth.id && @request.body.gebruiker:isset = false`,
    deleteRule: `${AUTH} && gebruiker = @request.auth.id`,
  },
};
RULESET.hh_users.viewRule = RULESET.hh_users.listRule;

const RULE_KEYS = ['listRule', 'viewRule', 'createRule', 'updateRule', 'deleteRule'];

function rulesDiffer(current, desired) {
  return RULE_KEYS.some((k) => (current[k] ?? null) !== (desired[k] ?? null));
}

async function applyRules(pb, name, desired) {
  assertHh(name);
  for (const k of RULE_KEYS) {
    const r = desired[k];
    if (r === '') throw new Error(`${name}.${k} is leeg ("" = publiek) — geweigerd.`);
    if (r !== null && !r.includes('@request.auth')) throw new Error(`${name}.${k} vereist geen login — geweigerd.`);
  }
  const current = await pb.collections.getOne(name);
  if (!rulesDiffer(current, desired)) {
    console.log(`✓ ${name}: regels al up-to-date`);
    return;
  }
  if (!APPLY) {
    console.log(`+ ZOU regels bijwerken op ${name} — dry-run`);
    for (const k of RULE_KEYS) {
      if ((current[k] ?? null) !== (desired[k] ?? null)) {
        console.log(`    ${k}:\n      was: ${JSON.stringify(current[k] ?? null)}\n      wordt: ${JSON.stringify(desired[k] ?? null)}`);
      }
    }
    return;
  }
  await pb.collections.update(current.id, desired);
  console.log(`↻ ${name}: regels bijgewerkt`);
}

async function main() {
  const pb = await superuserClient();
  logMode();
  for (const [name, desired] of Object.entries(RULESET)) {
    await applyRules(pb, name, desired);
  }
  console.log(APPLY ? '\nKlaar. API-rules staan op de server.' : '\nDry-run klaar. Niets geschreven.');
}

// Alleen draaien als dit bestand direct wordt aangeroepen (04-rulecheck importeert RULESET).
if (process.argv[1] && process.argv[1].endsWith('02-rules.mjs')) {
  main().catch(fail);
}
