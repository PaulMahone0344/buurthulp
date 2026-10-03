// HeitjeHulp B1 stap 1 — velden voor model B (helper met ouder-toestemming,
// ID-controle zonder het document te bewaren). ADDITIEF en idempotent: wat er
// al staat wordt overgeslagen, bestaande velden worden nooit gewijzigd of
// verwijderd. Alleen hh_-collecties (hard-guard).
//
// BESLUIT 3 OKT (Ibrahim): de rolcodes blijven (hulpvrager, jongere, familie,
// coordinator). Velden verwijderen (selfie, intake_op, telefoon, vog_status)
// gebeurt NIET in B1: de app gebruikt ze nog; dat volgt na B2.
//
//   hh_users      + ouder_email          e-mail (helper <18: e-mail van de ouder)
//                 + ouder_telefoon       tekst, max 20 (of het nummer van de ouder)
//                 + ouder_toestemming_op datum (ouder gaf toestemming; alleen
//                                        coordinator/server, zie 71)
//                 + ouder_iban_ok        ja/nee (ouder keurde het uitbetaal-
//                                        rekeningnummer goed; alleen coordinator)
//                 + huisnummer           tekst, max 10 (postcode + huisnummer)
//                 (adres, postcode, plaats bestaan sinds M4; geboortedatum
//                 sinds M1 — die worden overgeslagen)
//   hh_profielen  + id_gecontroleerd_op   datum (alleen coordinator; de hook
//                                         zet hem bij goedkeuren)
//                 + id_gecontroleerd_door verwijzing naar hh_users (idem)
//                 + vog_gezien_op         datum (helper 18+: alleen de datum,
//                                         niet het document; alleen coordinator)
//
// DRAAIEN (eerst 00-backup.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/70-b1-velden.mjs            (dry-run)
//   node scripts/70-b1-velden.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

/// Velden die er al moeten zijn (eerdere milestones). Alleen ter controle.
export const AL_AANWEZIG = {
  hh_users: ['geboortedatum', 'adres', 'postcode', 'plaats'],
};

/// Nieuwe velden per collectie. ids = { hh_users: '<collectie-id>' }.
export function b1Velden(ids) {
  return {
    hh_users: [
      { name: 'ouder_email', type: 'email' },
      { name: 'ouder_telefoon', type: 'text', max: 20 },
      { name: 'ouder_toestemming_op', type: 'date' },
      { name: 'ouder_iban_ok', type: 'bool' },
      { name: 'huisnummer', type: 'text', max: 10 },
    ],
    hh_profielen: [
      { name: 'id_gecontroleerd_op', type: 'date' },
      // Geen cascade: verdwijnt de coordinator, dan blijft het profiel staan
      // (PocketBase maakt de verwijzing dan leeg).
      {
        name: 'id_gecontroleerd_door',
        type: 'relation',
        collectionId: ids.hh_users,
        maxSelect: 1,
        cascadeDelete: false,
      },
      { name: 'vog_gezien_op', type: 'date' },
    ],
  };
}

/// Namen van de nieuwe velden, zonder server (voor 71 en 72).
export const B1_VELDNAMEN = {
  hh_users: ['ouder_email', 'ouder_telefoon', 'ouder_toestemming_op', 'ouder_iban_ok', 'huisnummer'],
  hh_profielen: ['id_gecontroleerd_op', 'id_gecontroleerd_door', 'vog_gezien_op'],
};

async function main() {
  const pb = await superuserClient();
  logMode();
  const users = await pb.collections.getOne(assertHh('hh_users'));
  let teDoen = 0;

  for (const [naam, namen] of Object.entries(AL_AANWEZIG)) {
    const col = naam === 'hh_users' ? users : await pb.collections.getOne(assertHh(naam));
    const bestaand = new Set(col.fields.map((f) => f.name));
    for (const n of namen) {
      console.log(bestaand.has(n) ? `  ✓ bestaat al (eerdere milestone): ${naam}.${n}` : `  ! ONTBREEKT (verwacht): ${naam}.${n}`);
    }
  }

  for (const [naam, gewenst] of Object.entries(b1Velden({ hh_users: users.id }))) {
    assertHh(naam);
    const col = await pb.collections.getOne(naam);
    const bestaand = new Map(col.fields.map((f) => [f.name, f]));
    const ontbreekt = [];
    for (const f of gewenst) {
      const er = bestaand.get(f.name);
      if (er) {
        const zelfde = er.type === f.type;
        console.log(`  ✓ bestaat al: ${naam}.${f.name} (${er.type})${zelfde ? '' : ` — LET OP: verwacht ${f.type}, niet aangepast`}`);
        continue;
      }
      ontbreekt.push(f);
      const extra = f.max ? `, max ${f.max}` : f.type === 'relation' ? ', -> hh_users, 1, geen cascade' : '';
      console.log(`  ${APPLY ? '＋ voeg toe' : '+ ZOU toevoegen'}: ${naam}.${f.name} (${f.type}${extra})`);
    }
    if (!ontbreekt.length) continue;
    teDoen += ontbreekt.length;
    if (!APPLY) continue;
    await pb.collections.update(col.id, { fields: [...col.fields, ...ontbreekt] });
    const na = await pb.collections.getOne(naam);
    const naNamen = new Set(na.fields.map((f) => f.name));
    const mist = ontbreekt.filter((f) => !naNamen.has(f.name)).map((f) => f.name);
    if (mist.length) throw new Error(`Na apply ontbreken nog op ${naam}: ${mist.join(', ')}`);
  }

  if (!teDoen) console.log('\nNiets te doen: alles staat er al.');
  else if (!APPLY) console.log(`\nDRY-RUN: ${teDoen} veld(en) zouden worden toegevoegd. Draai met --apply.`);
  else console.log(`\n✓ ${teDoen} veld(en) toegevoegd. Draai nu 71-b1-rules.mjs.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
