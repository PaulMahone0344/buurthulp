// HeitjeHulp B2 — "VOG gezien op" voor de seed-helpers (besluit Ibrahim
// 3 okt: JA). De 3 seed-helpers (jongere1-3 in seed-accounts.local.json) zijn
// alle drie 18+. Sinds B2 zien zij zonder vog_gezien_op geen open klussen en
// weigert accepteren (403 vog); dan worden 04-rulecheck en 50-koppelcheck
// rood. Dit script zet vog_gezien_op = nu op hun profiel. ALLEEN deze 3
// accounts (ids uit het seed-bestand, rol jongere op de server), alleen als
// het veld nog leeg is. Geen e-mailadressen of wachtwoorden in de uitvoer.
//
// VOLGORDE: na 80 (en na B1: het veld vog_gezien_op bestaat sinds 70).
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/84-seed-vog.mjs            (dry-run)
//   node scripts/84-seed-vog.mjs --apply

import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ACCOUNTS_FILE = path.resolve(__dirname, '..', 'seed-accounts.local.json');

/// De seed-helpers uit het bestand: [{ sleutel, id }]. Puur, getest.
export function seedHelpers(accounts) {
  return Object.entries(accounts || {})
    .filter(([sleutel, a]) => /^jongere\d+$/.test(sleutel) && a && a.rol === 'jongere' && a.id)
    .map(([sleutel, a]) => ({ sleutel, id: String(a.id) }))
    .sort((a, b) => a.sleutel.localeCompare(b.sleutel));
}

async function main() {
  const accounts = JSON.parse(readFileSync(ACCOUNTS_FILE, 'utf8'));
  const helpers = seedHelpers(accounts);
  if (helpers.length !== 3) throw new Error(`Verwacht 3 seed-helpers, gevonden ${helpers.length} — niets gedaan.`);
  const pb = await superuserClient();
  logMode();
  const nu = new Date().toISOString().replace('T', ' ');
  let teDoen = 0;
  for (const h of helpers) {
    const user = await pb.collection('hh_users').getOne(h.id);
    if (user.rol !== 'jongere') throw new Error(`${h.sleutel}: rol op de server is "${user.rol}", geen jongere — gestopt.`);
    const profielen = await pb.collection('hh_profielen').getFullList({ filter: pb.filter('gebruiker = {:id}', { id: h.id }) });
    if (profielen.length !== 1) {
      console.log(`  ! ${h.sleutel}: ${profielen.length} profiel(en), overgeslagen`);
      continue;
    }
    const p = profielen[0];
    if (p.vog_gezien_op) {
      console.log(`  ✓ ${h.sleutel}: vog_gezien_op staat al (${String(p.vog_gezien_op).slice(0, 10)})`);
      continue;
    }
    teDoen++;
    console.log(`  ${APPLY ? '↻ zet' : '+ ZOU zetten'}: ${h.sleutel} vog_gezien_op = vandaag (status ${p.verificatiestatus || 'leeg'})`);
    if (APPLY) await pb.collection(assertHh('hh_profielen')).update(p.id, { vog_gezien_op: nu });
  }
  if (!teDoen) console.log('\nNiets te doen.');
  else if (!APPLY) console.log(`\nDRY-RUN: ${teDoen} profiel(en) zouden vog_gezien_op krijgen. Draai met --apply.`);
  else console.log(`\n✓ ${teDoen} profiel(en) bijgewerkt.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
