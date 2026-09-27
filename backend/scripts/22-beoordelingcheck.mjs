// HeitjeHulp M7 — bewijst beoordelen en reputatie op de ECHTE server met de
// ECHTE seed-accounts (backend/seed-accounts.local.json, nooit loggen). Werkt
// met EIGEN klussen met het merk "[beoordelingcheck]" (oudere 1, Tiel-West,
// met lat/lon zodat er geen Nominatim-verzoek nodig is); de twaalf
// seed-klussen worden niet aangeraakt. Alles wordt aan het eind opgeruimd,
// inclusief de reputatievelden van de betrokken accounts.
//
//   A. opruimen van een eerdere (gecrashte) run + de beginstand onthouden
//   B. voorwaarden: de twee velden staan op hh_users, de sloten staan in de
//      createRule en de updateRule, de unieke index klus+van_gebruiker bestaat
//   C. niet bij een klus die nog niet afgerond is -> geweigerd
//   D. een vreemde (jongere 2) beoordeelt een klus van een ander -> geweigerd;
//      jezelf beoordelen -> geweigerd
//   E. de oudere beoordeelt de jongere; tweede keer dezelfde kant -> geweigerd
//      (unieke index); de jongere beoordeelt de oudere -> mag wel
//   F. gemiddelde en telling kloppen na 1, 2 en 3 beoordelingen van de jongere
//      (5 -> 5,0 / 5+4 -> 4,5 / 5+4+4 -> 4,3) en na een WIJZIGING (4 -> 2 geeft
//      3,7), op hh_users EN op hh_profielen
//   G. sterren_gemiddeld of klussen_aantal zelf meesturen -> geweigerd, bij
//      bijwerken van je eigen account en bij registreren
//   H. de oudere ziet de twee velden van zijn toegewezen jongere
//   I. opruimen en nameten
//
// Wijzigt geen rules en geen velden (dat doen 20 en 21). Herhaalbaar.
// Opruim-knop na een handmatige app-test:
//   node scripts/22-beoordelingcheck.mjs --apply --alleen-opruimen
//
// DRAAIEN (na 20 --apply, 21 --apply en 10-hook-deploy.sh):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/22-beoordelingcheck.mjs --apply    (zonder --apply: alleen uitleg + leescontroles)

import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, userClient, assertHh, APPLY, fail, PB_URL } from './_lib.mjs';
import { REPUTATIE_VELDEN } from './20-reputatie-velden.mjs';
import { REPUTATIE_SLOT } from './21-reputatie-rules.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ACCOUNTS_FILE = path.resolve(__dirname, '..', 'seed-accounts.local.json');
const MERK = '[beoordelingcheck]';
const ALLEEN_OPRUIMEN = process.argv.includes('--alleen-opruimen');

// Tiel-West; lat/lon gevuld zodat de geocoding-hook niets hoeft te doen.
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

// Een create/update die MAG mislukken; geeft {status, record} terug, gooit nooit.
async function probeer(actie) {
  try {
    return { status: 200, record: await actie() };
  } catch (e) {
    return { status: e?.status ?? 0, record: null, body: e?.response ?? {} };
  }
}

// Alle eigen klussen weghalen; hun beoordelingen horen daar niet bij (geen
// cascade op hh_beoordelingen), dus die gaan eerst apart weg.
async function opruimen(su) {
  const eigen = await su.collection('hh_klussen').getFullList({ filter: `omschrijving ~ "${MERK}"` });
  let beoordelingenWeg = 0;
  for (const k of eigen) {
    const rijen = await su.collection('hh_beoordelingen').getFullList({ filter: `klus = "${k.id}"` });
    for (const b of rijen) {
      await su.collection(assertHh('hh_beoordelingen')).delete(b.id);
      beoordelingenWeg++;
    }
    await su.collection(assertHh('hh_klussen')).delete(k.id);
  }
  if (eigen.length || beoordelingenWeg) {
    console.log(`  ↻ ${eigen.length} eigen klus(sen) en ${beoordelingenWeg} beoordeling(en) verwijderd`);
  }
  return { klussen: eigen.length, beoordelingen: beoordelingenWeg };
}

// De twee reputatievelden van een gebruiker, gelezen als superuser.
async function reputatie(su, gebruikerId) {
  const u = await su.collection('hh_users').getOne(gebruikerId);
  let profiel = null;
  try {
    profiel = await su.collection('hh_profielen').getFirstListItem(`gebruiker = "${gebruikerId}"`);
  } catch (_) {
    profiel = null;
  }
  return {
    sterren: Number(u.sterren_gemiddeld ?? 0),
    aantal: Number(u.klussen_aantal ?? 0),
    profielSterren: profiel ? Number(profiel.sterren_gemiddeld ?? 0) : null,
    profielAantal: profiel ? Number(profiel.klussen_aantal ?? 0) : null,
  };
}

// De reputatievelden terugzetten op de waarde van vóór de run.
async function herstelReputatie(su, gebruikerId, begin) {
  await su
    .collection(assertHh('hh_users'))
    .update(gebruikerId, { sterren_gemiddeld: begin.sterren, klussen_aantal: begin.aantal });
  if (begin.profielSterren !== null) {
    const profiel = await su.collection('hh_profielen').getFirstListItem(`gebruiker = "${gebruikerId}"`);
    await su
      .collection(assertHh('hh_profielen'))
      .update(profiel.id, { sterren_gemiddeld: begin.profielSterren, klussen_aantal: begin.profielAantal });
  }
}

/// De leescontroles die ZONDER --apply al iets kunnen bewijzen: velden, rules
/// en index staan er of niet. Schrijft niets.
async function voorwaarden(su) {
  kop('B. Voorwaarden op de server (alleen lezen)');
  const users = await su.collections.getOne('hh_users');
  const namen = new Set(users.fields.map((f) => f.name));
  for (const veld of REPUTATIE_VELDEN) {
    check(`hh_users.${veld.name} bestaat`, namen.has(veld.name), 'draai 20-reputatie-velden.mjs --apply');
  }
  for (const k of ['createRule', 'updateRule']) {
    check(
      `hh_users.${k} blokkeert de reputatievelden`,
      String(users[k] ?? '').includes(REPUTATIE_SLOT),
      'draai 21-reputatie-rules.mjs --apply',
    );
  }
  const beoordelingen = await su.collections.getOne('hh_beoordelingen');
  const index = (beoordelingen.indexes || []).some(
    (i) => i.toLowerCase().includes('unique') && i.includes('klus') && i.includes('van_gebruiker'),
  );
  check('hh_beoordelingen heeft de unieke index klus + van_gebruiker', index);
  const profielen = await su.collections.getOne('hh_profielen');
  const profielNamen = new Set(profielen.fields.map((f) => f.name));
  check(
    'hh_profielen heeft de twee velden al (M1)',
    profielNamen.has('sterren_gemiddeld') && profielNamen.has('klussen_aantal'),
  );
}

async function main() {
  assertHh('hh_beoordelingen');
  assertHh('hh_klussen');
  assertHh('hh_users');
  assertHh('hh_profielen');

  const su = await superuserClient();
  console.log('Verbonden met', PB_URL, APPLY ? '(APPLY)' : '(DRY-RUN)', '\n');

  if (!APPLY) {
    console.log('DRY-RUN: er wordt NIETS geschreven. Hieronder eerst de leescontroles; daarna staat');
    console.log('beschreven wat --apply zou doen.');
    await voorwaarden(su);
    console.log('\nWat --apply ZOU doen:');
    console.log(`  · inloggen als de seed-accounts en EIGEN klussen maken met het merk "${MERK}"`);
    console.log('    (oudere 1, Tiel-West), die via de hook-routes tot afgerond brengen;');
    console.log('  · bewijzen dat een beoordeling alleen bij afgerond, alleen door een deelnemer en');
    console.log('    maar één keer per kant per klus kan;');
    console.log('  · na 1, 2 en 3 beoordelingen en na een wijziging het gemiddelde en de telling');
    console.log('    nameten op hh_users én hh_profielen (5,0 / 4,5 / 4,3 / 3,7);');
    console.log('  · bewijzen dat sterren_gemiddeld en klussen_aantal niet mee te sturen zijn;');
    console.log('  · bewijzen dat de oudere de twee velden van zijn jongere ziet;');
    console.log('  · alles opruimen en de reputatievelden terugzetten op de beginstand.');
    console.log(`\n${groen} groen, ${rood} rood (${groen + rood} leescontroles).`);
    if (rood > 0) {
      console.log('Rood is hier GEEN fout zolang 20 en 21 nog niet met --apply gedraaid zijn: de');
      console.log('dry-run meet de server zoals hij nu is. Na de uitrol horen alle zes groen te zijn.');
    }
    console.log('Draai met --apply voor de rest.');
    return;
  }

  if (!existsSync(ACCOUNTS_FILE)) throw new Error(`${ACCOUNTS_FILE} ontbreekt — draai eerst 03-seed.mjs --apply`);
  const acc = JSON.parse(readFileSync(ACCOUNTS_FILE, 'utf8'));

  kop('A. Opruimen van een eerdere run');
  const wegBegin = await opruimen(su);
  check(`${wegBegin.klussen} achtergebleven ${MERK}-klus(sen) opgeruimd`, true);
  if (ALLEEN_OPRUIMEN) {
    console.log(`\n${groen} groen, ${rood} rood. Alleen opgeruimd.`);
    return;
  }

  const jongereId = acc.jongere1.id;
  const oudereId = acc.hulpvrager1.id;
  const beginJongere = await reputatie(su, jongereId);
  const beginOudere = await reputatie(su, oudereId);
  console.log(
    `  · beginstand jongere 1: ${beginJongere.sterren} sterren, ${beginJongere.aantal} klussen (wordt teruggezet)`,
  );

  await voorwaarden(su);

  const hv1 = await userClient(acc.hulpvrager1.email, acc.hulpvrager1.password);
  const j1 = await userClient(acc.jongere1.email, acc.jongere1.password);
  const j2 = await userClient(acc.jongere2.email, acc.jongere2.password);

  const klustype = await su.collection('hh_klustypes').getFirstListItem('naam = "boodschappen"');
  const nu = new Date();

  /// Een eigen klus van oudere 1, meteen op open, en daarna via de M6-routes
  /// naar afgerond gebracht door jongere 1.
  async function klusTotAfgerond(label) {
    const van = new Date(nu.getTime() + 24 * 3600 * 1000);
    const klus = await hv1.collection('hh_klussen').create({
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
    });
    await j1.send(`/api/hh/klussen/${klus.id}/accepteren`, { method: 'POST' });
    for (const naar of ['onderweg', 'bezig', 'afgerond']) {
      await j1.send(`/api/hh/klussen/${klus.id}/status`, { method: 'POST', body: { naar } });
    }
    return klus.id;
  }

  // van_gebruiker moet de ingelogde gebruiker zelf zijn; de rule eist dat
  // expliciet, dus we sturen het id mee.
  const beoordeelAls = (client, vanId, klusId, naarId, sterren, tekst = '') =>
    probeer(() =>
      client
        .collection('hh_beoordelingen')
        .create({ klus: klusId, van_gebruiker: vanId, naar_gebruiker: naarId, sterren, tekst }),
    );

  kop('C. Niet bij een klus die nog niet afgerond is');
  {
    const van = new Date(nu.getTime() + 24 * 3600 * 1000);
    const open = await hv1.collection('hh_klussen').create({
      hulpvrager: oudereId,
      geplaatst_door: oudereId,
      klustype: klustype.id,
      omschrijving: `${MERK} nog open`,
      adres: ADRES,
      lat: LAT,
      lon: LON,
      wanneer_van: van.toISOString(),
      status: 'open',
      bron: 'app',
    });
    const r = await beoordeelAls(hv1, oudereId, open.id, jongereId, 5);
    check('beoordeling op een open klus geweigerd', r.status !== 200, `status ${r.status}`);
  }

  const klus1 = await klusTotAfgerond('klus 1');

  kop('D. Alleen deelnemers, nooit jezelf');
  {
    const vreemde = await beoordeelAls(j2, acc.jongere2.id, klus1, oudereId, 5);
    check('jongere 2 (geen deelnemer) geweigerd', vreemde.status !== 200, `status ${vreemde.status}`);
    const zelf = await beoordeelAls(hv1, oudereId, klus1, oudereId, 5);
    check('jezelf beoordelen geweigerd', zelf.status !== 200, `status ${zelf.status}`);
    const namensAnder = await beoordeelAls(hv1, jongereId, klus1, oudereId, 5);
    check('beoordelen namens een ander geweigerd', namensAnder.status !== 200, `status ${namensAnder.status}`);
  }

  kop('E. Eén per kant per klus');
  let eerste = null;
  {
    const r = await beoordeelAls(hv1, oudereId, klus1, jongereId, 5, 'Heel vriendelijk.');
    check('de oudere beoordeelt de jongere', r.status === 200, `status ${r.status}`);
    eerste = r.record;
    const nogmaals = await beoordeelAls(hv1, oudereId, klus1, jongereId, 4);
    check('tweede beoordeling van dezelfde kant geweigerd', nogmaals.status !== 200, `status ${nogmaals.status}`);
    const andereKant = await beoordeelAls(j1, jongereId, klus1, oudereId, 5, 'Prettig contact.');
    check('de jongere beoordeelt de oudere wel', andereKant.status === 200, `status ${andereKant.status}`);
  }

  kop('F. Gemiddelde en telling');
  {
    const na1 = await reputatie(su, jongereId);
    check(`na 1 beoordeling (5) is het gemiddelde 5 — gemeten ${na1.sterren}`, na1.sterren === 5);
    check(`de telling staat op 1 afgeronde klus — gemeten ${na1.aantal}`, na1.aantal === beginJongere.aantal + 1);
    check(
      `hh_profielen krijgt dezelfde waarden — gemeten ${na1.profielSterren}/${na1.profielAantal}`,
      na1.profielSterren === na1.sterren && na1.profielAantal === na1.aantal,
    );

    const klus2 = await klusTotAfgerond('klus 2');
    const r2 = await beoordeelAls(hv1, oudereId, klus2, jongereId, 4);
    check('tweede beoordeling aangemaakt', r2.status === 200, `status ${r2.status}`);
    const na2 = await reputatie(su, jongereId);
    check(`5 en 4 geeft 4,5 — gemeten ${na2.sterren}`, na2.sterren === 4.5);
    check(`de telling staat op 2 — gemeten ${na2.aantal}`, na2.aantal === beginJongere.aantal + 2);

    const klus3 = await klusTotAfgerond('klus 3');
    const r3 = await beoordeelAls(hv1, oudereId, klus3, jongereId, 4);
    check('derde beoordeling aangemaakt', r3.status === 200, `status ${r3.status}`);
    const na3 = await reputatie(su, jongereId);
    check(`5, 4 en 4 geeft 4,3 (afgerond op 1 decimaal) — gemeten ${na3.sterren}`, na3.sterren === 4.3);
    check(`de telling staat op 3 — gemeten ${na3.aantal}`, na3.aantal === beginJongere.aantal + 3);

    // Wijzigen mag (eigen beoordeling, zonder klus/van/naar mee te sturen).
    const gewijzigd = await probeer(() =>
      hv1.collection('hh_beoordelingen').update(r3.record.id, { sterren: 2, tekst: 'Toch minder goed.' }),
    );
    check('de oudere mag zijn eigen beoordeling wijzigen', gewijzigd.status === 200, `status ${gewijzigd.status}`);
    const naWijziging = await reputatie(su, jongereId);
    check(`5, 4 en 2 geeft 3,7 — gemeten ${naWijziging.sterren}`, naWijziging.sterren === 3.7);
    check(
      `hh_profielen loopt mee na de wijziging — gemeten ${naWijziging.profielSterren}`,
      naWijziging.profielSterren === naWijziging.sterren,
    );

    const klusWijzigen = await probeer(() =>
      hv1.collection('hh_beoordelingen').update(eerste.id, { klus: klus2, sterren: 5 }),
    );
    check('klus meesturen bij wijzigen geweigerd', klusWijzigen.status !== 200, `status ${klusWijzigen.status}`);
    const verwijderen = await probeer(() => hv1.collection('hh_beoordelingen').delete(eerste.id));
    check('verwijderen door de gever geweigerd', verwijderen.status !== 200, `status ${verwijderen.status}`);
  }

  kop('G. De reputatievelden zijn niet mee te sturen');
  {
    const eigen = await probeer(() => j1.collection('hh_users').update(jongereId, { sterren_gemiddeld: 5 }));
    check('eigen sterren_gemiddeld zetten geweigerd', eigen.status !== 200, `status ${eigen.status}`);
    const eigenAantal = await probeer(() => j1.collection('hh_users').update(jongereId, { klussen_aantal: 99 }));
    check('eigen klussen_aantal zetten geweigerd', eigenAantal.status !== 200, `status ${eigenAantal.status}`);
    const gewoon = await probeer(() => j1.collection('hh_users').update(jongereId, { telefoon: '06-10000001' }));
    check('een gewone wijziging (telefoon) mag nog wel', gewoon.status === 200, `status ${gewoon.status}`);

    const registratie = await probeer(() =>
      su.collection('hh_users').create({
        email: `hh-beoordelingcheck-${Date.now()}@qawayah.nl`,
        password: 'beoordelingcheck1234',
        passwordConfirm: 'beoordelingcheck1234',
        rol: 'jongere',
        naam: 'Beoordelingcheck',
        taal: 'nl',
        sterren_gemiddeld: 5,
      }),
    );
    check('registreren met sterren_gemiddeld geweigerd', registratie.status !== 200, `status ${registratie.status}`);
    if (registratie.status === 200 && registratie.record) {
      await su.collection(assertHh('hh_users')).delete(registratie.record.id);
      console.log('  ↻ het toch aangemaakte proefaccount is weer verwijderd');
    }
  }

  kop('H. De oudere ziet de reputatie van zijn jongere');
  {
    const gezien = await probeer(() => hv1.collection('hh_users').getOne(jongereId));
    check('de oudere mag de rij van zijn jongere lezen', gezien.status === 200, `status ${gezien.status}`);
    if (gezien.record) {
      check(
        `sterren_gemiddeld komt mee — gemeten ${gezien.record.sterren_gemiddeld}`,
        Number(gezien.record.sterren_gemiddeld ?? -1) === 3.7,
      );
      check('klussen_aantal komt mee', Number(gezien.record.klussen_aantal ?? -1) > 0);
    }
    const vreemde = await probeer(() => j2.collection('hh_users').getOne(jongereId));
    check('jongere 2 mag die rij niet lezen', vreemde.status !== 200, `status ${vreemde.status}`);
  }

  kop('I. Opruimen en nameten');
  {
    const weg = await opruimen(su);
    check(`${weg.klussen} eigen klus(sen) en ${weg.beoordelingen} beoordeling(en) verwijderd`, weg.klussen > 0);
    const over = await su.collection('hh_klussen').getFullList({ filter: `omschrijving ~ "${MERK}"` });
    check('geen eigen klussen meer over', over.length === 0, `${over.length} over`);

    await herstelReputatie(su, jongereId, beginJongere);
    await herstelReputatie(su, oudereId, beginOudere);
    const terugJongere = await reputatie(su, jongereId);
    check(
      'de reputatie van jongere 1 staat weer op de beginstand',
      terugJongere.sterren === beginJongere.sterren && terugJongere.aantal === beginJongere.aantal,
      `${terugJongere.sterren}/${terugJongere.aantal}`,
    );
    const seed = await su.collection('hh_klussen').getFullList({ filter: 'omschrijving ~ "[seed "' });
    check(`de twaalf seed-klussen staan er nog (${seed.length})`, seed.length === 12, `${seed.length} seed-klussen`);
  }

  console.log(`\n${groen} groen, ${rood} rood (${groen + rood} checks).`);
  if (rood > 0) process.exit(1);
}

main().catch(fail);
