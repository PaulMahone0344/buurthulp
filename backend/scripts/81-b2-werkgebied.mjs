// HeitjeHulp B2 stap 1 — werkgebied "Tiel en omstreken" (besluit Ibrahim
// 3 okt: Tiel en alle dorpen binnen 20 km). ADDITIEF en idempotent; alleen
// hh_-collecties (hard-guard). Bestaande wijken (Tiel-West, Passewaaij)
// blijven staan en geldig; er wordt niets aan bestaande rijen veranderd.
//
//   hh_wijken  + regio              ja/nee. Ja = deze wijk dekt de regio
//                                   rond de gemeente: past bij elke wijk in
//                                   dezelfde gemeente (lijst-rule 80 en
//                                   accepteren). Bestaande rijen: leeg = nee.
//   hh_users   + werkgebied_status  keuze binnen | buiten | onbekend. Zet de
//                                   server bij aanmelden (hh_aanmelden.pb.js,
//                                   Nominatim). onbekend = geocoding mislukt:
//                                   de markering voor de meldkamer. Leeg =
//                                   nooit bepaald (bestaande accounts).
//   hh_wijken  + rij  gemeente "Tiel", wijk "Tiel en omstreken", actief,
//                     regio = ja, postcodes [] (de straal telt, niet de lijst)
//
// VOLGORDE: vóór 80 (80 zet rules op regio en werkgebied_status; PocketBase
// weigert een rule op een onbekend veld).
//
// DRAAIEN (eerst 00-backup.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/81-b2-werkgebied.mjs            (dry-run)
//   node scripts/81-b2-werkgebied.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

export const WERKGEBIED_STATUSSEN = ['binnen', 'buiten', 'onbekend'];

export const B2_VELDEN = {
  hh_wijken: [{ name: 'regio', type: 'bool' }],
  hh_users: [{ name: 'werkgebied_status', type: 'select', values: WERKGEBIED_STATUSSEN, maxSelect: 1 }],
};

/// Moet gelijk zijn aan WERKGEBIEDEN in pb_hooks/hh_aanmelden_hulp.js
/// (getest in backend/tests/b2_rules.test.mjs).
export const REGIO_WIJK = { gemeente: 'Tiel', wijk: 'Tiel en omstreken', postcodes: [], actief: true, regio: true };

async function velden(pb) {
  let teDoen = 0;
  for (const [naam, gewenst] of Object.entries(B2_VELDEN)) {
    const col = await pb.collections.getOne(assertHh(naam));
    const bestaand = new Map(col.fields.map((f) => [f.name, f]));
    const ontbreekt = [];
    for (const f of gewenst) {
      const er = bestaand.get(f.name);
      if (er) {
        console.log(`  ✓ bestaat al: ${naam}.${f.name} (${er.type})${er.type === f.type ? '' : ` — LET OP: verwacht ${f.type}`}`);
        continue;
      }
      ontbreekt.push(f);
      console.log(`  ${APPLY ? '＋ voeg toe' : '+ ZOU toevoegen'}: ${naam}.${f.name} (${f.type}${f.values ? `: ${f.values.join(' | ')}` : ''})`);
    }
    teDoen += ontbreekt.length;
    if (!ontbreekt.length || !APPLY) continue;
    await pb.collections.update(col.id, { fields: [...col.fields, ...ontbreekt] });
    const na = new Set((await pb.collections.getOne(naam)).fields.map((f) => f.name));
    const mist = ontbreekt.filter((f) => !na.has(f.name)).map((f) => f.name);
    if (mist.length) throw new Error(`Na apply ontbreken nog op ${naam}: ${mist.join(', ')}`);
  }
  return teDoen;
}

async function regioWijk(pb) {
  const rijen = await pb.collection('hh_wijken').getFullList({
    filter: pb.filter('gemeente = {:g} && wijk = {:w}', { g: REGIO_WIJK.gemeente, w: REGIO_WIJK.wijk }),
  });
  if (rijen.length) {
    const r = rijen[0];
    const goed = r.actief === true && r.regio === true;
    console.log(`  ✓ wijk "${REGIO_WIJK.wijk}" bestaat al (${r.id})${goed ? '' : ' — LET OP: niet actief of geen regio, niet aangepast'}`);
    return 0;
  }
  console.log(`  ${APPLY ? '＋ maak aan' : '+ ZOU aanmaken'}: hh_wijken "${REGIO_WIJK.gemeente} / ${REGIO_WIJK.wijk}" (actief, regio)`);
  if (APPLY) {
    const nieuw = await pb.collection(assertHh('hh_wijken')).create(REGIO_WIJK);
    console.log(`    id ${nieuw.id}`);
  }
  return 1;
}

async function main() {
  const pb = await superuserClient();
  logMode();
  const aantalVelden = await velden(pb);
  // In een dry-run kan de rij nog niet met regio: het veld bestaat dan nog niet.
  const aantalRijen = await regioWijk(pb);
  const totaal = aantalVelden + aantalRijen;
  if (!totaal) console.log('\nNiets te doen: alles staat er al.');
  else if (!APPLY) console.log(`\nDRY-RUN: ${aantalVelden} veld(en) en ${aantalRijen} wijk zouden erbij komen. Draai met --apply.`);
  else console.log(`\n✓ ${aantalVelden} veld(en) en ${aantalRijen} wijk toegevoegd. Draai nu 80-b2-rules.mjs.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
