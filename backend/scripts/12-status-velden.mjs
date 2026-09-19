// HeitjeHulp M6 stap 1 — voegt ADDITIEF één tekstveld toe aan hh_klus_status:
// toelichting (max 300). Daar komt de reden van een annulering in te staan
// (backend OPEN-PUNT 22). Niets anders wordt aangeraakt: geen bestaand veld,
// geen index, geen API-rule (die doet 13-status-rules.mjs).
//
// Idempotent: een veld dat al bestaat wordt overgeslagen; bestaande velden
// worden nooit gewijzigd of verwijderd. Alleen op hh_klus_status (hard-guard).
//
// DRAAIEN (eerst 00-backup.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/12-status-velden.mjs            (dry-run: print wat er ZOU gebeuren)
//   node scripts/12-status-velden.mjs --apply    (echt toevoegen)

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

const COLLECTIE = 'hh_klus_status';

// De reden van een annulering (M6, keuze 2). Niet verplicht: de gewone
// statuswissels (onderweg, bezig, afgerond) hebben geen toelichting.
export const STATUS_VELDEN = [{ name: 'toelichting', type: 'text', max: 300 }];

async function main() {
  assertHh(COLLECTIE);
  const pb = await superuserClient();
  logMode();

  const col = await pb.collections.getOne(COLLECTIE);
  const bestaand = new Set(col.fields.map((f) => f.name));
  const ontbreekt = STATUS_VELDEN.filter((f) => !bestaand.has(f.name));

  for (const f of STATUS_VELDEN) {
    if (bestaand.has(f.name)) console.log(`  ✓ bestaat al: ${COLLECTIE}.${f.name}`);
    else console.log(`  ${APPLY ? '＋ voeg toe' : '+ ZOU toevoegen'}: ${COLLECTIE}.${f.name} (text, max ${f.max})`);
  }

  if (!ontbreekt.length) {
    console.log('\nNiets te doen: het veld staat al op hh_klus_status.');
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
  const mist = STATUS_VELDEN.filter((f) => !naNamen.has(f.name)).map((f) => f.name);
  if (mist.length) throw new Error(`Na apply ontbreken nog: ${mist.join(', ')}`);
  console.log(`\n✓ ${ontbreekt.length} veld(en) toegevoegd; ${COLLECTIE} heeft nu ${na.fields.length} velden.`);
}

// Alleen draaien als dit script zelf wordt gestart (14 importeert STATUS_VELDEN).
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
