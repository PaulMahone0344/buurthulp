// HeitjeHulp M9 stap 1 — voegt ADDITIEF één keuzeveld toe aan hh_koppelingen:
//   status  keuze (één): aangevraagd | actief
//
// Daarmee wordt de koppeling-met-toestemming mogelijk (backend OPEN-PUNT 19):
// het familielid vraagt aan (status aangevraagd, rechten leeg), de oudere zegt
// Ja (status actief, rechten meekijken + plaatsen) of Nee (koppeling weg).
//
// Twee dingen, in deze volgorde:
//   1. het veld toevoegen als het nog niet bestaat;
//   2. elke BESTAANDE koppeling die nog geen status heeft op "actief" zetten.
//      PocketBase kent geen standaardwaarde op een keuzeveld, dus bestaande
//      rijen krijgen een lege status. Zou die leeg blijven, dan zou de
//      aangescherpte rule uit 41 de seed-koppeling meteen dichtzetten en zou
//      familielid 1 zijn oudere kwijt zijn. Daarom hier de terugvulling.
//
// Idempotent: een bestaand veld wordt overgeslagen, bestaande velden worden
// nooit gewijzigd of verwijderd, en een koppeling die al een status heeft
// blijft ongemoeid. Alleen op hh_koppelingen (hard-guard).
//
// LET OP de volgorde bij het uitrollen: 40 --apply moet VÓÓR 41 --apply, anders
// staat de rule al te eisen dat status "actief" is terwijl het veld nog leeg is.
//
// DRAAIEN (eerst 00-backup.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/40-familie-velden.mjs            (dry-run: print wat er ZOU gebeuren)
//   node scripts/40-familie-velden.mjs --apply    (echt toevoegen en terugvullen)

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

const COLLECTIE = 'hh_koppelingen';

export const STATUS_AANGEVRAAGD = 'aangevraagd';
export const STATUS_ACTIEF = 'actief';

// Eén keuze tegelijk (maxSelect 1); niet verplicht, want PocketBase weigert bij
// een verplicht keuzeveld een create zonder waarde en de rules/hook zetten hem
// altijd zelf.
export const KOPPELING_VELDEN = [
  {
    name: 'status',
    type: 'select',
    required: false,
    maxSelect: 1,
    values: [STATUS_AANGEVRAAGD, STATUS_ACTIEF],
  },
];

async function main() {
  assertHh(COLLECTIE);
  const pb = await superuserClient();
  logMode();

  const col = await pb.collections.getOne(COLLECTIE);
  const bestaand = new Set(col.fields.map((f) => f.name));
  const ontbreekt = KOPPELING_VELDEN.filter((f) => !bestaand.has(f.name));

  for (const f of KOPPELING_VELDEN) {
    if (bestaand.has(f.name)) console.log(`  ✓ bestaat al: ${COLLECTIE}.${f.name}`);
    else
      console.log(
        `  ${APPLY ? '＋ voeg toe' : '+ ZOU toevoegen'}: ${COLLECTIE}.${f.name} (select, één uit ${f.values.join(' | ')})`,
      );
  }

  if (ontbreekt.length) {
    if (!APPLY) {
      console.log(`\nDRY-RUN: ${ontbreekt.length} veld(en) zouden worden toegevoegd.`);
    } else {
      // Bestaande velden ongewijzigd meesturen; alleen de ontbrekende erbij.
      await pb.collections.update(col.id, { fields: [...col.fields, ...ontbreekt] });
      const na = await pb.collections.getOne(COLLECTIE);
      const naNamen = new Set(na.fields.map((f) => f.name));
      const mist = KOPPELING_VELDEN.filter((f) => !naNamen.has(f.name)).map((f) => f.name);
      if (mist.length) throw new Error(`Na apply ontbreken nog: ${mist.join(', ')}`);
      console.log(`\n✓ ${ontbreekt.length} veld(en) toegevoegd; ${COLLECTIE} heeft nu ${na.fields.length} velden.`);
    }
  } else {
    console.log('\nHet veld status staat al op hh_koppelingen.');
  }

  // --- Terugvullen: elke koppeling zonder status wordt actief ---------------
  const alle = await pb.collection(COLLECTIE).getFullList({ sort: 'created' });
  const zonder = alle.filter((k) => !String(k.status || '').trim());
  console.log(`\n${alle.length} koppeling(en); ${zonder.length} zonder status.`);
  for (const k of zonder) {
    console.log(`  ${APPLY ? '↻ zet' : '+ ZOU zetten'}: koppeling ${k.id} -> status ${STATUS_ACTIEF}`);
    if (APPLY) await pb.collection(assertHh(COLLECTIE)).update(k.id, { status: STATUS_ACTIEF });
  }

  if (!APPLY) {
    console.log('\nDRY-RUN klaar. Niets geschreven. Draai met --apply.');
    return;
  }

  // Nameten: geen enkele koppeling mag nog een lege status hebben.
  const na = await pb.collection(COLLECTIE).getFullList();
  const nogLeeg = na.filter((k) => !String(k.status || '').trim());
  if (nogLeeg.length) throw new Error(`Na apply hebben ${nogLeeg.length} koppeling(en) nog een lege status.`);
  const actief = na.filter((k) => k.status === STATUS_ACTIEF).length;
  console.log(`\n✓ Klaar. ${na.length} koppeling(en), waarvan ${actief} actief, geen enkele leeg.`);
}

// Alleen draaien als dit script zelf wordt gestart (42 importeert de constanten).
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
