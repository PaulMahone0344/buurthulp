// HeitjeHulp M9 — bewijst de familie-koppeling met toestemming en de rechten op
// de ECHTE server. Werkt met TIJDELIJKE accounts (e-mail
// "familiecheck-...@heitjehulp.invalid", door de superuser gemaakt en
// bevestigd) en eigen klussen met het merk "[familiecheck]"; alleen
// familielid 1 uit de seed doet mee (backend/seed-accounts.local.json, nooit
// loggen). Alles wordt aan het eind opgeruimd.
//
//   A. opruimen van een eerdere (gecrashte) run
//   B. voorwaarden (ook in dry-run): veld status, geen koppeling zonder
//      status, de wikkel van 41 staat in de rules, de route bestaat (401)
//   C. aanvraag: hetzelfde antwoord voor een bekend en een onbekend adres
//   D. "aangevraagd" geeft NOG GEEN toegang: klussen, hh_users en logregels
//      van de oudere blijven dicht
//   E. het familielid kan zijn eigen koppeling niet op actief zetten of
//      rechten geven; de oudere ziet de vraag en wie het vraagt
//   F. na "Ja" wel toegang (en beide rechten via de hook)
//   G. zonder recht plaatsen -> klus aanmaken geweigerd; met -> mag
//   H. het familielid ziet de jongere op de klus van zijn oudere, en geen
//      andere jongere of andere oudere
//   I. geen lek via een ANDER familielid: een aanvraag bij oudere B geeft
//      geen toegang, ook al heeft B een ander, actief familielid
//   J. "Nee": de oudere haalt de aanvraag weg
//   K. hooguit 5 aanvragen per dag (met een vers familielid)
//   L. opruimen en nameten
//
// DRAAIEN (na 40 --apply, 41 --apply en 43-hook-deploy.sh):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/42-familiecheck.mjs            (dry-run: alleen leescontroles)
//   node scripts/42-familiecheck.mjs --apply
//   node scripts/42-familiecheck.mjs --apply --alleen-opruimen

import { randomBytes } from 'node:crypto';
import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, userClient, anonClient, assertHh, APPLY, fail, PB_URL } from './_lib.mjs';
import { STATUS_ACTIEF, STATUS_AANGEVRAAGD } from './40-familie-velden.mjs';
import { ACTIEF, JONGERE_VAN_MIJN_OUDERE } from './41-familie-rules.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ACCOUNTS_FILE = path.resolve(__dirname, '..', 'seed-accounts.local.json');
const MERK = '[familiecheck]';
const MAIL_PREFIX = 'familiecheck-';
const MAIL_DOMEIN = '@heitjehulp.invalid';
const ROUTE = '/api/hh/koppelingen/aanvragen';
const ALLEEN_OPRUIMEN = process.argv.includes('--alleen-opruimen');

const ADRES = 'Prins Bernhardlaan 12, 4003 AB Tiel';
const LAT = 51.8865;
const LON = 5.4126;

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

async function probeer(actie) {
  try {
    return { status: 200, record: await actie() };
  } catch (e) {
    return { status: e?.status ?? 0, record: null, body: e?.response ?? {} };
  }
}

async function aanvraag(client, email) {
  try {
    const body = await client.send(ROUTE, { method: 'POST', body: { email_oudere: email } });
    return { status: 200, body };
  } catch (e) {
    return { status: e?.status ?? 0, body: e?.response ?? {} };
  }
}

async function opruimen(su) {
  const klussen = await su.collection('hh_klussen').getFullList({
    filter: su.filter('omschrijving ~ {:merk}', { merk: MERK }),
  });
  for (const k of klussen) await su.collection(assertHh('hh_klussen')).delete(k.id);
  const tijdelijk = await su.collection('hh_users').getFullList({
    filter: su.filter('email ~ {:prefix}', { prefix: MAIL_PREFIX }),
  });
  // Koppelingen verdwijnen mee met de gebruiker; die van familielid 1 naar
  // een tijdelijke oudere dus ook.
  for (const u of tijdelijk) await su.collection(assertHh('hh_users')).delete(u.id);
  if (klussen.length || tijdelijk.length) {
    console.log(`  ↻ ${klussen.length} klus(sen) en ${tijdelijk.length} tijdelijk(e) account(s) verwijderd`);
  }
}

async function voorwaarden(su) {
  kop('B. Voorwaarden op de server (alleen lezen)');
  const col = await su.collections.getOne('hh_koppelingen');
  const status = col.fields.find((f) => f.name === 'status');
  check('hh_koppelingen.status bestaat', !!status, 'draai 40-familie-velden.mjs --apply');
  if (status) {
    check(
      'status kent aangevraagd en actief',
      [STATUS_AANGEVRAAGD, STATUS_ACTIEF].every((w) => (status.values || []).includes(w)),
    );
  }
  const alle = await su.collection('hh_koppelingen').getFullList();
  const leeg = alle.filter((k) => !String(k.status || '').trim());
  check(`geen koppeling zonder status (${alle.length} in totaal)`, leeg.length === 0, `${leeg.length} leeg`);

  const klussen = await su.collections.getOne('hh_klussen');
  for (const k of ['listRule', 'viewRule', 'createRule', 'updateRule']) {
    check(`hh_klussen.${k} eist een actieve koppeling`, String(klussen[k] || '').includes(ACTIEF));
  }
  const users = await su.collections.getOne('hh_users');
  check('hh_users.listRule: jongere van mijn oudere', String(users.listRule || '').includes(JONGERE_VAN_MIJN_OUDERE));

  const anon = anonClient();
  const r = await aanvraag(anon, 'iemand@voorbeeld.nl');
  check('de aanvraagroute bestaat (anoniem 401, niet 404)', r.status === 401 || r.status === 403, `status ${r.status}`);
}

async function main() {
  for (const c of ['hh_koppelingen', 'hh_klussen', 'hh_users', 'hh_klus_status']) assertHh(c);
  const su = await superuserClient();
  console.log('Verbonden met', PB_URL, APPLY ? '(APPLY)' : '(DRY-RUN)', '\n');

  if (!APPLY) {
    console.log('DRY-RUN: er wordt NIETS geschreven.');
    await voorwaarden(su);
    console.log('\nWat --apply ZOU doen:');
    console.log(`  · tijdelijke accounts maken (${MAIL_PREFIX}...${MAIL_DOMEIN}) en eigen klussen "${MERK}";`);
    console.log('  · met familielid 1 aanvragen, "Ja" en "Nee" zeggen, rechten wisselen;');
    console.log('  · per stap nameten wat het familielid wel en niet ziet of mag;');
    console.log('  · de limiet van 5 aanvragen per dag raken met een vers familielid;');
    console.log('  · alles opruimen.');
    console.log(`\n${groen} groen, ${rood} rood (leescontroles).`);
    if (rood > 0) console.log('Rood is verwacht zolang 40, 41 en 43 nog niet uitgerold zijn.');
    return;
  }

  if (!existsSync(ACCOUNTS_FILE)) throw new Error(`${ACCOUNTS_FILE} ontbreekt — draai eerst 03-seed.mjs --apply`);
  const acc = JSON.parse(readFileSync(ACCOUNTS_FILE, 'utf8'));

  kop('A. Opruimen van een eerdere run');
  await opruimen(su);
  if (ALLEEN_OPRUIMEN) {
    console.log('\nAlleen opgeruimd.');
    return;
  }

  await voorwaarden(su);

  const wijk = await su.collection('hh_wijken').getFirstListItem('naam = "Tiel-West"');
  const klustype = await su.collection('hh_klustypes').getFirstListItem('naam = "boodschappen"');
  const wachtwoord = randomBytes(18).toString('base64url');

  async function tijdelijkAccount(label, rol) {
    const email = `${MAIL_PREFIX}${label}-${randomBytes(4).toString('hex')}${MAIL_DOMEIN}`;
    const record = await su.collection(assertHh('hh_users')).create({
      email,
      password: wachtwoord,
      passwordConfirm: wachtwoord,
      verified: true,
      rol,
      naam: `${MERK} ${label}`,
      taal: 'nl',
      wijk: rol === 'hulpvrager' ? wijk.id : '',
    });
    return { id: record.id, email, client: await userClient(email, wachtwoord) };
  }

  async function klusVoor(oudereId, label, extra = {}) {
    const van = new Date(Date.now() + 24 * 3600 * 1000);
    return su.collection(assertHh('hh_klussen')).create({
      hulpvrager: oudereId,
      geplaatst_door: oudereId,
      klustype: klustype.id,
      omschrijving: `${MERK} ${label}`,
      adres: ADRES,
      lat: LAT,
      lon: LON,
      wanneer_van: van.toISOString(),
      wanneer_tot: new Date(van.getTime() + 3600 * 1000).toISOString(),
      status: 'open',
      bron: 'app',
      ...extra,
    });
  }

  const fam = await userClient(acc.familie1.email, acc.familie1.password);
  const famId = acc.familie1.id;
  const oudereA = await tijdelijkAccount('oudere-a', 'hulpvrager');
  const oudereB = await tijdelijkAccount('oudere-b', 'hulpvrager');
  const familie2 = await tijdelijkAccount('familie-2', 'familie');
  const klusA = await klusVoor(oudereA.id, 'klus van oudere A', {
    toegewezen_jongere: acc.jongere1.id,
    status: 'geaccepteerd',
  });
  const klusB = await klusVoor(oudereB.id, 'klus van oudere B');

  kop('C. Aanvragen: hetzelfde antwoord voor bekend en onbekend');
  const bekend = await aanvraag(fam, oudereA.email);
  const onbekend = await aanvraag(fam, `${MAIL_PREFIX}bestaat-niet${MAIL_DOMEIN}`);
  check('bekend adres: 200', bekend.status === 200, `status ${bekend.status}`);
  check(
    'onbekend adres: precies hetzelfde antwoord',
    onbekend.status === bekend.status && JSON.stringify(onbekend.body) === JSON.stringify(bekend.body),
  );
  const koppelingA = await su
    .collection('hh_koppelingen')
    .getFirstListItem(su.filter('oudere = {:o} && familielid = {:f}', { o: oudereA.id, f: famId }));
  check('de koppeling staat op aangevraagd, zonder rechten',
    koppelingA.status === STATUS_AANGEVRAAGD && (koppelingA.rechten || []).length === 0);

  kop('D. Aangevraagd geeft nog geen toegang');
  {
    const klussen = await fam.collection('hh_klussen').getList(1, 10, { filter: fam.filter('hulpvrager = {:id}', { id: oudereA.id }) });
    check('klussen van de oudere: dicht', klussen.totalItems === 0, `${klussen.totalItems}`);
    const user = await probeer(() => fam.collection('hh_users').getOne(oudereA.id));
    check('hh_users van de oudere: dicht', user.status !== 200, `status ${user.status}`);
    const logs = await fam.collection('hh_klus_status').getList(1, 10, { filter: fam.filter('klus = {:id}', { id: klusA.id }) });
    check('logregels van de klus: dicht', logs.totalItems === 0, `${logs.totalItems}`);
    const jongere = await probeer(() => fam.collection('hh_users').getOne(acc.jongere1.id));
    check('de jongere op de klus: dicht', jongere.status !== 200, `status ${jongere.status}`);
  }

  kop('E. Alleen de oudere beslist');
  {
    const zelf = await probeer(() =>
      fam.collection('hh_koppelingen').update(koppelingA.id, { status: STATUS_ACTIEF, rechten: ['meekijken', 'plaatsen'] }),
    );
    check('familielid zet zijn eigen koppeling niet op actief', zelf.status !== 200, `status ${zelf.status}`);
    const direct = await probeer(() =>
      fam.collection('hh_koppelingen').create({ oudere: oudereB.id, familielid: famId, status: STATUS_ACTIEF, rechten: ['plaatsen'] }),
    );
    check('familielid maakt zelf geen koppeling', direct.status !== 200, `status ${direct.status}`);
    const ziet = await oudereA.client.collection('hh_koppelingen').getList(1, 10, { expand: 'familielid' });
    check('de oudere ziet de vraag', ziet.items.some((k) => k.id === koppelingA.id));
    check('de oudere ziet wie het vraagt', ziet.items.some((k) => k.expand?.familielid?.id === famId));
  }

  kop('F. Na "Ja" wel toegang');
  await oudereA.client.collection('hh_koppelingen').update(koppelingA.id, { status: STATUS_ACTIEF });
  {
    const na = await su.collection('hh_koppelingen').getOne(koppelingA.id);
    check('"Ja" zonder rechten geeft er beide (hook)',
      ['meekijken', 'plaatsen'].every((r) => (na.rechten || []).includes(r)), JSON.stringify(na.rechten));
    const klussen = await fam.collection('hh_klussen').getList(1, 10, { filter: fam.filter('hulpvrager = {:id}', { id: oudereA.id }) });
    check('klussen van de oudere: open', klussen.totalItems === 1, `${klussen.totalItems}`);
    const user = await probeer(() => fam.collection('hh_users').getOne(oudereA.id));
    check('hh_users van de oudere: open', user.status === 200, `status ${user.status}`);
  }

  kop('G. Plaatsen alleen met recht plaatsen');
  const nieuweKlus = () =>
    fam.collection('hh_klussen').create({
      hulpvrager: oudereA.id,
      geplaatst_door: famId,
      klustype: klustype.id,
      omschrijving: `${MERK} namens de oudere`,
      adres: ADRES,
      lat: LAT,
      lon: LON,
      wanneer_van: new Date(Date.now() + 48 * 3600 * 1000).toISOString(),
      status: 'open',
      bron: 'familie',
    });
  await oudereA.client.collection('hh_koppelingen').update(koppelingA.id, { rechten: ['meekijken'] });
  {
    const zonder = await probeer(nieuweKlus);
    check('alleen meekijken: klus aanmaken geweigerd', zonder.status !== 200, `status ${zonder.status}`);
    const lezen = await fam.collection('hh_klussen').getList(1, 10, { filter: fam.filter('hulpvrager = {:id}', { id: oudereA.id }) });
    check('alleen meekijken: lezen mag wel', lezen.totalItems >= 1);
  }
  await oudereA.client.collection('hh_koppelingen').update(koppelingA.id, { rechten: ['plaatsen'] });
  {
    const met = await probeer(nieuweKlus);
    check('met recht plaatsen: klus aanmaken mag', met.status === 200, `status ${met.status}`);
    const lezen = await fam.collection('hh_klussen').getList(1, 10, { filter: fam.filter('hulpvrager = {:id}', { id: oudereA.id }) });
    check('alleen plaatsen: meekijken is dicht', lezen.totalItems === 0, `${lezen.totalItems}`);
  }
  await oudereA.client.collection('hh_koppelingen').update(koppelingA.id, { rechten: ['meekijken', 'plaatsen'] });

  kop('H. De jongere op de klus van mijn oudere, en niemand anders');
  {
    const jongere = await probeer(() => fam.collection('hh_users').getOne(acc.jongere1.id));
    check('jongere 1 (op de klus van oudere A): zichtbaar', jongere.status === 200, `status ${jongere.status}`);
    for (const [naam, id] of [
      ['jongere 3 (niet op een klus van mijn ouderen)', acc.jongere3.id],
      ['oudere B (niet gekoppeld)', oudereB.id],
    ]) {
      const r = await probeer(() => fam.collection('hh_users').getOne(id));
      check(`${naam}: niet zichtbaar`, r.status !== 200, `status ${r.status}`);
    }
    const lijst = await fam.collection('hh_users').getFullList({ filter: 'rol = "jongere"' });
    const toegestaan = new Set([acc.jongere1.id]);
    // De seed-koppeling (familielid 1 - oudere 1) geeft ook de jongeren op
    // de klussen van oudere 1; die tellen mee als toegestaan.
    const vanOudere1 = await su.collection('hh_klussen').getFullList({
      filter: su.filter('hulpvrager = {:id} && toegewezen_jongere != ""', { id: acc.hulpvrager1.id }),
    });
    for (const k of vanOudere1) toegestaan.add(k.toegewezen_jongere);
    check('in de lijst alleen jongeren op klussen van mijn ouderen', lijst.every((u) => toegestaan.has(u.id)),
      lijst.map((u) => u.id).join(','));
  }

  kop('I. Geen lek via een ander familielid');
  {
    await su.collection(assertHh('hh_koppelingen')).create({
      oudere: oudereB.id,
      familielid: familie2.id,
      status: STATUS_ACTIEF,
      rechten: ['meekijken', 'plaatsen'],
    });
    await aanvraag(fam, oudereB.email);
    const klussen = await fam.collection('hh_klussen').getList(1, 10, { filter: fam.filter('hulpvrager = {:id}', { id: oudereB.id }) });
    check('aanvraag bij B + actief ander familielid: klussen van B dicht', klussen.totalItems === 0, `${klussen.totalItems}`);
    const user = await probeer(() => fam.collection('hh_users').getOne(oudereB.id));
    check('... en hh_users van B dicht', user.status !== 200, `status ${user.status}`);
    const klusVanB = await probeer(() => fam.collection('hh_klussen').getOne(klusB.id));
    check('... en de klus van B dicht', klusVanB.status !== 200, `status ${klusVanB.status}`);
  }

  kop('J. "Nee"');
  {
    const aanvraagB = await su
      .collection('hh_koppelingen')
      .getFirstListItem(su.filter('oudere = {:o} && familielid = {:f}', { o: oudereB.id, f: famId }));
    const nee = await probeer(() => oudereB.client.collection('hh_koppelingen').delete(aanvraagB.id));
    check('de oudere haalt de aanvraag weg', nee.status === 200, `status ${nee.status}`);
    const weg = await probeer(() => su.collection('hh_koppelingen').getOne(aanvraagB.id));
    check('de koppeling bestaat niet meer', weg.status === 404, `status ${weg.status}`);
  }

  kop('K. Hooguit 5 aanvragen per dag');
  {
    const vers = await tijdelijkAccount('familie-limiet', 'familie');
    const statussen = [];
    for (let i = 0; i < 6; i++) {
      const r = await aanvraag(vers.client, `${MAIL_PREFIX}onbekend-${i}${MAIL_DOMEIN}`);
      statussen.push(r.status);
    }
    check('vijf keer 200, de zesde 429', statussen.join() === '200,200,200,200,200,429', statussen.join());
  }

  kop('L. Opruimen');
  await opruimen(su);
  const over = await su.collection('hh_users').getFullList({ filter: su.filter('email ~ {:p}', { p: MAIL_PREFIX }) });
  check('geen tijdelijke accounts meer over', over.length === 0);
  const seed = await su.collection('hh_koppelingen').getFullList({ filter: su.filter('familielid = {:f}', { f: famId }) });
  check('de seed-koppeling van familielid 1 staat er nog, actief', seed.some((k) => k.status === STATUS_ACTIEF));

  console.log(`\n${groen} groen, ${rood} rood.`);
  if (rood > 0) process.exitCode = 1;
}

main().catch(fail);
