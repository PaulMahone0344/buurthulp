// HeitjeHulp M7 stap 1 — voegt ADDITIEF twee getalvelden toe aan hh_users:
// sterren_gemiddeld (0-5, één decimaal) en klussen_aantal (geheel, >= 0).
//
// WAAROM OP hh_users (backend OPEN-PUNT 12, optie a): hh_profielen heeft deze
// twee velden al, maar dat record is alleen leesbaar voor de eigenaar en de
// coordinator — er staan screening- en IBAN-gegevens in. De oudere moet de
// reputatie van ZIJN jongere kunnen zien, en hh_users is voor hem wél
// leesbaar zodra de jongere op zijn klus staat. Vandaar een kopie op
// hh_users. Een aparte collectie hh_reputatie (optie b) is niet gebouwd.
//
// Niemand zet deze velden via de API (dat doet 21-reputatie-rules.mjs);
// de hook backend/pb_hooks/hh_beoordelingen.pb.js rekent ze uit en schrijft
// ze via $app, dat niet langs de rules loopt.
//
// De velden zijn NIET verplicht: PocketBase leest 0 op een verplicht
// getalveld als leeg en weigert hem dan (memory reference_pb_jsvm_hooks 10).
// Een jongere zonder beoordelingen hoort 0 te kunnen hebben.
//
// Idempotent: een veld dat al bestaat wordt overgeslagen; bestaande velden
// worden nooit gewijzigd of verwijderd. Alleen op hh_users (hard-guard).
//
// DRAAIEN (eerst 00-backup.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/20-reputatie-velden.mjs          (dry-run: print wat er ZOU gebeuren)
//   node scripts/20-reputatie-velden.mjs --apply  (echt toevoegen)

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

const COLLECTIE = 'hh_users';

// Zelfde vorm als de twee velden die hh_profielen al heeft (01-collections),
// zodat de hook op beide collecties hetzelfde kan schrijven.
export const REPUTATIE_VELDEN = [
  { name: 'sterren_gemiddeld', type: 'number', min: 0, max: 5 },
  { name: 'klussen_aantal', type: 'number', onlyInt: true, min: 0 },
];

async function main() {
  assertHh(COLLECTIE);
  const pb = await superuserClient();
  logMode();

  const col = await pb.collections.getOne(COLLECTIE);
  const bestaand = new Set(col.fields.map((f) => f.name));
  const ontbreekt = REPUTATIE_VELDEN.filter((f) => !bestaand.has(f.name));

  for (const f of REPUTATIE_VELDEN) {
    if (bestaand.has(f.name)) console.log(`  ✓ bestaat al: ${COLLECTIE}.${f.name}`);
    else console.log(`  ${APPLY ? '＋ voeg toe' : '+ ZOU toevoegen'}: ${COLLECTIE}.${f.name} (number)`);
  }

  if (!ontbreekt.length) {
    console.log('\nNiets te doen: beide velden staan al op hh_users.');
    return;
  }
  if (!APPLY) {
    console.log(`\nDRY-RUN: ${ontbreekt.length} veld(en) zouden worden toegevoegd. Draai met --apply.`);
    return;
  }

  // Bestaande velden ongewijzigd meesturen; alleen de ontbrekende erbij.
  await pb.collections.update(col.id, { fields: [...col.fields, ...ontbreekt] });

  const na = await pb.collections.getOne(COLLECTIE);
  const naNamen = new Set(na.fields.map((f) => f.name));
  const mist = REPUTATIE_VELDEN.filter((f) => !naNamen.has(f.name)).map((f) => f.name);
  if (mist.length) throw new Error(`Na apply ontbreken nog: ${mist.join(', ')}`);
  console.log(`\n✓ ${ontbreekt.length} veld(en) toegevoegd; ${COLLECTIE} heeft nu ${na.fields.length} velden.`);
}

// Alleen draaien als dit script zelf wordt gestart (22 importeert de lijst).
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
