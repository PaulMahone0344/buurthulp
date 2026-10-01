// HeitjeHulp M7 stap 2 — zet sterren_gemiddeld en klussen_aantal op hh_users
// dicht voor de API. Niemand mag ze meesturen: niet bij registreren, niet bij
// het bijwerken van je eigen gegevens (O12), en ook de coordinator niet. De
// server rekent ze uit (pb_hooks/hh_beoordelingen.pb.js, via $app, dat niet
// langs de rules loopt); een superuser kan ze altijd nog met de hand zetten.
//
// DEZE AANPAK: wij WIKKELEN de rule die op de server staat, we schrijven hem
// niet opnieuw. De scripts 02, 06 en 13 hebben elkaar al overschreven; de
// server is de waarheid, niet een oude RULESET in een script (gedeelde regels
// ronde 5). Dus:
//
//   nieuw = "(" + huidig + ") && @request.body.sterren_gemiddeld:isset = false" +
//           " && @request.body.klussen_aantal:isset = false"
//
// Zo blijft alles wat M1/M3/M6/M10 daar hebben neergezet letterlijk staan en
// komt er alleen een slot bij. Idempotent: staat het slot er al, dan doet het
// script niets. Raakt ALLEEN hh_users.createRule en hh_users.updateRule; de
// list-, view- en deleteRule blijven onaangeroerd, en geen enkele andere
// collectie wordt bekeken of gewijzigd.
//
// LET OP: hh_profielen heeft deze twee velden al sinds M1 en de rules daar
// blokkeren ze al (BLOK_PROFIEL in 02-rules.mjs). Daar is dus niets te doen.
//
// DRAAIEN (na 20 --apply):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/21-reputatie-rules.mjs           (dry-run: toont het verschil)
//   node scripts/21-reputatie-rules.mjs --apply

import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

const COLLECTIE = 'hh_users';
const RULE_KEYS = ['createRule', 'updateRule'];

// De twee sloten. Eén string, zodat "staat het er al" een simpele
// substring-controle is en het script bij een tweede run niets doet.
export const REPUTATIE_SLOT =
  '@request.body.sterren_gemiddeld:isset = false && @request.body.klussen_aantal:isset = false';

/// Wikkelt [huidig] in het slot. Null (= alleen superuser) blijft null: een
/// dichte rule hoeft geen extra slot en mag nooit per ongeluk opengaan.
export function metSlot(huidig) {
  if (huidig === null || huidig === undefined) return null;
  if (String(huidig).includes(REPUTATIE_SLOT)) return huidig;
  if (String(huidig).trim() === '') {
    throw new Error('Lege rule ("" = publiek) — geweigerd, dit script wikkelt alleen bestaande rules.');
  }
  return `(${huidig}) && ${REPUTATIE_SLOT}`;
}

async function main() {
  assertHh(COLLECTIE);
  const pb = await superuserClient();
  logMode();

  const col = await pb.collections.getOne(COLLECTIE);
  const gewenst = {};
  let teDoen = 0;

  for (const k of RULE_KEYS) {
    const huidig = col[k] ?? null;
    const nieuw = metSlot(huidig);
    if (huidig === nieuw) {
      console.log(`✓ ${COLLECTIE}.${k}: het slot staat er al`);
      continue;
    }
    teDoen++;
    gewenst[k] = nieuw;
    console.log(`${APPLY ? '↻' : '+ ZOU'} ${COLLECTIE}.${k} bijwerken${APPLY ? '' : ' — dry-run'}`);
    console.log(`    was:   ${JSON.stringify(huidig)}`);
    console.log(`    wordt: ${JSON.stringify(nieuw)}`);
  }

  if (!teDoen) {
    console.log('\nNiets te doen: beide regels hebben het slot al.');
    return;
  }
  if (!APPLY) {
    console.log(`\nDRY-RUN: ${teDoen} regel(s) zouden worden bijgewerkt. Draai met --apply.`);
    return;
  }

  await pb.collections.update(col.id, gewenst);

  const na = await pb.collections.getOne(COLLECTIE);
  const mist = RULE_KEYS.filter((k) => !String(na[k] ?? '').includes(REPUTATIE_SLOT));
  if (mist.length) throw new Error(`Na apply mist het slot nog op: ${mist.join(', ')}`);
  console.log(`\n✓ ${teDoen} regel(s) bijgewerkt. Niemand kan de reputatievelden nog via de API zetten.`);
}

if (process.argv[1] && process.argv[1].endsWith('21-reputatie-rules.mjs')) {
  main().catch(fail);
}
