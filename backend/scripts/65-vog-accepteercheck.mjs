// HeitjeHulp — bewijst de VOG-check in POST /api/hh/klussen/{id}/accepteren
// (backend/pb_hooks/hh_klussen.pb.js) op de ECHTE server met seed-jongere 1
// en seed-klus k11 (backend/seed-accounts.local.json, nooit loggen):
//   A. terugzetten: k11 open zonder jongere, accepteer-logregels weg
//   B. VOG verlopen (2020-01-01) -> 403 reden vogverlopen, eigen melding;
//      k11 blijft open, geen logregel
//   C. VOG geldig tot VANDAAG -> 200 (de dag zelf telt nog mee)
//   D. VOG leeg -> 200 (geen datum bekend = niet verlopen)
//   E. terugzetten: oorspronkelijke vog_geldig_tot terug, k11 weer open
//
// Wijzigt geen rules. Herhaalbaar. Zet altijd terug, ook als een check faalt.
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/65-vog-accepteercheck.mjs --apply   (zonder --apply: alleen uitleg)

import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, userClient, assertHh, APPLY, fail, PB_URL } from './_lib.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ACCOUNTS_FILE = path.resolve(__dirname, '..', 'seed-accounts.local.json');
const ROUTE = (id) => `/api/hh/klussen/${id}/accepteren`;
const MELDING_VOG =
  'Je VOG is verlopen. Vraag de coördinator naar een nieuwe VOG; tot die tijd kun je geen klussen aannemen.';

let groen = 0;
let rood = 0;
function check(label, ok, detail) {
  if (ok) {
    groen++;
    console.log(`  ✓ ${label}`);
  } else {
    rood++;
    console.log(`  ✗ ${label}${detail ? ` — ${detail}` : ''}`);
  }
}
function kop(t) {
  console.log(`\n${t}`);
}

async function accepteer(client, klusId) {
  try {
    const body = await client.send(ROUTE(klusId), { method: 'POST' });
    return { status: 200, body };
  } catch (e) {
    return { status: e?.status ?? 0, body: e?.response ?? {} };
  }
}

async function zetKlusTerug(su, klus) {
  const nu = await su.collection('hh_klussen').getOne(klus.id);
  if (nu.status !== 'open' || nu.toegewezen_jongere) {
    await su.collection(assertHh('hh_klussen')).update(klus.id, { status: 'open', toegewezen_jongere: '' });
  }
  const logs = await su
    .collection('hh_klus_status')
    .getFullList({ filter: `klus = "${klus.id}" && naar = "geaccepteerd"` });
  for (const log of logs) await su.collection(assertHh('hh_klus_status')).delete(log.id);
}

const vandaagMiddag = () => `${new Date().toISOString().slice(0, 10)} 12:00:00.000Z`;

async function main() {
  assertHh('hh_klussen');
  assertHh('hh_klus_status');
  assertHh('hh_profielen');
  if (!APPLY) {
    console.log('DRY-RUN: zet vog_geldig_tot van seed-jongere 1 tijdelijk op verlopen / vandaag / leeg en');
    console.log('laat hem seed-klus k11 accepteren (403 vogverlopen / 200 / 200). Alles wordt teruggezet.');
    console.log('Zonder --apply gebeurt er niets. Draai met --apply.');
    return;
  }
  if (!existsSync(ACCOUNTS_FILE)) throw new Error(`${ACCOUNTS_FILE} ontbreekt — kopieer hem uit de hoofdmap`);
  const acc = JSON.parse(readFileSync(ACCOUNTS_FILE, 'utf8'));

  const su = await superuserClient();
  console.log('Verbonden met', PB_URL);

  const k11 = await su.collection('hh_klussen').getFirstListItem('omschrijving ~ "[seed k11]"');
  const profiel = await su
    .collection('hh_profielen')
    .getFirstListItem(su.filter('gebruiker = {:id}', { id: acc.jongere1.id }));
  const origineel = profiel.vog_geldig_tot || '';
  const j1 = await userClient(acc.jongere1.email, acc.jongere1.password);

  try {
    kop('A. Terugzetten (begin)');
    await zetKlusTerug(su, k11);
    check('k11 staat op open zonder jongere', true);

    kop('B. VOG verlopen');
    {
      await su.collection(assertHh('hh_profielen')).update(profiel.id, { vog_geldig_tot: '2020-01-01 12:00:00.000Z' });
      const r = await accepteer(j1, k11.id);
      check(`accepteren -> 403 vogverlopen (kreeg ${r.status} ${r.body?.reden})`, r.status === 403 && r.body?.reden === 'vogverlopen');
      check('melding voor de jongere klopt', r.body?.melding === MELDING_VOG, r.body?.melding);
      const klus = await su.collection('hh_klussen').getOne(k11.id);
      check('k11 is nog open zonder jongere', klus.status === 'open' && !klus.toegewezen_jongere);
      const logs = await su.collection('hh_klus_status').getFullList({ filter: `klus = "${k11.id}" && naar = "geaccepteerd"` });
      check('geen accepteer-logregel geschreven', logs.length === 0);
    }

    kop('C. VOG geldig tot vandaag');
    {
      await su.collection(assertHh('hh_profielen')).update(profiel.id, { vog_geldig_tot: vandaagMiddag() });
      const r = await accepteer(j1, k11.id);
      check(`accepteren -> 200 (kreeg ${r.status})`, r.status === 200 && r.body?.status === 'geaccepteerd', JSON.stringify(r.body));
      await zetKlusTerug(su, k11);
    }

    kop('D. VOG leeg');
    {
      await su.collection(assertHh('hh_profielen')).update(profiel.id, { vog_geldig_tot: '' });
      const r = await accepteer(j1, k11.id);
      check(`accepteren -> 200 (kreeg ${r.status})`, r.status === 200 && r.body?.status === 'geaccepteerd', JSON.stringify(r.body));
    }
  } finally {
    kop('E. Terugzetten (einde)');
    await su.collection(assertHh('hh_profielen')).update(profiel.id, { vog_geldig_tot: origineel });
    await zetKlusTerug(su, k11);
    const p = await su.collection('hh_profielen').getOne(profiel.id);
    check('vog_geldig_tot van jongere 1 terug zoals het was', (p.vog_geldig_tot || '') === origineel);
    const klus = await su.collection('hh_klussen').getOne(k11.id);
    check('k11 weer open zonder jongere', klus.status === 'open' && !klus.toegewezen_jongere);
  }

  console.log(`\n${groen} groen, ${rood} rood (${groen + rood} checks).`);
  if (rood > 0) process.exit(1);
}

main().catch(fail);
