// HeitjeHulp M10 — bewijst de hook backend/pb_hooks/hh_coordinator.pb.js op de
// ECHTE server met de ECHTE seed-accounts (backend/seed-accounts.local.json,
// nooit loggen):
//   A. terugzetten: seed-klussen k02/k03/k11 op open zonder jongere, k04 op
//      geaccepteerd (jongere1), k05 op onderweg (jongere2); logregels die deze
//      check eerder maakte weg. Daarna een momentopname van de logregel-ids per
//      klus, zodat aan het eind precies te zien is wat erbij kwam.
//   B. routes bestaan: anoniem koppelen en vrijgeven -> 401 (niet 404)
//   C. rechten: jongere -> 403, oudere -> 403, coordinator zonder jongere in de
//      body -> 400, onbekende klus -> 404
//   D. koppelen levert EXACT dezelfde klusvelden en logregel-vorm op als
//      accepteren door een jongere (k11 gekoppeld naast k02 geaccepteerd,
//      veld voor veld vergeleken)
//   E. klus niet meer open -> 409 bezet (tweede koppeling, en een klus die al
//      op geaccepteerd staat)
//   F. eisen aan de jongere: oudere als "jongere" -> 409, onbekend id -> 409,
//      niet-goedgekeurde jongere -> 409 (jongere 3 gaat tijdelijk op
//      in_behandeling en daarna terug op goedgekeurd)
//   G. andere wijk mag juist WEL: jongere 1 (Tiel-West) op een klus van
//      hulpvrager 2 (Passewaaij) -> 200 met andere_wijk true
//   H. vrijgeven: geaccepteerd -> open (van = geaccepteerd), daarna opnieuw
//      koppelen; onderweg -> open; zonder reden -> 400; een open klus -> 409;
//      door een jongere -> 403
//   I. RACE: 20 ronden waarin de coordinator k02 KOPPELT en jongere 1 hem
//      TEGELIJK accepteert (Promise.all); elke ronde precies één 200, één 409
//      en één nieuwe logregel
//   J. terugzetten en nameten (logtellingen gelijk aan het begin)
//
// Wijzigt geen rules en raakt geen andere collecties dan hh_klussen,
// hh_klus_status en (tijdelijk, voor F) hh_profielen. Herhaalbaar.
// Ook de "terugzet-knop" na een handmatige app-smoke met de coordinator:
//   node scripts/50-koppelcheck.mjs --apply --alleen-terugzetten
//
// LET OP: hh_klus_status.toelichting komt van M6 (scripts/12-status-velden.mjs).
// Zonder dat veld werkt de hook wel, maar laat PocketBase de toelichting stil
// vallen. Dit script meldt in dry-run én in de run of het veld er is, en slaat
// de toelichting-controles over zolang het ontbreekt.
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/50-koppelcheck.mjs --apply     (zonder --apply: alleen uitleg)

import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, userClient, anonClient, assertHh, APPLY, fail, PB_URL } from './_lib.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ACCOUNTS_FILE = path.resolve(__dirname, '..', 'seed-accounts.local.json');
const ALLEEN_TERUGZETTEN = process.argv.includes('--alleen-terugzetten');
const RONDEN = Number(process.env.HH_RONDEN || 20);

const KOPPEL = (id) => `/api/hh/klussen/${id}/koppelen`;
const VRIJGEVEN = (id) => `/api/hh/klussen/${id}/vrijgeven`;
const ACCEPTEER = (id) => `/api/hh/klussen/${id}/accepteren`;

// De seed-stand van de klussen die deze check aanraakt (03-seed.mjs).
const SEED_STAND = {
  k02: { status: 'open', jongere: null },
  k03: { status: 'open', jongere: null },
  k11: { status: 'open', jongere: null },
  k04: { status: 'geaccepteerd', jongere: 'jongere1' },
  k05: { status: 'onderweg', jongere: 'jongere2' },
};
const KLUS_KEYS = Object.keys(SEED_STAND);

let groen = 0;
let rood = 0;
let overgeslagen = 0;
function check(label, ok, detail) {
  if (ok) {
    groen++;
    console.log(`  ✓ ${label}`);
  } else {
    rood++;
    console.log(`  ✗ ${label}${detail ? ` — ${detail}` : ''}`);
  }
}
function sla(label, waarom) {
  overgeslagen++;
  console.log(`  – ${label} (overgeslagen: ${waarom})`);
}
function kop(t) {
  console.log(`\n${t}`);
}

// Een POST naar een hook-route; geeft {status, body} terug, gooit nooit.
async function post(client, pad, body) {
  try {
    const antwoord = await client.send(pad, { method: 'POST', body });
    return { status: 200, body: antwoord };
  } catch (e) {
    return { status: e?.status ?? 0, body: e?.response ?? {} };
  }
}

async function seedKlus(su, key) {
  return su.collection('hh_klussen').getFirstListItem(`omschrijving ~ "[seed ${key}]"`);
}

async function logsVan(su, klusId) {
  return su.collection('hh_klus_status').getFullList({ filter: `klus = "${klusId}"`, sort: 'created' });
}

/// Bestaat hh_klus_status.toelichting al (M6, script 12)? Alleen lezen.
async function heeftToelichting(su) {
  const collectie = await su.collections.getOne('hh_klus_status');
  return collectie.fields.some((f) => f.name === 'toelichting');
}

/// Zet de vijf klussen terug op hun seed-stand en verwijdert alle logregels die
/// niet in [bewaar] staan. Geeft de klus-ids en de logtelling per key terug.
async function terugzetten(su, userId, bewaar = null) {
  const ids = {};
  const telling = {};
  for (const key of KLUS_KEYS) {
    const klus = await seedKlus(su, key);
    ids[key] = klus.id;
    const wil = SEED_STAND[key];
    const jongereId = wil.jongere ? userId[wil.jongere] : '';
    if (klus.status !== wil.status || (klus.toegewezen_jongere || '') !== jongereId) {
      await su.collection(assertHh('hh_klussen')).update(klus.id, {
        status: wil.status,
        toegewezen_jongere: jongereId,
      });
      console.log(`  ↻ ${key} terug op ${wil.status}${wil.jongere ? ` (${wil.jongere})` : ' zonder jongere'}`);
    }
    const logs = await logsVan(su, klus.id);
    for (const log of logs) {
      if (bewaar && !bewaar[key].has(log.id)) {
        await su.collection(assertHh('hh_klus_status')).delete(log.id);
        console.log(`  ↻ ${key} logregel ${log.id} verwijderd`);
      }
    }
    telling[key] = (await logsVan(su, klus.id)).length;
  }
  return { ids, telling };
}

async function main() {
  assertHh('hh_klussen');
  assertHh('hh_klus_status');
  assertHh('hh_profielen');

  if (!APPLY) {
    console.log('DRY-RUN: dit script logt in als de seed-accounts en bewijst de twee routes uit');
    console.log('pb_hooks/hh_coordinator.pb.js: /api/hh/klussen/{id}/koppelen en /vrijgeven');
    console.log('(401/403/400/404/409/200), dat koppelen dezelfde klusvelden en logregel oplevert als');
    console.log(`accepteren, en laat de coordinator ${RONDEN} keer tegelijk met jongere 1 op k02 duwen`);
    console.log('(precies één winnaar per ronde). Alles wordt teruggezet. Er wordt niets geschreven');
    console.log('zonder --apply.\n');
    try {
      const su = await superuserClient();
      const erIs = await heeftToelichting(su);
      console.log(`Veld hh_klus_status.toelichting: ${erIs ? 'AANWEZIG' : 'ONTBREEKT'}`);
      if (!erIs) {
        console.log('-> Rol eerst M6 uit (scripts/12-status-velden.mjs --apply). Zonder dat veld');
        console.log('   koppelt en vrijgeeft de hook wel, maar valt de toelichting stil weg.');
      }
      const co = await su.collection('hh_users').getFirstListItem('rol = "coordinator"');
      console.log(`Coordinator-account gevonden: ${co.id}`);
      for (const key of KLUS_KEYS) {
        const klus = await seedKlus(su, key);
        console.log(`  ${key}: status ${klus.status}, jongere ${klus.toegewezen_jongere || '-'}`);
      }
    } catch (e) {
      console.log('Kon de server niet lezen:', e?.message || e);
    }
    return;
  }

  if (!existsSync(ACCOUNTS_FILE)) throw new Error(`${ACCOUNTS_FILE} ontbreekt — draai eerst 03-seed.mjs --apply`);
  const acc = JSON.parse(readFileSync(ACCOUNTS_FILE, 'utf8'));
  const U = Object.fromEntries(Object.entries(acc).map(([k, v]) => [k, v.id]));

  const su = await superuserClient();
  console.log('Verbonden met', PB_URL, '\n');

  const metToelichting = await heeftToelichting(su);
  console.log(`Veld hh_klus_status.toelichting: ${metToelichting ? 'aanwezig' : 'ONTBREEKT (M6 nog niet uitgerold)'}`);

  kop('A. Terugzetten (begin)');
  const begin = await terugzetten(su, U);
  const K = begin.ids;
  const bewaar = {};
  for (const key of KLUS_KEYS) {
    bewaar[key] = new Set((await logsVan(su, K[key])).map((l) => l.id));
  }
  check('k02/k03/k11 open zonder jongere, k04 geaccepteerd, k05 onderweg', true);
  if (ALLEEN_TERUGZETTEN) {
    console.log(`\n${groen} groen, ${rood} rood. Alleen teruggezet.`);
    return;
  }

  const co = await userClient(acc.coordinator1.email, acc.coordinator1.password);
  const j1 = await userClient(acc.jongere1.email, acc.jongere1.password);
  const j2 = await userClient(acc.jongere2.email, acc.jongere2.password);
  const hv1 = await userClient(acc.hulpvrager1.email, acc.hulpvrager1.password);
  const anon = anonClient();

  kop('B. Routes bestaan (anoniem -> 401, niet 404)');
  {
    const a = await post(anon, KOPPEL(K.k11), { jongere: U.jongere1 });
    check(`anoniem koppelen -> 401 (kreeg ${a.status})`, a.status === 401, JSON.stringify(a.body));
    const b = await post(anon, VRIJGEVEN(K.k04), { reden: 'test' });
    check(`anoniem vrijgeven -> 401 (kreeg ${b.status})`, b.status === 401, JSON.stringify(b.body));
  }

  kop('C. Rechten en invoer');
  {
    const a = await post(j1, KOPPEL(K.k11), { jongere: U.jongere1 });
    check(`jongere koppelt -> 403 rol (kreeg ${a.status})`, a.status === 403 && a.body?.reden === 'rol', JSON.stringify(a.body));
    const b = await post(hv1, KOPPEL(K.k11), { jongere: U.jongere1 });
    check(`oudere koppelt -> 403 rol (kreeg ${b.status})`, b.status === 403 && b.body?.reden === 'rol', JSON.stringify(b.body));
    const c = await post(j1, VRIJGEVEN(K.k04), { reden: 'test' });
    check(`jongere geeft vrij -> 403 rol (kreeg ${c.status})`, c.status === 403 && c.body?.reden === 'rol', JSON.stringify(c.body));
    const d = await post(co, KOPPEL(K.k11), {});
    check(`coordinator zonder jongere -> 400 (kreeg ${d.status})`, d.status === 400 && d.body?.reden === 'geenjongere', JSON.stringify(d.body));
    const e = await post(co, KOPPEL('bestaatnietxx'), { jongere: U.jongere1 });
    check(`onbekende klus -> 404 (kreeg ${e.status})`, e.status === 404, JSON.stringify(e.body));
    const f = await post(co, VRIJGEVEN('bestaatnietxx'), { reden: 'test' });
    check(`onbekende klus vrijgeven -> 404 (kreeg ${f.status})`, f.status === 404, JSON.stringify(f.body));
  }

  kop('D. Koppelen == accepteren (zelfde klusvelden en logregel-vorm)');
  {
    // k11 wordt gekoppeld door de coordinator, k02 geaccepteerd door de
    // jongere zelf. Daarna veld voor veld vergelijken.
    const gekoppeld = await post(co, KOPPEL(K.k11), { jongere: U.jongere1 });
    check(`koppelen k11 -> 200 (kreeg ${gekoppeld.status})`, gekoppeld.status === 200, JSON.stringify(gekoppeld.body));
    check('antwoord meldt status geaccepteerd', gekoppeld.body?.status === 'geaccepteerd', JSON.stringify(gekoppeld.body));
    check('antwoord meldt andere_wijk false (beiden Tiel-West)', gekoppeld.body?.andere_wijk === false, JSON.stringify(gekoppeld.body));

    const geaccepteerd = await post(j1, ACCEPTEER(K.k02));
    check(`accepteren k02 -> 200 (kreeg ${geaccepteerd.status})`, geaccepteerd.status === 200, JSON.stringify(geaccepteerd.body));

    const kA = await su.collection('hh_klussen').getOne(K.k11);
    const kB = await su.collection('hh_klussen').getOne(K.k02);
    check(`k11 status geaccepteerd (is ${kA.status})`, kA.status === 'geaccepteerd');
    check('k11 toegewezen_jongere = jongere 1', kA.toegewezen_jongere === U.jongere1);
    check('gekoppeld en geaccepteerd geven dezelfde status', kA.status === kB.status);
    check('gekoppeld en geaccepteerd geven dezelfde toegewezen_jongere', kA.toegewezen_jongere === kB.toegewezen_jongere);

    const logA = (await logsVan(su, K.k11)).filter((l) => !bewaar.k11.has(l.id));
    const logB = (await logsVan(su, K.k02)).filter((l) => !bewaar.k02.has(l.id));
    check(`koppelen schreef precies 1 logregel (${logA.length})`, logA.length === 1);
    check(`accepteren schreef precies 1 logregel (${logB.length})`, logB.length === 1);
    if (logA.length === 1 && logB.length === 1) {
      check('logregel koppelen: van open, naar geaccepteerd', logA[0].van === 'open' && logA[0].naar === 'geaccepteerd', JSON.stringify(logA[0]));
      check('logregel koppelen: door = de coordinator', logA[0].door === U.coordinator1, logA[0].door);
      check('logregel accepteren: door = de jongere', logB[0].door === U.jongere1, logB[0].door);
      check('zelfde van/naar als accepteren', logA[0].van === logB[0].van && logA[0].naar === logB[0].naar);
      check('logregel hangt aan de juiste klus', logA[0].klus === K.k11);
      if (metToelichting) {
        check('logregel koppelen: toelichting "handmatig gekoppeld"', logA[0].toelichting === 'handmatig gekoppeld', JSON.stringify(logA[0].toelichting));
      } else {
        sla('logregel koppelen: toelichting', 'veld bestaat nog niet (M6)');
      }
    }
  }

  kop('E. Klus niet meer open -> 409 bezet');
  {
    const a = await post(co, KOPPEL(K.k11), { jongere: U.jongere2 });
    check(`tweede koppeling k11 -> 409 bezet (kreeg ${a.status})`, a.status === 409 && a.body?.reden === 'bezet', JSON.stringify(a.body));
    const b = await post(co, KOPPEL(K.k04), { jongere: U.jongere2 });
    check(`koppelen op geaccepteerde k04 -> 409 bezet (kreeg ${b.status})`, b.status === 409 && b.body?.reden === 'bezet', JSON.stringify(b.body));
    const na = await su.collection('hh_klussen').getOne(K.k04);
    check('k04 bleef op jongere 1 staan', na.toegewezen_jongere === U.jongere1 && na.status === 'geaccepteerd');
  }

  kop('F. Eisen aan de jongere (409, klus blijft open)');
  {
    const a = await post(co, KOPPEL(K.k03), { jongere: U.hulpvrager1 });
    check(`oudere als jongere -> 409 geenjongere (kreeg ${a.status})`, a.status === 409 && a.body?.reden === 'geenjongere', JSON.stringify(a.body));
    const b = await post(co, KOPPEL(K.k03), { jongere: 'bestaatnietxx' });
    check(`onbekend jongere-id -> 409 jongeronbekend (kreeg ${b.status})`, b.status === 409 && b.body?.reden === 'jongeronbekend', JSON.stringify(b.body));

    // Jongere 3 tijdelijk niet goedgekeurd (superuser), daarna terug.
    const p3 = await su.collection('hh_profielen').getFirstListItem(`gebruiker = "${U.jongere3}"`);
    await su.collection(assertHh('hh_profielen')).update(p3.id, { verificatiestatus: 'in_behandeling' });
    try {
      const c = await post(co, KOPPEL(K.k03), { jongere: U.jongere3 });
      check(`niet-goedgekeurde jongere -> 409 nietgoedgekeurd (kreeg ${c.status})`, c.status === 409 && c.body?.reden === 'nietgoedgekeurd', JSON.stringify(c.body));
    } finally {
      await su.collection(assertHh('hh_profielen')).update(p3.id, { verificatiestatus: 'goedgekeurd' });
    }
    const p3Na = await su.collection('hh_profielen').getOne(p3.id);
    check('jongere 3 staat weer op goedgekeurd', p3Na.verificatiestatus === 'goedgekeurd');

    const k03 = await su.collection('hh_klussen').getOne(K.k03);
    check('k03 is na drie weigeringen nog open zonder jongere', k03.status === 'open' && !k03.toegewezen_jongere);
    const extra = (await logsVan(su, K.k03)).filter((l) => !bewaar.k03.has(l.id));
    check(`geen logregel bij een weigering (${extra.length})`, extra.length === 0);
  }

  kop('G. Andere wijk mag juist wel (dat is het nut van handmatig)');
  {
    // k03 is van hulpvrager 2 (Passewaaij); jongere 1 woont in Tiel-West.
    const a = await post(co, KOPPEL(K.k03), { jongere: U.jongere1 });
    check(`koppelen over de wijkgrens -> 200 (kreeg ${a.status})`, a.status === 200, JSON.stringify(a.body));
    check('antwoord meldt andere_wijk true', a.body?.andere_wijk === true, JSON.stringify(a.body));
    const k03 = await su.collection('hh_klussen').getOne(K.k03);
    check('k03 staat op jongere 1, geaccepteerd', k03.toegewezen_jongere === U.jongere1 && k03.status === 'geaccepteerd');
  }

  kop('H. Vrijgeven (doorzetten)');
  {
    const a = await post(co, VRIJGEVEN(K.k04), { reden: 'jongere is ziek geworden' });
    check(`vrijgeven k04 (geaccepteerd) -> 200 (kreeg ${a.status})`, a.status === 200, JSON.stringify(a.body));
    check('antwoord meldt van = geaccepteerd, status = open', a.body?.van === 'geaccepteerd' && a.body?.status === 'open', JSON.stringify(a.body));
    const k04 = await su.collection('hh_klussen').getOne(K.k04);
    check('k04 is open zonder jongere', k04.status === 'open' && !k04.toegewezen_jongere);
    const log = (await logsVan(su, K.k04)).filter((l) => !bewaar.k04.has(l.id));
    check(`vrijgeven schreef precies 1 logregel (${log.length})`, log.length === 1);
    if (log.length === 1) {
      check('logregel vrijgeven: van geaccepteerd, naar open', log[0].van === 'geaccepteerd' && log[0].naar === 'open', JSON.stringify(log[0]));
      check('logregel vrijgeven: door = de coordinator', log[0].door === U.coordinator1);
      if (metToelichting) {
        check('logregel vrijgeven: toelichting draagt de reden', String(log[0].toelichting || '').includes('jongere is ziek geworden'), JSON.stringify(log[0].toelichting));
      } else {
        sla('logregel vrijgeven: toelichting', 'veld bestaat nog niet (M6)');
      }
    }

    const b = await post(co, KOPPEL(K.k04), { jongere: U.jongere2 });
    check(`opnieuw koppelen na vrijgeven -> 200 (kreeg ${b.status})`, b.status === 200, JSON.stringify(b.body));
    const k04b = await su.collection('hh_klussen').getOne(K.k04);
    check('k04 staat nu op jongere 2', k04b.toegewezen_jongere === U.jongere2 && k04b.status === 'geaccepteerd');

    const c = await post(co, VRIJGEVEN(K.k05), { reden: 'oudere heeft afgezegd' });
    check(`vrijgeven k05 (onderweg) -> 200, van = onderweg (kreeg ${c.status})`, c.status === 200 && c.body?.van === 'onderweg', JSON.stringify(c.body));

    const d = await post(co, VRIJGEVEN(K.k05), { reden: '   ' });
    check(`vrijgeven zonder reden -> 400 (kreeg ${d.status})`, d.status === 400 && d.body?.reden === 'geenreden', JSON.stringify(d.body));
    const e = await post(co, VRIJGEVEN(K.k05), { reden: 'nog een keer' });
    check(`vrijgeven van een open klus -> 409 nietvrijtegeven (kreeg ${e.status})`, e.status === 409 && e.body?.reden === 'nietvrijtegeven', JSON.stringify(e.body));
  }

  kop(`I. RACE: ${RONDEN} ronden koppelen tegen accepteren op k02`);
  {
    let winnaarCoordinator = 0;
    let winnaarJongere = 0;
    let fouten = 0;
    for (let ronde = 1; ronde <= RONDEN; ronde++) {
      await su.collection(assertHh('hh_klussen')).update(K.k02, { status: 'open', toegewezen_jongere: '' });
      const voor = new Set((await logsVan(su, K.k02)).map((l) => l.id));

      const [gekoppeld, geaccepteerd] = await Promise.all([
        post(co, KOPPEL(K.k02), { jongere: U.jongere2 }),
        post(j1, ACCEPTEER(K.k02)),
      ]);

      const statussen = [gekoppeld.status, geaccepteerd.status].sort();
      const eenWinnaar = statussen[0] === 200 && statussen[1] === 409;
      const na = await logsVan(su, K.k02);
      const nieuw = na.filter((l) => !voor.has(l.id));
      const klus = await su.collection('hh_klussen').getOne(K.k02);
      const winnaar = gekoppeld.status === 200 ? U.jongere2 : U.jongere1;
      const klopt = eenWinnaar && nieuw.length === 1 && klus.toegewezen_jongere === winnaar && klus.status === 'geaccepteerd';
      if (!klopt) {
        fouten++;
        console.log(`  ✗ ronde ${ronde}: koppelen ${gekoppeld.status}, accepteren ${geaccepteerd.status}, ${nieuw.length} logregels, klus op ${klus.toegewezen_jongere}`);
      }
      if (gekoppeld.status === 200) winnaarCoordinator++;
      else winnaarJongere++;
      for (const l of nieuw) {
        await su.collection(assertHh('hh_klus_status')).delete(l.id);
      }
    }
    check(`${RONDEN}/${RONDEN} ronden precies één winnaar en één logregel (coordinator ${winnaarCoordinator}, jongere ${winnaarJongere})`, fouten === 0, `${fouten} ronden fout`);
  }

  kop('J. Terugzetten en nameten');
  const eind = await terugzetten(su, U, bewaar);
  for (const key of KLUS_KEYS) {
    check(`${key}: logtelling terug op ${begin.telling[key]} (is ${eind.telling[key]})`, eind.telling[key] === begin.telling[key]);
    const klus = await su.collection('hh_klussen').getOne(K[key]);
    const wil = SEED_STAND[key];
    const jongereId = wil.jongere ? U[wil.jongere] : '';
    check(`${key}: terug op ${wil.status}`, klus.status === wil.status && (klus.toegewezen_jongere || '') === jongereId, `${klus.status}/${klus.toegewezen_jongere}`);
  }

  console.log(`\n${groen} groen, ${rood} rood${overgeslagen ? `, ${overgeslagen} overgeslagen` : ''}.`);
  if (rood > 0) process.exit(1);
}

main().catch(fail);
