// HeitjeHulp M4 stap 2 — bewijst de adresvelden op hh_users met de ECHTE
// seed-accounts (backend/seed-accounts.local.json, nooit loggen):
//   1. de seed-oudere zet adres/postcode/plaats/contact zelf (zonder rol),
//      leest terug, en zet daarna alles terug naar de oude waarden;
//   2. een jongere ziet het adres van een oudere NIET, tenzij hij op een klus
//      van die oudere is toegewezen (bestaande rule uit M1; alleen bewijzen);
//   3. een andere oudere kan het adres van oudere 1 niet wijzigen.
// Wijzigt geen rules. Herhaalbaar: eindigt met de seedwaarden zoals ze waren.
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/09-adrescheck.mjs --apply     (zonder --apply: alleen uitleg)

import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, userClient, assertHh, APPLY, fail, PB_URL } from './_lib.mjs';
import { ADRES_VELDEN } from './08-adres-velden.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ACCOUNTS_FILE = path.resolve(__dirname, '..', 'seed-accounts.local.json');
const COLLECTIE = 'hh_users';

const TESTWAARDEN = {
  adres: 'Adrescheckstraat 9',
  postcode: '4003 AC',
  plaats: 'Tiel',
  contact_naam: 'Contact Adrescheck',
  contact_telefoon: '0612-000009',
};

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
async function magNiet(label, fn, codes = [400, 403, 404]) {
  try {
    await fn();
    check(label, false, 'ging onverwacht door');
  } catch (e) {
    check(`${label} (${e?.status})`, codes.includes(e?.status), `status=${e?.status} ${e?.response?.message ?? ''}`);
  }
}

async function main() {
  assertHh(COLLECTIE);
  if (!APPLY) {
    console.log('DRY-RUN: dit script logt in als seed-oudere 1, zet tijdelijk een testadres op haar eigen hh_users-rij,');
    console.log('leest terug, bewijst dat jongere 3 (nooit toegewezen) het niet ziet en jongere 1 (toegewezen) wel,');
    console.log('en zet de oude waarden terug. Zonder --apply gebeurt er niets. Draai met --apply.');
    return;
  }
  if (!existsSync(ACCOUNTS_FILE)) throw new Error(`${ACCOUNTS_FILE} ontbreekt — draai eerst 03-seed.mjs --apply`);
  const acc = JSON.parse(readFileSync(ACCOUNTS_FILE, 'utf8'));

  const su = await superuserClient();
  console.log('Verbonden met', PB_URL, '\n');

  console.log('A. Schema');
  const col = await su.collections.getOne(COLLECTIE);
  const namen = new Set(col.fields.map((f) => f.name));
  for (const f of ADRES_VELDEN) {
    const echt = col.fields.find((x) => x.name === f.name);
    check(`hh_users.${f.name} bestaat als text, max ${f.max}`, namen.has(f.name) && echt?.type === 'text' && echt?.max === f.max, echt ? `${echt.type} max ${echt.max}` : 'ontbreekt');
  }

  const hv1Id = acc.hulpvrager1.id;
  const hv1 = await userClient(acc.hulpvrager1.email, acc.hulpvrager1.password);
  const hv2 = await userClient(acc.hulpvrager2.email, acc.hulpvrager2.password);
  const j1 = await userClient(acc.jongere1.email, acc.jongere1.password);
  const j3 = await userClient(acc.jongere3.email, acc.jongere3.password);

  // Oude waarden bewaren om ze aan het eind terug te zetten.
  const voor = await su.collection(COLLECTIE).getOne(hv1Id);
  const oud = Object.fromEntries(ADRES_VELDEN.map((f) => [f.name, voor[f.name] ?? '']));

  try {
    console.log('\nB. Oudere 1 zet en leest eigen adres en contactpersoon');
    let upd = null;
    try {
      upd = await hv1.collection(COLLECTIE).update(hv1Id, TESTWAARDEN);
      check('oudere 1 kan eigen adres + contact zetten (zonder rol mee te sturen)', true);
    } catch (e) {
      check('oudere 1 kan eigen adres + contact zetten (zonder rol mee te sturen)', false, `status=${e?.status} ${JSON.stringify(e?.response?.data ?? '')}`);
    }
    const terug = await hv1.collection(COLLECTIE).getOne(hv1Id);
    for (const [k, v] of Object.entries(TESTWAARDEN)) {
      check(`oudere 1 leest ${k} terug`, terug[k] === v, `kreeg "${terug[k]}"`);
    }
    check('update-antwoord bevat de nieuwe waarden', !!upd && upd.adres === TESTWAARDEN.adres);
    await magNiet('oudere 1 kan adres niet samen met rol meesturen (:isset)', () => hv1.collection(COLLECTIE).update(hv1Id, { adres: 'x', rol: 'hulpvrager' }));
    await magNiet('postcode langer dan 7 tekens wordt geweigerd', () => hv1.collection(COLLECTIE).update(hv1Id, { postcode: '4003 ABCD' }), [400]);

    console.log('\nC. Wie ziet het adres van oudere 1 (bestaande rule, alleen bewijzen)');
    await magNiet('jongere 3 (nooit toegewezen) kan oudere 1 niet bekijken', () => j3.collection(COLLECTIE).getOne(hv1Id));
    const lijstJ3 = await j3.collection(COLLECTIE).getFullList();
    check('jongere 3: oudere 1 staat niet in de lijst', !lijstJ3.some((r) => r.id === hv1Id));
    const viaJ1 = await j1.collection(COLLECTIE).getOne(hv1Id);
    check('jongere 1 (toegewezen op k04/k07) ziet adres van oudere 1', viaJ1.adres === TESTWAARDEN.adres, `kreeg "${viaJ1.adres}"`);
    await magNiet('oudere 2 kan oudere 1 niet bekijken', () => hv2.collection(COLLECTIE).getOne(hv1Id));

    console.log('\nD. Wie mag het adres van oudere 1 wijzigen');
    await magNiet('oudere 2 kan adres van oudere 1 niet wijzigen', () => hv2.collection(COLLECTIE).update(hv1Id, { adres: 'Inbraakstraat 1' }));
    await magNiet('jongere 1 kan adres van oudere 1 niet wijzigen (ook al ziet hij het)', () => j1.collection(COLLECTIE).update(hv1Id, { adres: 'Inbraakstraat 1' }));
    const nogSteeds = await su.collection(COLLECTIE).getOne(hv1Id);
    check('adres is na de weigeringen ongewijzigd', nogSteeds.adres === TESTWAARDEN.adres);
  } finally {
    // Terugzetten via de oudere zelf (bewijst partieel bijwerken), met de superuser als vangnet.
    try {
      await hv1.collection(COLLECTIE).update(hv1Id, oud);
    } catch {
      await su.collection(COLLECTIE).update(hv1Id, oud);
    }
    const eind = await su.collection(COLLECTIE).getOne(hv1Id);
    const hersteld = ADRES_VELDEN.every((f) => (eind[f.name] ?? '') === oud[f.name]);
    check('seedwaarden van oudere 1 teruggezet', hersteld);
  }

  console.log(`\n${groen} groen, ${rood} rood (${groen + rood} checks).`);
  if (rood > 0) process.exit(1);
}

main().catch(fail);
