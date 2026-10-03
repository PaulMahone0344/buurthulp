// HeitjeHulp M6 — bewijst de statusmachine op de ECHTE server met de ECHTE
// seed-accounts (backend/seed-accounts.local.json, nooit loggen). Werkt met
// EIGEN klussen met het merk "[statuscheck]" (oudere 1, Tiel-West, met lat/lon
// zodat er geen Nominatim-verzoek nodig is); de twaalf seed-klussen worden
// niet aangeraakt. Alles wordt aan het eind opgeruimd en nagemeten.
//
//   A. opruimen van een eerdere (gecrashte) run
//   B. de drie routes bestaan: anoniem -> 401 (niet 404)
//   C. aanmaken schrijft de EERSTE logregel (leeg -> open) — hook, niet de app
//   D. concept -> open door de oudere mag nog, en geeft een logregel
//   E. de achterdeur is dicht: status en toegewezen_jongere niet meer via een
//      gewone record-update (jongere 403, oudere 403); hh_klus_status.create
//      door een jongere geweigerd
//   F. de hele reeks via de routes: accepteren -> onderweg -> bezig ->
//      afgerond, precies EEN logregel per wissel, met tijdstempel
//   G. weigeringen: overslaan 409, terug 409, andere jongere 403, oudere 403,
//      onbekende klus 404, lege/onbekende doelstatus 400
//   H. annuleren door de oudere bij open, geaccepteerd en onderweg; bij bezig
//      409; reden te kort 400
//   I. annuleren door de jongere: klus terug naar open, jongere leeg,
//      toelichting in de logregel
//   J. bel-route: jongere krijgt het nummer van de oudere, oudere dat van de
//      jongere, een vreemde 403, status open 409, zonder nummer 409
//   K. RACE: 20 ronden waarin twee clients van jongere 1 TEGELIJK dezelfde
//      statusstap doen; elke ronde precies één 200, één 409 en één logregel
//   L. opruimen en nameten
//
// Wijzigt geen rules en geen velden (dat doen 12 en 13). Herhaalbaar.
// Opruim-knop na een handmatige app-smoke:
//   node scripts/14-statuscheck.mjs --apply --alleen-opruimen
//
// DRAAIEN (na 12 --apply, 13 --apply en 10-hook-deploy.sh):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/14-statuscheck.mjs --apply     (zonder --apply: alleen uitleg)

import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, userClient, anonClient, assertHh, APPLY, fail, PB_URL } from './_lib.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ACCOUNTS_FILE = path.resolve(__dirname, '..', 'seed-accounts.local.json');
const MERK = '[statuscheck]';
const ALLEEN_OPRUIMEN = process.argv.includes('--alleen-opruimen');
const RONDEN = Number(process.env.HH_RONDEN || 20);

// Tiel-West, zodat de wijk-eis van de accepteer-route klopt en de
// geocoding-hook niets hoeft te doen (lat/lon zijn al gevuld).
const ADRES = 'Prins Bernhardlaan 12, 4003 AB Tiel';
const LAT = 51.8865;
const LON = 5.4126;

const ROUTE_ACCEPTEREN = (id) => `/api/hh/klussen/${id}/accepteren`;
const ROUTE_STATUS = (id) => `/api/hh/klussen/${id}/status`;
const ROUTE_ANNULEREN = (id) => `/api/hh/klussen/${id}/annuleren`;
const ROUTE_BEL = (id) => `/api/hh/klussen/${id}/bel`;

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

// Een verzoek aan een hook-route; geeft {status, body} terug, gooit nooit.
async function roep(client, pad, methode = 'POST', body) {
  try {
    const antwoord = await client.send(pad, body === undefined ? { method: methode } : { method: methode, body });
    return { status: 200, body: antwoord ?? {} };
  } catch (e) {
    return { status: e?.status ?? 0, body: e?.response ?? {} };
  }
}

const zetStatus = (client, id, naar) => roep(client, ROUTE_STATUS(id), 'POST', { naar });
const annuleer = (client, id, reden) => roep(client, ROUTE_ANNULEREN(id), 'POST', { reden });
const bel = (client, id) => roep(client, ROUTE_BEL(id), 'GET');
const accepteer = (client, id) => roep(client, ROUTE_ACCEPTEREN(id), 'POST');

async function logsVan(su, klusId) {
  return su.collection('hh_klus_status').getFullList({ filter: `klus = "${klusId}"`, sort: 'created,id' });
}

// Alle eigen klussen (en hun logregels, die cascaden mee) weghalen.
async function opruimen(su) {
  const eigen = await su.collection('hh_klussen').getFullList({ filter: `omschrijving ~ "${MERK}"` });
  for (const k of eigen) {
    await su.collection(assertHh('hh_klussen')).delete(k.id);
    console.log(`  ↻ eigen klus ${k.id} verwijderd`);
  }
  return eigen.length;
}

async function main() {
  assertHh('hh_klussen');
  assertHh('hh_klus_status');
  assertHh('hh_users');
  if (!APPLY) {
    console.log('DRY-RUN: dit script logt in als de seed-accounts en maakt EIGEN klussen met het merk');
    console.log(`"${MERK}" (oudere 1, Tiel-West). Het bewijst de routes /status, /annuleren en /bel, de`);
    console.log('dichte achterdeur op record-updates, de logregels van de hook, en laat twee clients van');
    console.log(`jongere 1 ${RONDEN} keer tegelijk dezelfde stap zetten. Alles wordt aan het eind verwijderd.`);
    console.log('De twaalf seed-klussen worden niet aangeraakt.');
    console.log('Zonder --apply gebeurt er niets. Draai met --apply.');
    return;
  }
  if (!existsSync(ACCOUNTS_FILE)) throw new Error(`${ACCOUNTS_FILE} ontbreekt — draai eerst 03-seed.mjs --apply`);
  const acc = JSON.parse(readFileSync(ACCOUNTS_FILE, 'utf8'));

  const su = await superuserClient();
  console.log('Verbonden met', PB_URL, '\n');

  kop('A. Opruimen van een eerdere run');
  const wegBegin = await opruimen(su);
  check(`${wegBegin} achtergebleven ${MERK}-klus(sen) opgeruimd`, true);
  if (ALLEEN_OPRUIMEN) {
    console.log(`\n${groen} groen, ${rood} rood. Alleen opgeruimd.`);
    return;
  }

  const U = Object.fromEntries(Object.entries(acc).map(([k, v]) => [k, v.id]));
  const hv1 = await userClient(acc.hulpvrager1.email, acc.hulpvrager1.password);
  const j1 = await userClient(acc.jongere1.email, acc.jongere1.password);
  const j1b = await userClient(acc.jongere1.email, acc.jongere1.password); // tweede client voor de race
  const j2 = await userClient(acc.jongere2.email, acc.jongere2.password);
  const j3 = await userClient(acc.jongere3.email, acc.jongere3.password);
  const co = await userClient(acc.coordinator1.email, acc.coordinator1.password);
  const anon = anonClient();

  const klustype = await su.collection('hh_klustypes').getFirstListItem('naam = "boodschappen"');
  const nu = new Date();
  const van = new Date(nu.getTime() + 24 * 3600 * 1000);
  const tot = new Date(van.getTime() + 3600 * 1000);

  // Een eigen klus van oudere 1 in Tiel-West. [status] is concept of open.
  async function nieuweKlus(status, label) {
    return hv1.collection('hh_klussen').create({
      hulpvrager: U.hulpvrager1,
      geplaatst_door: U.hulpvrager1,
      klustype: klustype.id,
      omschrijving: `${MERK} ${label}`,
      adres: ADRES,
      lat: LAT,
      lon: LON,
      wanneer_van: van.toISOString(),
      wanneer_tot: tot.toISOString(),
      status,
      bedrag_bruto: 1000,
      vergoeding_jongere: 800,
      commissie: 200,
      bron: 'app',
    });
  }

  // Een klus die al op [status] staat met jongere 1 erop: aanmaken als open,
  // accepteren via de route, en daarna stap voor stap doorzetten.
  async function klusOp(status, label) {
    const k = await nieuweKlus('open', label);
    if (status === 'open') return k;
    const a = await accepteer(j1, k.id);
    if (a.status !== 200) throw new Error(`accepteren mislukt (${a.status}) bij het klaarzetten van ${label}`);
    const reeks = ['onderweg', 'bezig', 'afgerond'];
    for (const stap of reeks) {
      if (status === 'geaccepteerd') break;
      const r = await zetStatus(j1, k.id, stap);
      if (r.status !== 200) throw new Error(`${stap} mislukt (${r.status}) bij het klaarzetten van ${label}`);
      if (stap === status) break;
    }
    return su.collection('hh_klussen').getOne(k.id);
  }

  kop('B. De drie routes bestaan (anoniem -> 401, niet 404)');
  {
    const k = await nieuweKlus('open', 'routecheck');
    for (const [naam, r] of [
      ['status', await zetStatus(anon, k.id, 'onderweg')],
      ['annuleren', await annuleer(anon, k.id, 'zomaar een reden')],
      ['bel', await bel(anon, k.id)],
    ]) {
      check(`anoniem op /${naam} -> 401 (kreeg ${r.status})`, r.status === 401, JSON.stringify(r.body));
    }
  }

  kop('C. Aanmaken schrijft de eerste logregel (de hook, niet de app)');
  {
    const k = await nieuweKlus('open', 'eerste logregel');
    const logs = await logsVan(su, k.id);
    check(`precies 1 logregel na het aanmaken (kreeg ${logs.length})`, logs.length === 1, JSON.stringify(logs.map((l) => `${l.van}->${l.naar}`)));
    if (logs.length) {
      check(`  van is leeg, naar is open, door is de oudere`, logs[0].van === '' && logs[0].naar === 'open' && logs[0].door === U.hulpvrager1, `van=${logs[0].van} naar=${logs[0].naar} door=${logs[0].door}`);
      check('  created is gevuld (tijdstempel van de wissel)', !!logs[0].created);
    }
  }

  kop('D. Concept -> open door de oudere mag nog, en geeft een logregel');
  {
    const k = await nieuweKlus('concept', 'concept naar open');
    const naCreate = await logsVan(su, k.id);
    check(`concept-klus krijgt bij aanmaken 1 logregel leeg -> concept (kreeg ${naCreate.length})`, naCreate.length === 1 && naCreate[0].van === '' && naCreate[0].naar === 'concept', JSON.stringify(naCreate.map((l) => `${l.van}->${l.naar}`)));
    let gelukt = false;
    try {
      await hv1.collection('hh_klussen').update(k.id, { status: 'open' });
      gelukt = true;
    } catch (e) {
      check('oudere 1 zet eigen concept op open', false, `status=${e?.status} ${e?.response?.message ?? ''}`);
    }
    if (gelukt) {
      check('oudere 1 zet eigen concept op open', true);
      const logs = await logsVan(su, k.id);
      check(`nu 2 logregels, de tweede concept -> open (kreeg ${logs.length})`, logs.length === 2 && logs[1].van === 'concept' && logs[1].naar === 'open', JSON.stringify(logs.map((l) => `${l.van}->${l.naar}`)));
    }
  }

  kop('E. De achterdeur is dicht (record-update en losse logregels)');
  {
    const open = await nieuweKlus('open', 'achterdeur open');
    const mijn = await klusOp('geaccepteerd', 'achterdeur toegewezen');

    for (const [label, fn] of [
      ['jongere 1 kan een open klus niet aan zichzelf toewijzen via record-update', () => j1.collection('hh_klussen').update(open.id, { toegewezen_jongere: U.jongere1, status: 'geaccepteerd' })],
      ['jongere 1 kan de status van zijn eigen klus niet via record-update wijzigen', () => j1.collection('hh_klussen').update(mijn.id, { status: 'onderweg' })],
      ['jongere 1 kan zijn klus niet via record-update teruggeven', () => j1.collection('hh_klussen').update(mijn.id, { toegewezen_jongere: '' })],
      ['oudere 1 kan de status van zijn eigen klus niet via record-update wijzigen', () => hv1.collection('hh_klussen').update(mijn.id, { status: 'geannuleerd' })],
      ['oudere 1 kan geen jongere op zijn klus zetten via record-update', () => hv1.collection('hh_klussen').update(open.id, { toegewezen_jongere: U.jongere2 })],
      ['jongere 1 kan geen losse logregel meer schrijven', () => j1.collection('hh_klus_status').create({ klus: mijn.id, door: U.jongere1, van: 'geaccepteerd', naar: 'onderweg' })],
      ['oudere 1 kan geen losse logregel meer schrijven', () => hv1.collection('hh_klus_status').create({ klus: mijn.id, door: U.hulpvrager1, van: 'geaccepteerd', naar: 'geannuleerd' })],
    ]) {
      try {
        await fn();
        check(label, false, 'verzoek is onterecht gelukt');
      } catch (e) {
        check(`${label} (${e?.status})`, [400, 403, 404].includes(e?.status), `status=${e?.status} ${e?.response?.message ?? ''}`);
      }
    }

    let adresGelukt = false;
    try {
      await hv1.collection('hh_klussen').update(open.id, { omschrijving: `${MERK} achterdeur open, bijgewerkt` });
      adresGelukt = true;
    } catch (_) {
      adresGelukt = false;
    }
    check('oudere 1 kan de omschrijving van zijn klus nog wel bijwerken', adresGelukt);

    let coordGelukt = false;
    try {
      await co.collection('hh_klussen').update(open.id, { status: 'geannuleerd' });
      await co.collection('hh_klussen').update(open.id, { status: 'open' });
      coordGelukt = true;
    } catch (e) {
      check('coordinator mag de status wel via record-update wijzigen', false, `status=${e?.status}`);
    }
    if (coordGelukt) check('coordinator mag de status wel via record-update wijzigen', true);

    const naAchterdeur = await su.collection('hh_klussen').getOne(mijn.id);
    check('de toegewezen klus staat na alle pogingen nog op geaccepteerd met jongere 1', naAchterdeur.status === 'geaccepteerd' && naAchterdeur.toegewezen_jongere === U.jongere1, `${naAchterdeur.status} / ${naAchterdeur.toegewezen_jongere}`);
  }

  kop('F. De hele reeks via de routes, met precies één logregel per wissel');
  {
    const k = await nieuweKlus('open', 'hele reeks');
    const a = await accepteer(j1, k.id);
    check(`accepteren -> 200 (kreeg ${a.status})`, a.status === 200, JSON.stringify(a.body));

    for (const [van, naar] of [['geaccepteerd', 'onderweg'], ['onderweg', 'bezig'], ['bezig', 'afgerond']]) {
      const r = await zetStatus(j1, k.id, naar);
      check(`${van} -> ${naar} geeft 200 met status ${naar} (kreeg ${r.status})`, r.status === 200 && r.body?.status === naar, JSON.stringify(r.body));
    }

    const klus = await su.collection('hh_klussen').getOne(k.id);
    check('de klus staat op afgerond met jongere 1', klus.status === 'afgerond' && klus.toegewezen_jongere === U.jongere1, `${klus.status} / ${klus.toegewezen_jongere}`);

    const VERWACHT = 'leeg->open open->geaccepteerd geaccepteerd->onderweg onderweg->bezig bezig->afgerond';
    const logs = await logsVan(su, k.id);
    const reeks = logs.map((l) => `${l.van || 'leeg'}->${l.naar}`).join(' ');
    check(`precies 5 logregels in de goede volgorde (${reeks})`, logs.length === 5 && reeks === VERWACHT, `verwacht: ${VERWACHT}`);
    check('elke logregel heeft een tijdstempel; vanaf het accepteren staat de jongere als "door"', logs.every((l) => !!l.created) && logs.slice(1).every((l) => l.door === U.jongere1), reeks);
  }

  kop('G. Weigeringen op de statusroute');
  {
    const mijn = await klusOp('geaccepteerd', 'weigeringen');

    let r = await zetStatus(j1, mijn.id, 'afgerond');
    check(`stap overslaan (geaccepteerd -> afgerond) -> 409 (kreeg ${r.status})`, r.status === 409 && r.body?.reden === 'overgang', JSON.stringify(r.body));
    check('  melding is Nederlands', typeof r.body?.melding === 'string' && r.body.melding.length > 10, JSON.stringify(r.body));

    r = await zetStatus(j1, mijn.id, 'onderweg');
    check(`onderweg -> 200 (kreeg ${r.status})`, r.status === 200);
    r = await zetStatus(j1, mijn.id, 'geaccepteerd');
    check(`terug (onderweg -> geaccepteerd) -> 409 (kreeg ${r.status})`, r.status === 409 && r.body?.reden === 'overgang', JSON.stringify(r.body));

    r = await zetStatus(j2, mijn.id, 'bezig');
    check(`andere jongere -> 403 (kreeg ${r.status})`, r.status === 403 && r.body?.reden === 'nietvanjou', JSON.stringify(r.body));
    r = await zetStatus(hv1, mijn.id, 'bezig');
    check(`de oudere zelf -> 403 (kreeg ${r.status})`, r.status === 403 && r.body?.reden === 'nietvanjou', JSON.stringify(r.body));
    r = await zetStatus(anon, mijn.id, 'bezig');
    check(`anoniem -> 401 (kreeg ${r.status})`, r.status === 401);

    r = await zetStatus(j1, 'bestaatnietxx01', 'onderweg');
    check(`onbekende klus -> 404 (kreeg ${r.status})`, r.status === 404);
    r = await zetStatus(j1, mijn.id, '');
    check(`lege doelstatus -> 400 (kreeg ${r.status})`, r.status === 400 && r.body?.reden === 'naar', JSON.stringify(r.body));
    r = await zetStatus(j1, mijn.id, 'probleem');
    check(`onbekende doelstatus -> 409 (kreeg ${r.status})`, r.status === 409 && r.body?.reden === 'overgang', JSON.stringify(r.body));

    const logs = await logsVan(su, mijn.id);
    check(`geen enkele weigering schreef een logregel (${logs.length} regels: leeg->open, open->geaccepteerd, geaccepteerd->onderweg)`, logs.length === 3, logs.map((l) => `${l.van || 'leeg'}->${l.naar}`).join(' '));
  }

  kop('H. Annuleren door de oudere');
  {
    for (const status of ['open', 'geaccepteerd', 'onderweg']) {
      const k = await klusOp(status, `annuleren oudere bij ${status}`);
      const r = await annuleer(hv1, k.id, `Het komt me nu toch niet uit (${status}).`);
      check(`oudere annuleert bij ${status} -> 200 (kreeg ${r.status})`, r.status === 200 && r.body?.status === 'geannuleerd', JSON.stringify(r.body));
      const na = await su.collection('hh_klussen').getOne(k.id);
      check(`  de klus staat op geannuleerd`, na.status === 'geannuleerd', na.status);
      const logs = await logsVan(su, k.id);
      const laatste = logs[logs.length - 1];
      check(`  de laatste logregel is ${status} -> geannuleerd met de reden erin`, laatste?.van === status && laatste?.naar === 'geannuleerd' && String(laatste?.toelichting || '').includes(status), `${laatste?.van}->${laatste?.naar} "${laatste?.toelichting}"`);
    }

    const bezig = await klusOp('bezig', 'annuleren oudere bij bezig');
    let r = await annuleer(hv1, bezig.id, 'Toch maar niet, sorry.');
    check(`oudere annuleert bij bezig -> 409 (kreeg ${r.status})`, r.status === 409 && r.body?.reden === 'bezig', JSON.stringify(r.body));
    r = await annuleer(j1, bezig.id, 'Toch maar niet, sorry.');
    check(`jongere annuleert bij bezig -> 409 (kreeg ${r.status})`, r.status === 409 && r.body?.reden === 'bezig', JSON.stringify(r.body));

    const afgerond = await klusOp('afgerond', 'annuleren bij afgerond');
    r = await annuleer(hv1, afgerond.id, 'Achteraf toch annuleren.');
    check(`annuleren bij afgerond -> 409 (kreeg ${r.status})`, r.status === 409 && r.body?.reden === 'status', JSON.stringify(r.body));

    const vreemd = await klusOp('geaccepteerd', 'annuleren door een vreemde');
    r = await annuleer(j3, vreemd.id, 'Ik ken deze klus helemaal niet.');
    check(`een vreemde annuleert -> 403 (kreeg ${r.status})`, r.status === 403 && r.body?.reden === 'geendeelnemer', JSON.stringify(r.body));

    // M14: de meldkamer annuleert ook een klus die de oudere zelf in de app zette.
    for (const status of ['open', 'geaccepteerd', 'onderweg']) {
      const k = await klusOp(status, `annuleren coordinator bij ${status}`);
      const reden = `Oudere belde de meldkamer af (${status}).`;
      const rc = await annuleer(co, k.id, reden);
      check(`coordinator annuleert bij ${status} -> 200 geannuleerd (kreeg ${rc.status})`, rc.status === 200 && rc.body?.status === 'geannuleerd', JSON.stringify(rc.body));
      const logs = await logsVan(su, k.id);
      const laatste = logs[logs.length - 1];
      check(`  de laatste logregel is ${status} -> geannuleerd, door de coordinator, met de reden`, laatste?.van === status && laatste?.naar === 'geannuleerd' && laatste?.door === U.coordinator1 && laatste?.toelichting === reden, `${laatste?.van}->${laatste?.naar} door=${laatste?.door} "${laatste?.toelichting}"`);
    }
    const coBezig = await klusOp('bezig', 'annuleren coordinator bij bezig');
    r = await annuleer(co, coBezig.id, 'Meldkamer wil toch stoppen.');
    check(`coordinator annuleert bij bezig -> 409 (kreeg ${r.status})`, r.status === 409 && r.body?.reden === 'bezig', JSON.stringify(r.body));

    r = await annuleer(hv1, vreemd.id, 'kort');
    check(`reden te kort (4 tekens) -> 400 (kreeg ${r.status})`, r.status === 400 && r.body?.reden === 'reden', JSON.stringify(r.body));
    r = await annuleer(hv1, vreemd.id, 'x'.repeat(301));
    check(`reden te lang (301 tekens) -> 400 (kreeg ${r.status})`, r.status === 400 && r.body?.reden === 'reden', JSON.stringify(r.body));
    r = await annuleer(hv1, 'bestaatnietxx01', 'Een nette reden van genoeg tekens.');
    check(`annuleren van een onbekende klus -> 404 (kreeg ${r.status})`, r.status === 404);
  }

  kop('I. Annuleren door de jongere: de klus gaat terug de buurt in');
  {
    for (const status of ['geaccepteerd', 'onderweg']) {
      const k = await klusOp(status, `annuleren jongere bij ${status}`);
      const reden = `Ik ben ziek geworden en kan niet komen (${status}).`;
      const r = await annuleer(j1, k.id, reden);
      check(`jongere annuleert bij ${status} -> 200 met status open (kreeg ${r.status})`, r.status === 200 && r.body?.status === 'open', JSON.stringify(r.body));
      const na = await su.collection('hh_klussen').getOne(k.id);
      check(`  de klus staat weer op open en toegewezen_jongere is leeg`, na.status === 'open' && !na.toegewezen_jongere, `${na.status} / "${na.toegewezen_jongere}"`);
      const logs = await logsVan(su, k.id);
      const laatste = logs[logs.length - 1];
      check(`  de laatste logregel is ${status} -> open, door de jongere, met de reden`, laatste?.van === status && laatste?.naar === 'open' && laatste?.door === U.jongere1 && laatste?.toelichting === reden, `${laatste?.van}->${laatste?.naar} door=${laatste?.door} "${laatste?.toelichting}"`);
      const weer = await accepteer(j2, k.id);
      check(`  een andere jongere kan hem daarna aannemen (kreeg ${weer.status})`, weer.status === 200, JSON.stringify(weer.body));
    }
    const open = await nieuweKlus('open', 'annuleren jongere bij open');
    const r = await annuleer(j1, open.id, 'Deze klus is niet van mij.');
    check(`jongere annuleert een klus die niet van hem is -> 403 (kreeg ${r.status})`, r.status === 403 && r.body?.reden === 'geendeelnemer', JSON.stringify(r.body));
  }

  kop('J. Bel-route');
  {
    const open = await nieuweKlus('open', 'bellen bij open');
    let r = await bel(hv1, open.id);
    check(`bellen bij status open -> 409 (kreeg ${r.status})`, r.status === 409 && r.body?.reden === 'status', JSON.stringify(r.body));

    const k = await klusOp('geaccepteerd', 'bellen');
    const oudereRij = await su.collection('hh_users').getOne(U.hulpvrager1);
    const jongereRij = await su.collection('hh_users').getOne(U.jongere1);

    r = await bel(j1, k.id);
    check(`jongere krijgt het nummer van de oudere (kreeg ${r.status})`, r.status === 200 && r.body?.nummer === oudereRij.telefoon, JSON.stringify(r.body));
    check('  en de naam van de oudere erbij', r.status === 200 && r.body?.naam === oudereRij.naam, JSON.stringify(r.body));

    r = await bel(hv1, k.id);
    check(`oudere krijgt het nummer van de jongere (kreeg ${r.status})`, r.status === 200 && r.body?.nummer === jongereRij.telefoon, JSON.stringify(r.body));
    check('  en de naam van de jongere erbij', r.status === 200 && r.body?.naam === jongereRij.naam, JSON.stringify(r.body));

    r = await bel(j3, k.id);
    check(`een vreemde -> 403 (kreeg ${r.status})`, r.status === 403 && r.body?.reden === 'geendeelnemer', JSON.stringify(r.body));
    r = await bel(j1, 'bestaatnietxx01');
    check(`onbekende klus -> 404 (kreeg ${r.status})`, r.status === 404);

    // Even zonder telefoonnummer, daarna netjes terug.
    const jongere = await su.collection('hh_users').getOne(U.jongere1);
    const bewaard = jongere.telefoon;
    await su.collection(assertHh('hh_users')).update(U.jongere1, { telefoon: '' });
    try {
      r = await bel(hv1, k.id);
      check(`jongere zonder nummer -> 409 met nette melding (kreeg ${r.status})`, r.status === 409 && r.body?.reden === 'geennummer', JSON.stringify(r.body));
    } finally {
      await su.collection(assertHh('hh_users')).update(U.jongere1, { telefoon: bewaard });
    }
    const terug = await su.collection('hh_users').getOne(U.jongere1);
    check(`het nummer van jongere 1 staat weer op de seed-waarde`, terug.telefoon === bewaard, `"${terug.telefoon}" vs "${bewaard}"`);

    // Terugval op contact_telefoon van de oudere.
    const oudere = await su.collection('hh_users').getOne(U.hulpvrager1);
    const oudNummer = oudere.telefoon;
    const oudContact = oudere.contact_telefoon;
    await su.collection(assertHh('hh_users')).update(U.hulpvrager1, { telefoon: '', contact_telefoon: '0612345678' });
    try {
      r = await bel(j1, k.id);
      check(`oudere zonder eigen nummer: de jongere krijgt contact_telefoon (kreeg ${r.status})`, r.status === 200 && r.body?.nummer === '0612345678', JSON.stringify(r.body));
    } finally {
      await su.collection(assertHh('hh_users')).update(U.hulpvrager1, { telefoon: oudNummer, contact_telefoon: oudContact });
    }
    const oudereTerug = await su.collection('hh_users').getOne(U.hulpvrager1);
    check('de gegevens van oudere 1 staan weer op de seed-waarden', oudereTerug.telefoon === oudNummer && oudereTerug.contact_telefoon === oudContact);
  }

  kop(`K. RACE: twee clients van jongere 1 zetten ${RONDEN} keer tegelijk dezelfde stap`);
  {
    let goedeRonden = 0;
    const uitkomsten = [];
    for (let ronde = 1; ronde <= RONDEN; ronde++) {
      const k = await klusOp('geaccepteerd', `race ronde ${ronde}`);
      const voor = (await logsVan(su, k.id)).length;
      const [r1, r2] = await Promise.all([zetStatus(j1, k.id, 'onderweg'), zetStatus(j1b, k.id, 'onderweg')]);
      const statussen = [r1.status, r2.status].sort();
      const logs = await logsVan(su, k.id);
      const nieuwe = logs.length - voor;
      const klus = await su.collection('hh_klussen').getOne(k.id);
      const ok = statussen[0] === 200 && statussen[1] === 409 && nieuwe === 1 && klus.status === 'onderweg';
      if (ok) goedeRonden++;
      uitkomsten.push(`${ronde}:${r1.status}/${r2.status}/log${nieuwe}${ok ? '' : '!'}`);
    }
    console.log(`  ronden: ${uitkomsten.join(' ')}`);
    check(`${goedeRonden}/${RONDEN} ronden precies één 200, één 409 en één nieuwe logregel`, goedeRonden === RONDEN);
  }

  kop('L. Opruimen en nameten');
  {
    const weg = await opruimen(su);
    check(`${weg} eigen klus(sen) verwijderd`, weg > 0);
    const over = await su.collection('hh_klussen').getFullList({ filter: `omschrijving ~ "${MERK}"` });
    check('geen eigen klussen meer over', over.length === 0, `${over.length} over`);
    const seed = await su.collection('hh_klussen').getFullList({ filter: 'omschrijving ~ "[seed "' });
    check(`de twaalf seed-klussen staan er nog (${seed.length})`, seed.length === 12, `${seed.length} seed-klussen`);
    const totaal = (await su.collection('hh_klussen').getFullList()).length;
    console.log(`  · in totaal staan er nu ${totaal} klussen op de server`);
  }

  console.log(`\n${groen} groen, ${rood} rood (${groen + rood} checks).`);
  if (rood > 0) process.exit(1);
}

main().catch(fail);
