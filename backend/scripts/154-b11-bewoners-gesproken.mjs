// HeitjeHulp B11 stap 5 — DATAMIGRATIE (eigen JA): bestaande bewoners zonder
// kennismaking_status op "gesproken" zetten, zodat ze niet in de wachtrij
// "Nog bellen" komen en hun klussen gewoon gekeurd kunnen worden als
// b11_kennismaking_verplicht later aan gaat. Raakt alleen hh_users met rol
// hulpvrager en een LEGE kennismaking_status; zet kennismaking_status,
// kennismaking_op (nu) en kennismaking_notitie ("bestond al vóór B11").
// Geen kennismaking_door (niemand belde echt). Tweede run: niets te doen.
//
// DRAAIEN (na 150 --apply en 153; eerst 00-backup.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/154-b11-bewoners-gesproken.mjs            (dry-run: wie)
//   node scripts/154-b11-bewoners-gesproken.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

export const NOTITIE = 'bestond al vóór B11 (script 154)';

async function main() {
  const pb = await superuserClient();
  logMode();
  assertHh('hh_users');
  const lijst = await pb.collection('hh_users').getFullList({
    filter: 'rol = "hulpvrager" && kennismaking_status = ""',
    sort: 'created',
    fields: 'id,email,naam,created',
  });
  if (!lijst.length) {
    console.log('Niets te doen: elke bewoner heeft al een kennismaking_status.');
    return;
  }
  for (const u of lijst) console.log(`  ${APPLY ? '↻' : '+ ZOU'} ${u.email} (${u.naam}) -> gesproken`);
  if (!APPLY) {
    console.log(`\nDRY-RUN: ${lijst.length} bewoner(s). Draai met --apply (eigen JA: datamigratie).`);
    return;
  }
  const nu = new Date().toISOString().replace('T', ' ');
  for (const u of lijst) {
    await pb.collection('hh_users').update(u.id, { kennismaking_status: 'gesproken', kennismaking_op: nu, kennismaking_notitie: NOTITIE });
  }
  const rest = await pb.collection('hh_users').getList(1, 1, { filter: 'rol = "hulpvrager" && kennismaking_status = ""' });
  if (rest.totalItems) throw new Error(`Na apply nog ${rest.totalItems} bewoner(s) zonder status.`);
  console.log(`\nKlaar: ${lijst.length} bewoner(s) op gesproken.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
