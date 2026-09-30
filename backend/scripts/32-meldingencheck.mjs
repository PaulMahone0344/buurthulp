// HeitjeHulp M8 — bewijst de meldingen (laag 1) op de ECHTE server met de
// ECHTE seed-accounts (backend/seed-accounts.local.json, nooit loggen). Werkt
// met EIGEN klussen en incidenten met het merk "[meldingencheck]" (oudere 1,
// Tiel-West, met lat/lon zodat er geen Nominatim-verzoek nodig is); de
// seed-klussen worden niet aangeraakt. Alles wordt aan het eind opgeruimd.
//
//   A. opruimen van een eerdere (gecrashte) run
//   B. voorwaarden (ook in dry-run): hh_meldingen bestaat met alle velden,
//      de twee indexen, de rules van 31; hh_incidenten.createRule staat open
//   C. per trigger precies één melding bij de juiste ontvanger:
//      open -> jongeren in de wijk (1 en 2, niet 3 in Passewaaij);
//      geaccepteerd/onderweg -> oudere; bezig -> niemand; afgerond -> oudere
//      en jongere; jongere geeft terug -> oudere + de andere jongere; oudere
//      annuleert -> de jongere
//   D. geen dubbele: elke (ontvanger, soort, sleutel) één keer, en een
//      dubbele als superuser loopt op de unieke index
//   E. een vreemde leest niets
//   F. de ontvanger kan alleen gelezen_op zetten
//   G. aanmaken via de API geweigerd, ook voor de coordinator
//   H. incident nood -> melding bij elke coordinator (+ familielid als er een
//      koppeling is); incident probleem -> alleen de coordinatoren
//   I. opruimen en nameten
//
// Wijzigt geen rules en geen velden (dat doen 30 en 31). Herhaalbaar.
// Opruim-knop na een handmatige app-test:
//   node scripts/32-meldingencheck.mjs --apply --alleen-opruimen
//
// DRAAIEN (na 30 --apply, 31 --apply en 33-hook-deploy.sh):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/32-meldingencheck.mjs            (dry-run: alleen leescontroles)
//   node scripts/32-meldingencheck.mjs --apply

import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, userClient, assertHh, APPLY, fail, PB_URL } from './_lib.mjs';
import { COLLECTIE, MELDING_INDEXEN, meldingVelden } from './30-meldingen-collectie.mjs';
import { MELDINGEN_RULES } from './31-meldingen-rules.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ACCOUNTS_FILE = path.resolve(__dirname, '..', 'seed-accounts.local.json');
const MERK = '[meldingencheck]';
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
    return { status: e?.status ?? 0, record: null };
  }
}

const wacht = (ms) => new Promise((r) => setTimeout(r, ms));

/// De meldingen met een sleutel, als superuser. De after-success-hook loopt
/// na de transactie; we wachten hooguit drie seconden tot er [minstens]
/// staan.
async function meldingenMet(su, sleutel, minstens = 0) {
  let rijen = [];
  for (let poging = 0; poging < 6; poging++) {
    rijen = await su.collection(COLLECTIE).getFullList({
      filter: su.filter('sleutel = {:sleutel}', { sleutel }),
    });
    if (rijen.length >= minstens) break;
    await wacht(500);
  }
  return rijen;
}

const paren = (rijen) => rijen.map((m) => `${m.ontvanger}:${m.soort}`).sort();

async function opruimen(su) {
  const klussen = await su.collection('hh_klussen').getFullList({
    filter: su.filter('omschrijving ~ {:merk}', { merk: MERK }),
  });
  const incidenten = await su.collection('hh_incidenten').getFullList({
    filter: su.filter('omschrijving ~ {:merk}', { merk: MERK }),
  });
  let meldingen = 0;
  for (const k of klussen) {
    const rijen = await su.collection(COLLECTIE).getFullList({ filter: su.filter('klus = {:id}', { id: k.id }) });
    for (const m of rijen) {
      await su.collection(assertHh(COLLECTIE)).delete(m.id);
      meldingen++;
    }
  }
  for (const i of incidenten) {
    const rijen = await su.collection(COLLECTIE).getFullList({ filter: su.filter('incident = {:id}', { id: i.id }) });
    for (const m of rijen) {
      await su.collection(assertHh(COLLECTIE)).delete(m.id);
      meldingen++;
    }
    await su.collection(assertHh('hh_incidenten')).delete(i.id);
  }
  for (const k of klussen) await su.collection(assertHh('hh_klussen')).delete(k.id);
  if (klussen.length || incidenten.length || meldingen) {
    console.log(`  ↻ ${klussen.length} klus(sen), ${incidenten.length} incident(en) en ${meldingen} melding(en) verwijderd`);
  }
  return { klussen: klussen.length, incidenten: incidenten.length, meldingen };
}

/// Leescontroles die ook zonder --apply iets bewijzen. Schrijft niets.
async function voorwaarden(su) {
  kop('B. Voorwaarden op de server (alleen lezen)');
  let col = null;
  try {
    col = await su.collections.getOne(COLLECTIE);
  } catch (_) {
    col = null;
  }
  check(`${COLLECTIE} bestaat`, !!col, 'draai 30-meldingen-collectie.mjs --apply');
  if (col) {
    const namen = new Set(col.fields.map((f) => f.name));
    const nodig = meldingVelden({ hh_users: '', hh_klussen: '', hh_incidenten: '' }).map((f) => f.name);
    const mist = nodig.filter((n) => !namen.has(n));
    check('alle velden aanwezig (ook sleutel)', mist.length === 0, `mist: ${mist.join(', ')}`);
    const idx = (col.indexes || []).map((i) => i.replace(/\s+/g, ' '));
    for (const gewenst of MELDING_INDEXEN) {
      check(`index: ${gewenst.split(' ON ')[0]}`, idx.includes(gewenst.replace(/\s+/g, ' ')));
    }
    for (const [k, v] of Object.entries(MELDINGEN_RULES)) {
      check(`${k} zoals 31 hem zet`, (col[k] ?? null) === v, `staat: ${JSON.stringify(col[k] ?? null)}`);
    }
  }
  const incidenten = await su.collections.getOne('hh_incidenten');
  check('hh_incidenten.createRule staat open voor ingelogde gebruikers', !!incidenten.createRule);
}

async function main() {
  assertHh(COLLECTIE);
  assertHh('hh_klussen');
  assertHh('hh_incidenten');

  const su = await superuserClient();
  console.log('Verbonden met', PB_URL, APPLY ? '(APPLY)' : '(DRY-RUN)', '\n');

  if (!APPLY) {
    console.log('DRY-RUN: er wordt NIETS geschreven.');
    await voorwaarden(su);
    console.log('\nWat --apply ZOU doen:');
    console.log(`  · eigen klussen en incidenten maken met het merk "${MERK}" (oudere 1, Tiel-West)`);
    console.log('    en ze via de hook-routes laten wisselen: open, geaccepteerd, onderweg, bezig,');
    console.log('    afgerond, teruggeven door de jongere, annuleren door de oudere;');
    console.log('  · per wissel nameten wie welke melding kreeg, en dat er niets dubbel is;');
    console.log('  · bewijzen dat een vreemde niets leest, de ontvanger alleen gelezen_op zet');
    console.log('    en niemand via de API een melding maakt;');
    console.log('  · een noodmelding en een probleem melden en de meldingen bij de coordinatoren');
    console.log('    (en het familielid bij nood) tellen;');
    console.log('  · alles opruimen.');
    console.log(`\n${groen} groen, ${rood} rood (leescontroles).`);
    if (rood > 0) console.log('Rood is verwacht zolang 30 en 31 nog niet met --apply gedraaid zijn.');
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

  const oudereId = acc.hulpvrager1.id;
  const j1Id = acc.jongere1.id;
  const j2Id = acc.jongere2.id;
  const j3Id = acc.jongere3.id;
  const hv1 = await userClient(acc.hulpvrager1.email, acc.hulpvrager1.password);
  const j1 = await userClient(acc.jongere1.email, acc.jongere1.password);
  const j2 = await userClient(acc.jongere2.email, acc.jongere2.password);
  const j3 = await userClient(acc.jongere3.email, acc.jongere3.password);
  const co = await userClient(acc.coordinator1.email, acc.coordinator1.password);

  const klustype = await su.collection('hh_klustypes').getFirstListItem('naam = "boodschappen"');
  const nu = new Date();

  async function nieuweKlus(label) {
    const van = new Date(nu.getTime() + 24 * 3600 * 1000);
    return hv1.collection('hh_klussen').create({
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
  }

  /// De laatste logregel van een klus: zijn id is de sleutel van de melding.
  async function laatsteLog(klusId) {
    const rijen = await su.collection('hh_klus_status').getFullList({
      filter: su.filter('klus = {:id}', { id: klusId }),
      sort: '-created,-id',
    });
    return rijen[0];
  }

  async function stap(client, klusId, naar) {
    await client.send(`/api/hh/klussen/${klusId}/status`, { method: 'POST', body: { naar } });
    return laatsteLog(klusId);
  }

  kop('C. Per trigger één melding bij de juiste ontvanger');
  const klus1 = await nieuweKlus('klus 1');
  {
    const log = await laatsteLog(klus1.id);
    const rijen = await meldingenMet(su, `klusstatus:${log.id}`, 2);
    const ontvangers = paren(rijen);
    check('open -> jongere 1 en 2 krijgen "nieuwe_klus"', ontvangers.includes(`${j1Id}:nieuwe_klus`) && ontvangers.includes(`${j2Id}:nieuwe_klus`), ontvangers.join(' '));
    check('open -> jongere 3 (Passewaaij) krijgt niets', !ontvangers.some((o) => o.startsWith(j3Id)));
    check('open -> de oudere zelf krijgt niets', !ontvangers.some((o) => o.startsWith(oudereId)));
  }
  await j1.send(`/api/hh/klussen/${klus1.id}/accepteren`, { method: 'POST' });
  {
    const log = await laatsteLog(klus1.id);
    const rijen = await meldingenMet(su, `klusstatus:${log.id}`, 1);
    check('geaccepteerd -> alleen de oudere, soort toegewezen', paren(rijen).join() === `${oudereId}:toegewezen`, paren(rijen).join(' '));
  }
  {
    const log = await stap(j1, klus1.id, 'onderweg');
    const rijen = await meldingenMet(su, `klusstatus:${log.id}`, 1);
    check('onderweg -> alleen de oudere', paren(rijen).join() === `${oudereId}:onderweg`, paren(rijen).join(' '));
  }
  {
    const log = await stap(j1, klus1.id, 'bezig');
    await wacht(1000);
    const rijen = await meldingenMet(su, `klusstatus:${log.id}`);
    check('bezig -> niemand', rijen.length === 0, `${rijen.length} melding(en)`);
  }
  {
    const log = await stap(j1, klus1.id, 'afgerond');
    const rijen = await meldingenMet(su, `klusstatus:${log.id}`, 2);
    check(
      'afgerond -> de oudere en de jongere',
      paren(rijen).join() === [`${j1Id}:afgerond`, `${oudereId}:afgerond`].sort().join(),
      paren(rijen).join(' '),
    );
  }

  const klus2 = await nieuweKlus('klus 2 (jongere geeft terug)');
  await j1.send(`/api/hh/klussen/${klus2.id}/accepteren`, { method: 'POST' });
  await j1.send(`/api/hh/klussen/${klus2.id}/annuleren`, { method: 'POST', body: { reden: `${MERK} kan toch niet` } });
  {
    const log = await laatsteLog(klus2.id);
    const rijen = await meldingenMet(su, `klusstatus:${log.id}`, 2);
    const ontvangers = paren(rijen);
    check('terug naar open -> de oudere hoort het', ontvangers.includes(`${oudereId}:geannuleerd`), ontvangers.join(' '));
    check('terug naar open -> jongere 2 krijgt hem opnieuw aangeboden', ontvangers.includes(`${j2Id}:nieuwe_klus`));
    check('terug naar open -> jongere 1 (die hem teruggaf) niet', !ontvangers.some((o) => o.startsWith(j1Id)));
  }

  const klus3 = await nieuweKlus('klus 3 (oudere annuleert)');
  await j2.send(`/api/hh/klussen/${klus3.id}/accepteren`, { method: 'POST' });
  await hv1.send(`/api/hh/klussen/${klus3.id}/annuleren`, { method: 'POST', body: { reden: `${MERK} toch niet nodig` } });
  {
    const log = await laatsteLog(klus3.id);
    const rijen = await meldingenMet(su, `klusstatus:${log.id}`, 1);
    check('oudere annuleert -> alleen de jongere', paren(rijen).join() === `${j2Id}:geannuleerd`, paren(rijen).join(' '));
  }

  kop('D. Geen dubbele meldingen');
  const alleEigen = [];
  for (const k of [klus1, klus2, klus3]) {
    alleEigen.push(...(await su.collection(COLLECTIE).getFullList({ filter: su.filter('klus = {:id}', { id: k.id }) })));
  }
  {
    const sleutels = alleEigen.map((m) => `${m.ontvanger}|${m.soort}|${m.sleutel}`);
    check(`${alleEigen.length} meldingen, allemaal uniek`, new Set(sleutels).size === sleutels.length);
    const eerste = alleEigen[0];
    const dubbel = await probeer(() =>
      su.collection(assertHh(COLLECTIE)).create({
        ontvanger: eerste.ontvanger,
        soort: eerste.soort,
        klus: eerste.klus,
        sleutel: eerste.sleutel,
        titel: MERK,
      }),
    );
    check('een dubbele loopt op de unieke index (ook als superuser)', dubbel.status !== 200, `status ${dubbel.status}`);
  }

  kop('E. Een vreemde leest niets');
  const vanOudere = alleEigen.find((m) => m.ontvanger === oudereId);
  {
    const lijst = await j3.collection(COLLECTIE).getList(1, 50, { filter: j3.filter('ontvanger = {:id}', { id: oudereId }) });
    check('jongere 3 ziet geen meldingen van de oudere in de lijst', lijst.totalItems === 0, `${lijst.totalItems}`);
    const los = await probeer(() => j3.collection(COLLECTIE).getOne(vanOudere.id));
    check('jongere 3 kan een melding van de oudere niet openen', los.status !== 200, `status ${los.status}`);
    const eigen = await hv1.collection(COLLECTIE).getList(1, 50);
    check('de oudere ziet alleen zijn eigen meldingen', eigen.items.every((m) => m.ontvanger === oudereId));
  }

  kop('F. De ontvanger zet alleen gelezen_op');
  {
    const titel = await probeer(() => hv1.collection(COLLECTIE).update(vanOudere.id, { titel: 'gehackt' }));
    check('titel wijzigen geweigerd', titel.status !== 200, `status ${titel.status}`);
    const gelezen = await probeer(() =>
      hv1.collection(COLLECTIE).update(vanOudere.id, { gelezen_op: new Date().toISOString() }),
    );
    check('gelezen_op zetten mag', gelezen.status === 200, `status ${gelezen.status}`);
    const na = await su.collection(COLLECTIE).getOne(vanOudere.id);
    check('de rest bleef gelijk', na.titel === vanOudere.titel && na.tekst === vanOudere.tekst && !!na.gelezen_op);
    const ander = await probeer(() => j3.collection(COLLECTIE).update(vanOudere.id, { gelezen_op: new Date().toISOString() }));
    check('een vreemde kan gelezen_op niet zetten', ander.status !== 200, `status ${ander.status}`);
  }

  kop('G. Aanmaken via de API geweigerd');
  for (const [naam, client, id] of [['oudere', hv1, oudereId], ['coordinator', co, acc.coordinator1.id]]) {
    const r = await probeer(() =>
      client.collection(COLLECTIE).create({ ontvanger: id, soort: 'incident', titel: MERK, sleutel: `${MERK}${naam}` }),
    );
    check(`${naam} kan geen melding aanmaken`, r.status !== 200, `status ${r.status}`);
  }

  kop('H. Incidenten');
  const coordinatoren = await su.collection('hh_users').getFullList({ filter: 'rol = "coordinator"' });
  const familie = await su.collection('hh_koppelingen').getFullList({
    filter: su.filter('oudere = {:id}', { id: oudereId }),
  });
  {
    const nood = await hv1.collection('hh_incidenten').create({ melder: oudereId, soort: 'nood', omschrijving: `${MERK} nood` });
    const verwacht = coordinatoren.length + familie.length;
    const rijen = await meldingenMet(su, `incident:${nood.id}`, verwacht);
    const bijCoordinator = rijen.filter((m) => coordinatoren.some((c) => c.id === m.ontvanger));
    check(`nood -> elke coordinator (${coordinatoren.length})`, bijCoordinator.length === coordinatoren.length, `${bijCoordinator.length}`);
    check(
      `nood -> het gekoppelde familielid (${familie.length})`,
      familie.every((k) => rijen.some((m) => m.ontvanger === k.familielid)),
    );
    check('nood -> niemand anders', rijen.length === verwacht, `${rijen.length} i.p.v. ${verwacht}`);
  }
  {
    const probleem = await j1.collection('hh_incidenten').create({
      melder: j1Id,
      soort: 'probleem',
      klus: klus1.id,
      omschrijving: `${MERK} probleem`,
    });
    const rijen = await meldingenMet(su, `incident:${probleem.id}`, coordinatoren.length);
    check('probleem -> alleen de coordinatoren', rijen.length === coordinatoren.length && rijen.every((m) => coordinatoren.some((c) => c.id === m.ontvanger)));
    check('probleem -> de klus staat erbij', rijen.every((m) => m.klus === klus1.id));
  }

  kop('I. Opruimen');
  await opruimen(su);
  const over = await su.collection('hh_klussen').getFullList({ filter: su.filter('omschrijving ~ {:merk}', { merk: MERK }) });
  check('geen eigen klussen meer over', over.length === 0);

  console.log(`\n${groen} groen, ${rood} rood.`);
  if (rood > 0) process.exitCode = 1;
}

main().catch(fail);
