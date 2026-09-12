// HeitjeHulp M1 stap 6 — smoketest van de API-rules. Logt in als de ECHTE
// seed-accounts (uit backend/seed-accounts.local.json, geschreven door
// 03-seed.mjs) en bewijst per rule positief én negatief wat mag en wat niet.
// De superuser wordt alleen gebruikt om fixtures te lezen, tijdelijke rijen
// op te ruimen en seed-mutaties terug te draaien.
//
// Valkuil: een list-rule is een filter → PocketBase geeft 200 met een lege
// lijst, geen 403. "X ziet Y niet" wordt daarom op INHOUD gecontroleerd.
// Mislukte view/update/delete geeft 404 (bestaan wordt niet gelekt); mislukte
// create geeft 400 of 403.
//
// Herhaalbaar: ruimt eigen testrijen op vóór en na de run en zet seedwaarden
// die tijdens de test veranderen terug.
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/04-rulecheck.mjs --apply     (zonder --apply: alleen uitleg)

import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, userClient, anonClient, assertHh, APPLY, fail, PB_URL } from './_lib.mjs';
import { RULESET } from './02-rules.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ACCOUNTS_FILE = path.resolve(__dirname, '..', 'seed-accounts.local.json');
const MERK = '[rulecheck]';
const ANON_EMAIL = 'hh-rulecheck-anon@qawayah.nl';
const COORD_EMAIL = 'hh-rulecheck-coord@qawayah.nl';
const WEIGER = [400, 403, 404];

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
async function mag(label, fn) {
  try {
    const r = await fn();
    check(label, true);
    return r;
  } catch (e) {
    check(label, false, `status=${e?.status} ${e?.response?.message ?? e?.message ?? ''} ${JSON.stringify(e?.response?.data ?? '')}`);
    return null;
  }
}
async function magNiet(label, fn, codes = WEIGER) {
  try {
    await fn();
    check(label, false, 'verzoek is onterecht gelukt');
  } catch (e) {
    check(`${label} (${e?.status})`, codes.includes(e?.status), `status=${e?.status} ${e?.response?.message ?? ''}`);
  }
}
const heeft = (lijst, id) => lijst.some((r) => r.id === id);

async function main() {
  if (!APPLY) {
    console.log('DRY-RUN: dit script logt in als de seed-accounts, maakt tijdelijke testrijen (merk "[rulecheck]") en ruimt ze weer op.');
    console.log('Zonder --apply gebeurt er niets. Draai met --apply.');
    return;
  }
  if (!existsSync(ACCOUNTS_FILE)) throw new Error(`${ACCOUNTS_FILE} ontbreekt — draai eerst 03-seed.mjs --apply`);
  const acc = JSON.parse(readFileSync(ACCOUNTS_FILE, 'utf8'));

  const su = await superuserClient();
  console.log('Verbonden met', PB_URL, '\n');

  // --- Fixtures lezen (seed) -----------------------------------------------
  const U = {};
  for (const key of Object.keys(acc)) U[key] = (await su.collection('hh_users').getFirstListItem(`email = "${acc[key].email}"`)).id;
  const K = {};
  for (const n of ['k01', 'k02', 'k03', 'k04', 'k05', 'k06', 'k07', 'k08', 'k09', 'k10', 'k11', 'k12']) {
    K[n] = (await su.collection('hh_klussen').getFirstListItem(`omschrijving ~ "[seed ${n}]"`)).id;
  }
  const wijken = await su.collection('hh_wijken').getFullList();
  const klustypes = await su.collection('hh_klustypes').getFullList();
  const koppeling = await su.collection('hh_koppelingen').getFirstListItem(`oudere = "${U.hulpvrager1}" && familielid = "${U.familie1}"`);
  const vertrouwd = await su.collection('hh_vertrouwd').getFirstListItem(`oudere = "${U.hulpvrager1}" && jongere = "${U.jongere2}"`);
  const incident = await su.collection('hh_incidenten').getFirstListItem(`klus = "${K.k10}"`);
  const betalingK07 = await su.collection('hh_betalingen').getFirstListItem(`klus = "${K.k07}"`);
  const betalingK08 = await su.collection('hh_betalingen').getFirstListItem(`klus = "${K.k08}"`);
  const beoordelingHv1 = await su.collection('hh_beoordelingen').getFirstListItem(`klus = "${K.k07}" && van_gebruiker = "${U.hulpvrager1}"`);
  const logK04 = await su.collection('hh_klus_status').getFirstListItem(`klus = "${K.k04}" && naar = "geaccepteerd"`);
  const profielJ1 = await su.collection('hh_profielen').getFirstListItem(`gebruiker = "${U.jongere1}"`);
  const profielJ2 = await su.collection('hh_profielen').getFirstListItem(`gebruiker = "${U.jongere2}"`);

  // --- Opruimen van eerdere (gecrashte) runs -------------------------------
  const opruimen = []; // [collectie, id]
  async function ruimOp() {
    for (const [coll, id] of opruimen.reverse()) await su.collection(assertHh(coll)).delete(id).catch(() => {});
    opruimen.length = 0;
  }
  async function ruimOudeRunOp() {
    for (const email of [ANON_EMAIL, COORD_EMAIL]) {
      const r = await su.collection('hh_users').getFirstListItem(`email = "${email}"`).catch(() => null);
      if (r) await su.collection('hh_users').delete(r.id);
    }
    for (const [coll, veld] of [['hh_klussen', 'omschrijving'], ['hh_incidenten', 'omschrijving'], ['hh_beoordelingen', 'tekst'], ['hh_wijken', 'wijk'], ['hh_klustypes', 'naam'], ['hh_vergoedingen', 'periode'], ['hh_push_tokens', 'token']]) {
      const rows = await su.collection(assertHh(coll)).getFullList({ filter: `${veld} ~ "${MERK}"` });
      for (const r of rows) await su.collection(coll).delete(r.id);
    }
    // Testkoppelingen (oudere 2 ↔ familielid 1) van een gecrashte run.
    const oudeKop = await su.collection('hh_koppelingen').getFullList({ filter: `oudere = "${U.hulpvrager2}" && familielid = "${U.familie1}"` });
    for (const r of oudeKop) await su.collection('hh_koppelingen').delete(r.id);
  }
  await ruimOudeRunOp();

  // Fixtures die de seed niet heeft: één vergoeding en één push-token (via superuser).
  const vergoedingJ1 = await su.collection('hh_vergoedingen').create({ jongere: U.jongere1, periode: `${MERK} 2026-09`, bedrag: 800, status: 'open' });
  opruimen.push(['hh_vergoedingen', vergoedingJ1.id]);
  const tokenJ2 = await su.collection('hh_push_tokens').create({ gebruiker: U.jongere2, token: `${MERK} token-j2`, platform: 'ios' });
  opruimen.push(['hh_push_tokens', tokenJ2.id]);

  // Eén bestaand record per collectie, voor de anonieme view/update/delete-test.
  const voorbeeld = {
    hh_users: U.hulpvrager1, hh_wijken: wijken[0].id, hh_klustypes: klustypes[0].id, hh_profielen: profielJ1.id,
    hh_klussen: K.k02, hh_klus_status: logK04.id, hh_beoordelingen: beoordelingHv1.id, hh_koppelingen: koppeling.id,
    hh_vertrouwd: vertrouwd.id, hh_betalingen: betalingK07.id, hh_vergoedingen: vergoedingJ1.id, hh_incidenten: incident.id,
    hh_push_tokens: tokenJ2.id,
  };

  // --- Clients -------------------------------------------------------------
  const anon = anonClient();
  const hv1 = await userClient(acc.hulpvrager1.email, acc.hulpvrager1.password);
  const hv2 = await userClient(acc.hulpvrager2.email, acc.hulpvrager2.password);
  const j1 = await userClient(acc.jongere1.email, acc.jongere1.password);
  const j2 = await userClient(acc.jongere2.email, acc.jongere2.password);
  const j3 = await userClient(acc.jongere3.email, acc.jongere3.password);
  const fam = await userClient(acc.familie1.email, acc.familie1.password);
  const co = await userClient(acc.coordinator1.email, acc.coordinator1.password);

  // =========================================================================
  kop('A. Anoniem: op elke hh_-collectie nooit data (lijst leeg of geweigerd; view/create/update/delete geweigerd)');
  for (const coll of Object.keys(RULESET)) {
    assertHh(coll);
    try {
      const lijst = await anon.collection(coll).getList(1, 5);
      check(`${coll}: anonieme lijst geeft geen rijen (200, ${lijst.items.length} rijen — filter-semantiek)`, lijst.items.length === 0, `${lijst.items.length} rijen gelekt`);
    } catch (e) {
      check(`${coll}: anonieme lijst geweigerd (${e?.status})`, WEIGER.includes(e?.status), `status=${e?.status}`);
    }
    await magNiet(`${coll}: anonieme view geweigerd`, () => anon.collection(coll).getOne(voorbeeld[coll]));
    if (coll === 'hh_users') {
      await magNiet('hh_users: anonieme registratie als coordinator geweigerd', () =>
        anon.collection('hh_users').create({ email: ANON_EMAIL, password: 'Rulecheck-2026!x', passwordConfirm: 'Rulecheck-2026!x', rol: 'coordinator', naam: `${MERK} anon` }));
      await magNiet('hh_users: anonieme registratie zonder rol geweigerd', () =>
        anon.collection('hh_users').create({ email: ANON_EMAIL, password: 'Rulecheck-2026!x', passwordConfirm: 'Rulecheck-2026!x', naam: `${MERK} anon` }));
      const reg = await mag('hh_users: anonieme zelfregistratie als hulpvrager mag (bewust: registreren)', () =>
        anon.collection('hh_users').create({ email: ANON_EMAIL, password: 'Rulecheck-2026!x', passwordConfirm: 'Rulecheck-2026!x', rol: 'hulpvrager', naam: `${MERK} anon`, taal: 'nl' }));
      if (reg) opruimen.push(['hh_users', reg.id]);
    } else {
      await magNiet(`${coll}: anonieme create geweigerd`, () => anon.collection(coll).create({ naam: MERK, omschrijving: MERK }));
    }
    await magNiet(`${coll}: anonieme update geweigerd`, () => anon.collection(coll).update(voorbeeld[coll], { naam: MERK }));
    await magNiet(`${coll}: anonieme delete geweigerd`, () => anon.collection(coll).delete(voorbeeld[coll]));
  }

  // =========================================================================
  kop('B. hh_users — zichtbaarheid en anti-escalatie');
  const usersHv1 = await hv1.collection('hh_users').getFullList();
  check('oudere 1 ziet zichzelf', heeft(usersHv1, U.hulpvrager1));
  check('oudere 1 ziet oudere 2 NIET', !heeft(usersHv1, U.hulpvrager2));
  check('oudere 1 ziet jongere 1 (toegewezen op k04/k07)', heeft(usersHv1, U.jongere1));
  check('oudere 1 ziet jongere 3 NIET (nooit toegewezen)', !heeft(usersHv1, U.jongere3));
  check('oudere 1 ziet familielid 1 (gekoppeld)', heeft(usersHv1, U.familie1));
  check('oudere 1 ziet coordinator NIET', !heeft(usersHv1, U.coordinator1));
  await magNiet('oudere 1 kan oudere 2 niet direct bekijken', () => hv1.collection('hh_users').getOne(U.hulpvrager2));
  await mag('jongere 1 kan oudere 1 bekijken (toegewezen)', () => j1.collection('hh_users').getOne(U.hulpvrager1));
  await magNiet('jongere 1 kan oudere 2 niet bekijken', () => j1.collection('hh_users').getOne(U.hulpvrager2));
  const usersFam = await fam.collection('hh_users').getFullList();
  check('familielid ziet gekoppelde oudere 1', heeft(usersFam, U.hulpvrager1));
  check('familielid ziet oudere 2 NIET', !heeft(usersFam, U.hulpvrager2));
  const usersCo = await co.collection('hh_users').getFullList();
  check(`coordinator ziet alle ${Object.keys(U).length} seed-accounts`, Object.values(U).every((id) => heeft(usersCo, id)));
  await magNiet('oudere 1 kan eigen rol niet ophogen naar coordinator', () => hv1.collection('hh_users').update(U.hulpvrager1, { rol: 'coordinator' }));
  await magNiet('oudere 1 kan eigen rol niet eens ongewijzigd meesturen (:isset)', () => hv1.collection('hh_users').update(U.hulpvrager1, { rol: 'hulpvrager', telefoon: '0344-100001' }));
  await magNiet('jongere 1 kan rol van oudere 1 niet wijzigen', () => j1.collection('hh_users').update(U.hulpvrager1, { naam: MERK }));
  const upd = await mag('oudere 1 kan eigen telefoon wijzigen (zonder rol mee te sturen)', () => hv1.collection('hh_users').update(U.hulpvrager1, { telefoon: '0344-100099' }));
  if (upd) await su.collection('hh_users').update(U.hulpvrager1, { telefoon: '0344-100001' });
  await magNiet('oudere 1 kan geen coordinator-account aanmaken', () =>
    hv1.collection('hh_users').create({ email: COORD_EMAIL, password: 'Rulecheck-2026!x', passwordConfirm: 'Rulecheck-2026!x', rol: 'coordinator', naam: `${MERK} coord` }));
  const nieuweCo = await mag('coordinator kan wel een coordinator-account aanmaken', () =>
    co.collection('hh_users').create({ email: COORD_EMAIL, password: 'Rulecheck-2026!x', passwordConfirm: 'Rulecheck-2026!x', rol: 'coordinator', naam: `${MERK} coord` }));
  if (nieuweCo) opruimen.push(['hh_users', nieuweCo.id]);
  await magNiet('jongere 1 kan oudere 1 niet verwijderen', () => j1.collection('hh_users').delete(U.hulpvrager1));

  // =========================================================================
  kop('C. hh_wijken en hh_klustypes — lezen iedereen ingelogd, schrijven alleen coordinator');
  check('oudere 1 ziet 2 wijken', (await hv1.collection('hh_wijken').getFullList()).length >= 2);
  check('jongere 1 ziet 6 klustypes', (await j1.collection('hh_klustypes').getFullList()).length >= 6);
  await magNiet('oudere 1 kan geen wijk aanmaken', () => hv1.collection('hh_wijken').create({ gemeente: 'Tiel', wijk: `${MERK} wijk`, actief: true }));
  await magNiet('jongere 1 kan geen klustype aanmaken', () => j1.collection('hh_klustypes').create({ naam: `${MERK} type` }));
  await magNiet('familielid kan klustype niet wijzigen', () => fam.collection('hh_klustypes').update(klustypes[0].id, { icoon: 'x' }));
  const nieuweWijk = await mag('coordinator kan wijk aanmaken', () => co.collection('hh_wijken').create({ gemeente: 'Tiel', wijk: `${MERK} wijk`, postcodes: ['4005'], actief: false }));
  if (nieuweWijk) opruimen.push(['hh_wijken', nieuweWijk.id]);
  const nieuwType = await mag('coordinator kan klustype aanmaken', () => co.collection('hh_klustypes').create({ naam: `${MERK} type`, richtduur: 30, richtvergoeding: 500 }));
  if (nieuwType) opruimen.push(['hh_klustypes', nieuwType.id]);

  // =========================================================================
  kop('D. hh_klussen — wie ziet wat');
  const klussenHv1 = await hv1.collection('hh_klussen').getFullList();
  check('oudere 1 ziet al zijn 8 klussen', ['k01', 'k02', 'k04', 'k05', 'k07', 'k09', 'k11', 'k12'].every((k) => heeft(klussenHv1, K[k])));
  check('oudere 1 ziet klussen van oudere 2 NIET', !['k03', 'k06', 'k08', 'k10'].some((k) => heeft(klussenHv1, K[k])));
  await magNiet('oudere 1 kan klus van oudere 2 niet direct bekijken', () => hv1.collection('hh_klussen').getOne(K.k03));
  const klussenJ1 = await j1.collection('hh_klussen').getFullList();
  check('jongere 1 (Tiel-West) ziet open klussen in eigen wijk (k02, k11)', heeft(klussenJ1, K.k02) && heeft(klussenJ1, K.k11));
  check('jongere 1 ziet open klus in Passewaaij NIET (k03)', !heeft(klussenJ1, K.k03));
  check('jongere 1 ziet eigen toegewezen klussen (k04, k07)', heeft(klussenJ1, K.k04) && heeft(klussenJ1, K.k07));
  check('jongere 1 ziet concept van oudere 1 NIET (k01)', !heeft(klussenJ1, K.k01));
  check('jongere 1 ziet klus toegewezen aan jongere 2 NIET (k05)', !heeft(klussenJ1, K.k05));
  await magNiet('jongere 1 kan k03 (andere wijk) niet direct bekijken', () => j1.collection('hh_klussen').getOne(K.k03));
  const klussenJ3 = await j3.collection('hh_klussen').getFullList();
  check('jongere 3 (Passewaaij) ziet k03 wel, k02 niet', heeft(klussenJ3, K.k03) && !heeft(klussenJ3, K.k02));
  const klussenFam = await fam.collection('hh_klussen').getFullList();
  check('familielid ziet alle klussen van gekoppelde oudere 1', ['k01', 'k02', 'k04', 'k05', 'k07', 'k09', 'k11', 'k12'].every((k) => heeft(klussenFam, K[k])));
  check('familielid ziet klussen van ongekoppelde oudere 2 NIET', !['k03', 'k06', 'k08', 'k10'].some((k) => heeft(klussenFam, K[k])));
  await magNiet('familielid kan klus van oudere 2 niet direct bekijken', () => fam.collection('hh_klussen').getOne(K.k06));
  const klussenCo = await co.collection('hh_klussen').getFullList();
  check('coordinator ziet alle 12 klussen', Object.values(K).every((id) => heeft(klussenCo, id)));

  kop('E. hh_klussen — aanmaken');
  const basisKlus = { klustype: klustypes[0].id, omschrijving: `${MERK} testklus`, adres: 'Teststraat 1', status: 'open', bedrag_bruto: 1000, vergoeding_jongere: 800, commissie: 200 };
  const k = await mag('oudere 1 kan eigen klus aanmaken (bron app)', () => hv1.collection('hh_klussen').create({ ...basisKlus, hulpvrager: U.hulpvrager1, geplaatst_door: U.hulpvrager1, bron: 'app' }));
  if (k) opruimen.push(['hh_klussen', k.id]);
  await magNiet('oudere 1 kan geen klus voor oudere 2 aanmaken', () => hv1.collection('hh_klussen').create({ ...basisKlus, hulpvrager: U.hulpvrager2, geplaatst_door: U.hulpvrager1, bron: 'app' }));
  await magNiet('oudere 1 kan geen klus met status afgerond aanmaken', () => hv1.collection('hh_klussen').create({ ...basisKlus, hulpvrager: U.hulpvrager1, geplaatst_door: U.hulpvrager1, bron: 'app', status: 'afgerond' }));
  await magNiet('oudere 1 kan geen klus met jongere al toegewezen aanmaken', () => hv1.collection('hh_klussen').create({ ...basisKlus, hulpvrager: U.hulpvrager1, geplaatst_door: U.hulpvrager1, bron: 'app', toegewezen_jongere: U.jongere1 }));
  await magNiet('oudere 1 kan geen klus met bron telefoon aanmaken', () => hv1.collection('hh_klussen').create({ ...basisKlus, hulpvrager: U.hulpvrager1, geplaatst_door: U.hulpvrager1, bron: 'telefoon' }));
  const kf = await mag('familielid kan klus namens gekoppelde oudere 1 aanmaken (bron familie)', () => fam.collection('hh_klussen').create({ ...basisKlus, hulpvrager: U.hulpvrager1, geplaatst_door: U.familie1, bron: 'familie' }));
  if (kf) opruimen.push(['hh_klussen', kf.id]);
  await magNiet('familielid kan geen klus namens ongekoppelde oudere 2 aanmaken', () => fam.collection('hh_klussen').create({ ...basisKlus, hulpvrager: U.hulpvrager2, geplaatst_door: U.familie1, bron: 'familie' }));
  await magNiet('familielid kan geen klus met bron app aanmaken', () => fam.collection('hh_klussen').create({ ...basisKlus, hulpvrager: U.hulpvrager1, geplaatst_door: U.familie1, bron: 'app' }));
  await magNiet('familielid kan geplaatst_door niet op de oudere zetten', () => fam.collection('hh_klussen').create({ ...basisKlus, hulpvrager: U.hulpvrager1, geplaatst_door: U.hulpvrager1, bron: 'familie' }));
  await magNiet('jongere 1 kan geen klus aanmaken', () => j1.collection('hh_klussen').create({ ...basisKlus, hulpvrager: U.hulpvrager1, geplaatst_door: U.jongere1, bron: 'app' }));
  const kc = await mag('coordinator kan klus aanmaken (bron telefoon)', () => co.collection('hh_klussen').create({ ...basisKlus, hulpvrager: U.hulpvrager2, geplaatst_door: U.coordinator1, bron: 'telefoon' }));
  if (kc) opruimen.push(['hh_klussen', kc.id]);

  kop('F. hh_klussen — bijwerken door oudere en familie');
  const u1 = await mag('oudere 1 kan eigen klus annuleren (status)', () => hv1.collection('hh_klussen').update(K.k02, { status: 'geannuleerd' }));
  if (u1) await su.collection('hh_klussen').update(K.k02, { status: 'open' });
  await magNiet('oudere 1 kan hulpvrager van eigen klus niet wijzigen', () => hv1.collection('hh_klussen').update(K.k02, { hulpvrager: U.hulpvrager2 }));
  await magNiet('oudere 1 kan klus van oudere 2 niet wijzigen', () => hv1.collection('hh_klussen').update(K.k03, { omschrijving: MERK }));
  const u2 = await mag('familielid kan klus van gekoppelde oudere bijwerken', () => fam.collection('hh_klussen').update(K.k11, { adres: 'Prins Bernhardlaan 12, 4003 AB Tiel' }));
  void u2;
  await magNiet('familielid kan klus van ongekoppelde oudere niet wijzigen', () => fam.collection('hh_klussen').update(K.k03, { adres: MERK }));
  await magNiet('oudere 1 kan open klus niet verwijderen (nooit stil verdwijnen)', () => hv1.collection('hh_klussen').delete(K.k02));
  await magNiet('jongere 1 kan toegewezen klus niet verwijderen', () => j1.collection('hh_klussen').delete(K.k04));

  kop('G. hh_klussen — jongere: accepteren en uitvoeren, bedragen dicht');
  const acc1 = await mag('jongere 1 accepteert open klus k02 in eigen wijk', () => j1.collection('hh_klussen').update(K.k02, { toegewezen_jongere: U.jongere1, status: 'geaccepteerd' }));
  if (acc1) await su.collection('hh_klussen').update(K.k02, { toegewezen_jongere: '', status: 'open' });
  await magNiet('jongere 3 (Passewaaij) kan k02 (Tiel-West) niet accepteren', () => j3.collection('hh_klussen').update(K.k02, { toegewezen_jongere: U.jongere3, status: 'geaccepteerd' }));
  await magNiet('jongere 2 kan k04 (al toegewezen aan jongere 1) niet overnemen', () => j2.collection('hh_klussen').update(K.k04, { toegewezen_jongere: U.jongere2 }));
  await magNiet('jongere 1 kan open klus niet aan jongere 2 toewijzen', () => j1.collection('hh_klussen').update(K.k02, { toegewezen_jongere: U.jongere2 }));
  await magNiet('jongere 1 kan bij accepteren geen bedrag meesturen', () => j1.collection('hh_klussen').update(K.k02, { toegewezen_jongere: U.jongere1, bedrag_bruto: 99999 }));
  const st = await mag('jongere 1 zet eigen klus k04 op onderweg', () => j1.collection('hh_klussen').update(K.k04, { status: 'onderweg' }));
  if (st) await su.collection('hh_klussen').update(K.k04, { status: 'geaccepteerd' });
  await magNiet('jongere 1 kan bedrag_bruto van eigen klus niet wijzigen', () => j1.collection('hh_klussen').update(K.k04, { bedrag_bruto: 99999 }));
  await magNiet('jongere 1 kan vergoeding_jongere niet wijzigen', () => j1.collection('hh_klussen').update(K.k04, { vergoeding_jongere: 99999 }));
  await magNiet('jongere 1 kan commissie niet wijzigen', () => j1.collection('hh_klussen').update(K.k04, { commissie: 0 }));
  await magNiet('jongere 1 kan hulpvrager niet wijzigen', () => j1.collection('hh_klussen').update(K.k04, { hulpvrager: U.hulpvrager2 }));
  await magNiet('jongere 1 kan geplaatst_door niet wijzigen', () => j1.collection('hh_klussen').update(K.k04, { geplaatst_door: U.jongere1 }));
  await magNiet('jongere 1 kan eigen klus niet aan jongere 2 doorgeven', () => j1.collection('hh_klussen').update(K.k04, { toegewezen_jongere: U.jongere2 }));
  await magNiet('jongere 1 kan klus van jongere 2 (k05) niet wijzigen', () => j1.collection('hh_klussen').update(K.k05, { status: 'bezig' }));
  const cb = await mag('coordinator kan bedrag wel wijzigen', () => co.collection('hh_klussen').update(K.k04, { bedrag_bruto: 1300 }));
  if (cb) await su.collection('hh_klussen').update(K.k04, { bedrag_bruto: 1250 });

  // =========================================================================
  kop('H. hh_klus_status — logregels');
  const logsHv1 = await hv1.collection('hh_klus_status').getFullList();
  check('oudere 1 ziet logregels van eigen klussen', logsHv1.some((l) => l.klus === K.k04));
  check('oudere 1 ziet logregels van oudere 2 NIET', !logsHv1.some((l) => l.klus === K.k03 || l.klus === K.k08));
  const logsFam = await fam.collection('hh_klus_status').getFullList();
  check('familielid ziet logregels van gekoppelde oudere', logsFam.some((l) => l.klus === K.k07) && !logsFam.some((l) => l.klus === K.k08));
  const logsJ1 = await j1.collection('hh_klus_status').getFullList();
  check('jongere 1 ziet logregels van toegewezen klus k04, niet van k05', logsJ1.some((l) => l.klus === K.k04) && !logsJ1.some((l) => l.klus === K.k05));
  const l1 = await mag('jongere 1 logt statuswissel op eigen klus k04', () => j1.collection('hh_klus_status').create({ klus: K.k04, door: U.jongere1, van: 'geaccepteerd', naar: 'onderweg' }));
  if (l1) opruimen.push(['hh_klus_status', l1.id]);
  await magNiet('jongere 1 kan geen logregel op k03 (niet van hem) maken', () => j1.collection('hh_klus_status').create({ klus: K.k03, door: U.jongere1, van: 'open', naar: 'geaccepteerd' }));
  await magNiet('oudere 1 kan geen logregel namens jongere 1 maken (door ≠ auth)', () => hv1.collection('hh_klus_status').create({ klus: K.k04, door: U.jongere1, van: 'geaccepteerd', naar: 'onderweg' }));
  const l2 = await mag('familielid logt annulering op klus van gekoppelde oudere', () => fam.collection('hh_klus_status').create({ klus: K.k11, door: U.familie1, van: 'open', naar: 'geannuleerd' }));
  if (l2) opruimen.push(['hh_klus_status', l2.id]);
  await magNiet('jongere 1 kan logregel niet wijzigen', () => j1.collection('hh_klus_status').update(logK04.id, { naar: 'afgerond' }));
  await magNiet('oudere 1 kan logregel niet verwijderen', () => hv1.collection('hh_klus_status').delete(logK04.id));

  // =========================================================================
  kop('I. hh_profielen — eigen profiel, screening dicht');
  const profielenJ1 = await j1.collection('hh_profielen').getFullList();
  check('jongere 1 ziet precies 1 profiel (eigen)', profielenJ1.length === 1 && profielenJ1[0].id === profielJ1.id);
  await magNiet('jongere 1 kan profiel van jongere 2 niet bekijken', () => j1.collection('hh_profielen').getOne(profielJ2.id));
  const p1 = await mag('jongere 1 kan eigen straal_km wijzigen', () => j1.collection('hh_profielen').update(profielJ1.id, { straal_km: 4 }));
  if (p1) await su.collection('hh_profielen').update(profielJ1.id, { straal_km: 3 });
  await magNiet('jongere 1 kan eigen verificatiestatus niet zetten', () => j1.collection('hh_profielen').update(profielJ1.id, { verificatiestatus: 'goedgekeurd' }));
  await magNiet('jongere 1 kan eigen vog_status niet zetten', () => j1.collection('hh_profielen').update(profielJ1.id, { vog_status: 'goedgekeurd' }));
  await magNiet('jongere 1 kan eigen sterren_gemiddeld niet zetten', () => j1.collection('hh_profielen').update(profielJ1.id, { sterren_gemiddeld: 5 }));
  await magNiet('jongere 1 kan profiel van jongere 2 niet wijzigen', () => j1.collection('hh_profielen').update(profielJ2.id, { straal_km: 1 }));
  await magNiet('jongere 1 kan geen tweede profiel aanmaken (unieke index)', () => j1.collection('hh_profielen').create({ gebruiker: U.jongere1, straal_km: 1 }));
  await magNiet('jongere 1 kan geen profiel voor jongere 2 aanmaken', () => j1.collection('hh_profielen').create({ gebruiker: U.jongere2, straal_km: 1 }));
  await mag('coordinator kan verificatiestatus zetten', () => co.collection('hh_profielen').update(profielJ1.id, { verificatiestatus: 'goedgekeurd' }));

  // =========================================================================
  kop('J. hh_beoordelingen');
  const beoHv1 = await hv1.collection('hh_beoordelingen').getFullList();
  check('oudere 1 ziet beide beoordelingen van k07 (gegeven + ontvangen)', beoHv1.length === 2);
  check('oudere 2 ziet geen beoordelingen', (await hv2.collection('hh_beoordelingen').getFullList()).length === 0);
  check('familielid ziet beoordelingen van gekoppelde oudere', (await fam.collection('hh_beoordelingen').getFullList()).length === 2);
  await magNiet('jongere 1 kan k07 niet twee keer beoordelen (unieke index)', () => j1.collection('hh_beoordelingen').create({ klus: K.k07, van_gebruiker: U.jongere1, naar_gebruiker: U.hulpvrager1, sterren: 4 }));
  await magNiet('jongere 1 kan k04 (niet afgerond) niet beoordelen', () => j1.collection('hh_beoordelingen').create({ klus: K.k04, van_gebruiker: U.jongere1, naar_gebruiker: U.hulpvrager1, sterren: 4 }));
  await magNiet('oudere 2 kan k07 (niet zijn klus) niet beoordelen', () => hv2.collection('hh_beoordelingen').create({ klus: K.k07, van_gebruiker: U.hulpvrager2, naar_gebruiker: U.jongere1, sterren: 1 }));
  await magNiet('jongere 2 kan k12 niet beoordelen namens oudere 1 (van ≠ auth)', () => j2.collection('hh_beoordelingen').create({ klus: K.k12, van_gebruiker: U.hulpvrager1, naar_gebruiker: U.jongere2, sterren: 5 }));
  await magNiet('jongere 2 kan bij k12 niet zichzelf beoordelen', () => j2.collection('hh_beoordelingen').create({ klus: K.k12, van_gebruiker: U.jongere2, naar_gebruiker: U.jongere2, sterren: 5 }));
  const b1 = await mag('jongere 2 beoordeelt oudere 1 op afgeronde klus k12', () => j2.collection('hh_beoordelingen').create({ klus: K.k12, van_gebruiker: U.jongere2, naar_gebruiker: U.hulpvrager1, sterren: 5, tekst: `${MERK} fijn` }));
  if (b1) opruimen.push(['hh_beoordelingen', b1.id]);
  await magNiet('jongere 1 kan beoordeling van oudere 1 niet wijzigen', () => j1.collection('hh_beoordelingen').update(beoordelingHv1.id, { sterren: 1 }));
  await magNiet('oudere 1 kan eigen beoordeling niet verwijderen', () => hv1.collection('hh_beoordelingen').delete(beoordelingHv1.id));

  // =========================================================================
  kop('K. hh_koppelingen en hh_vertrouwd');
  check('familielid ziet eigen koppeling', heeft(await fam.collection('hh_koppelingen').getFullList(), koppeling.id));
  check('oudere 2 ziet geen koppelingen', (await hv2.collection('hh_koppelingen').getFullList()).length === 0);
  check('jongere 1 ziet geen koppelingen', (await j1.collection('hh_koppelingen').getFullList()).length === 0);
  await magNiet('familielid kan zichzelf niet aan oudere 2 koppelen', () => fam.collection('hh_koppelingen').create({ oudere: U.hulpvrager2, familielid: U.familie1, rechten: ['meekijken'] }));
  await magNiet('oudere 2 kan jongere 1 niet als familielid koppelen (rol ≠ familie)', () => hv2.collection('hh_koppelingen').create({ oudere: U.hulpvrager2, familielid: U.jongere1, rechten: ['meekijken'] }));
  const kop2 = await mag('oudere 2 kan zelf familielid 1 koppelen', () => hv2.collection('hh_koppelingen').create({ oudere: U.hulpvrager2, familielid: U.familie1, rechten: ['meekijken'] }));
  if (kop2) {
    check('familielid ziet nu ook klussen van oudere 2 (koppeling werkt door)', heeft(await fam.collection('hh_koppelingen').getFullList(), kop2.id) && heeft(await fam.collection('hh_klussen').getFullList(), K.k03));
    await mag('oudere 2 kan die koppeling weer verwijderen', () => hv2.collection('hh_koppelingen').delete(kop2.id));
    check('familielid ziet klussen van oudere 2 daarna NIET meer', !heeft(await fam.collection('hh_klussen').getFullList(), K.k03));
  }
  await magNiet('familielid kan rechten van koppeling niet zelf verhogen', () => fam.collection('hh_koppelingen').update(koppeling.id, { rechten: ['meekijken', 'plaatsen'] }));
  check('oudere 1 ziet vertrouwd-relatie', (await hv1.collection('hh_vertrouwd').getFullList()).length === 1);
  check('jongere 2 ziet vertrouwd-relatie', (await j2.collection('hh_vertrouwd').getFullList()).length === 1);
  check('jongere 1 ziet geen vertrouwd-relatie', (await j1.collection('hh_vertrouwd').getFullList()).length === 0);
  await magNiet('jongere 1 kan zichzelf niet als vertrouwd toevoegen', () => j1.collection('hh_vertrouwd').create({ oudere: U.hulpvrager1, jongere: U.jongere1 }));
  await magNiet('oudere 1 kan familielid niet als vertrouwde jongere toevoegen (rol ≠ jongere)', () => hv1.collection('hh_vertrouwd').create({ oudere: U.hulpvrager1, jongere: U.familie1 }));
  const v1 = await mag('oudere 1 kan jongere 1 als vertrouwd toevoegen', () => hv1.collection('hh_vertrouwd').create({ oudere: U.hulpvrager1, jongere: U.jongere1 }));
  if (v1) opruimen.push(['hh_vertrouwd', v1.id]);

  // =========================================================================
  kop('L. hh_betalingen en hh_vergoedingen — lezen betrokkene, schrijven coordinator');
  const betHv1 = await hv1.collection('hh_betalingen').getFullList();
  check('oudere 1 ziet betaling k07, niet k08', heeft(betHv1, betalingK07.id) && !heeft(betHv1, betalingK08.id));
  const betHv2 = await hv2.collection('hh_betalingen').getFullList();
  check('oudere 2 ziet betaling k08, niet k07', heeft(betHv2, betalingK08.id) && !heeft(betHv2, betalingK07.id));
  check('familielid ziet betaling van gekoppelde oudere (k07)', heeft(await fam.collection('hh_betalingen').getFullList(), betalingK07.id));
  check('jongere 1 ziet geen betalingen', (await j1.collection('hh_betalingen').getFullList()).length === 0);
  await magNiet('oudere 1 kan geen betaling aanmaken', () => hv1.collection('hh_betalingen').create({ klus: K.k12, betaler: U.hulpvrager1, bedrag: 1, status: 'betaald' }));
  await magNiet('oudere 1 kan eigen betaling niet op betaald zetten', () => hv1.collection('hh_betalingen').update(betalingK07.id, { status: 'terugbetaald' }));
  await magNiet('oudere 2 kan open betaling niet wijzigen', () => hv2.collection('hh_betalingen').update(betalingK08.id, { status: 'betaald' }));
  const bet = await mag('coordinator kan betaling wijzigen', () => co.collection('hh_betalingen').update(betalingK08.id, { methode: 'ideal' }));
  void bet;
  check('jongere 1 ziet eigen vergoeding', heeft(await j1.collection('hh_vergoedingen').getFullList(), vergoedingJ1.id));
  check('jongere 2 ziet vergoeding van jongere 1 NIET', (await j2.collection('hh_vergoedingen').getFullList()).length === 0);
  await magNiet('jongere 1 kan eigen vergoeding niet op uitbetaald zetten', () => j1.collection('hh_vergoedingen').update(vergoedingJ1.id, { status: 'uitbetaald' }));
  await magNiet('jongere 1 kan geen vergoeding aanmaken', () => j1.collection('hh_vergoedingen').create({ jongere: U.jongere1, periode: `${MERK} x`, bedrag: 100000, status: 'uitbetaald' }));
  const vg = await mag('coordinator kan vergoeding aanmaken', () => co.collection('hh_vergoedingen').create({ jongere: U.jongere2, periode: `${MERK} 2026-09`, bedrag: 600, status: 'open' }));
  if (vg) opruimen.push(['hh_vergoedingen', vg.id]);

  // =========================================================================
  kop('M. hh_incidenten');
  check('jongere 3 (melder) ziet eigen incident', heeft(await j3.collection('hh_incidenten').getFullList(), incident.id));
  check('oudere 2 (hulpvrager van k10, geen melder) ziet incident NIET', (await hv2.collection('hh_incidenten').getFullList()).length === 0);
  check('coordinator ziet incident', heeft(await co.collection('hh_incidenten').getFullList(), incident.id));
  const i1 = await mag('jongere 3 meldt incident op eigen klus k10', () => j3.collection('hh_incidenten').create({ klus: K.k10, melder: U.jongere3, soort: 'probleem', omschrijving: `${MERK} nog een` }));
  if (i1) opruimen.push(['hh_incidenten', i1.id]);
  const i2 = await mag('oudere 1 drukt op de noodknop zonder klus', () => hv1.collection('hh_incidenten').create({ melder: U.hulpvrager1, soort: 'nood', omschrijving: `${MERK} nood` }));
  if (i2) opruimen.push(['hh_incidenten', i2.id]);
  const i3 = await mag('familielid meldt incident op klus van gekoppelde oudere', () => fam.collection('hh_incidenten').create({ klus: K.k05, melder: U.familie1, soort: 'probleem', omschrijving: `${MERK} fam` }));
  if (i3) opruimen.push(['hh_incidenten', i3.id]);
  await magNiet('jongere 1 kan geen incident op k10 (niet zijn klus) melden', () => j1.collection('hh_incidenten').create({ klus: K.k10, melder: U.jongere1, soort: 'probleem', omschrijving: MERK }));
  await magNiet('jongere 3 kan geen incident namens oudere 2 melden (melder ≠ auth)', () => j3.collection('hh_incidenten').create({ klus: K.k10, melder: U.hulpvrager2, soort: 'probleem', omschrijving: MERK }));
  await magNiet('jongere 3 kan afhandeling niet zelf invullen', () => j3.collection('hh_incidenten').create({ klus: K.k10, melder: U.jongere3, soort: 'probleem', omschrijving: MERK, afhandeling: 'opgelost' }));
  await magNiet('jongere 3 kan eigen incident niet bewerken', () => j3.collection('hh_incidenten').update(incident.id, { afhandeling: 'opgelost' }));
  await mag('coordinator kan afhandeling invullen', () => co.collection('hh_incidenten').update(incident.id, { afhandeling: '' }));

  // =========================================================================
  kop('N. hh_push_tokens — alleen eigen rijen');
  const t1 = await mag('jongere 1 registreert eigen push-token', () => j1.collection('hh_push_tokens').create({ gebruiker: U.jongere1, token: `${MERK} token-j1`, platform: 'android' }));
  if (t1) opruimen.push(['hh_push_tokens', t1.id]);
  await magNiet('jongere 1 kan geen token voor jongere 2 registreren', () => j1.collection('hh_push_tokens').create({ gebruiker: U.jongere2, token: `${MERK} token-x`, platform: 'android' }));
  await magNiet('jongere 1 kan zelfde token niet dubbel registreren (unieke index)', () => j1.collection('hh_push_tokens').create({ gebruiker: U.jongere1, token: `${MERK} token-j1`, platform: 'ios' }));
  check('jongere 1 ziet alleen eigen token', (await j1.collection('hh_push_tokens').getFullList()).every((t) => t.gebruiker === U.jongere1));
  check('jongere 2 ziet token van jongere 1 NIET', !heeft(await j2.collection('hh_push_tokens').getFullList(), t1?.id));
  await magNiet('jongere 2 kan token van jongere 1 niet verwijderen', () => j2.collection('hh_push_tokens').delete(t1?.id ?? 'x'));
  await magNiet('coordinator ziet token van jongere 2 niet (eigen rijen alleen)', () => co.collection('hh_push_tokens').getOne(tokenJ2.id));
  if (t1) {
    await mag('jongere 1 verwijdert eigen token', () => j1.collection('hh_push_tokens').delete(t1.id));
    opruimen.splice(opruimen.findIndex(([, id]) => id === t1.id), 1);
  }

  // =========================================================================
  await ruimOp();
  console.log(`\n${groen} groen, ${rood} rood (${groen + rood} checks).`);
  if (rood > 0) process.exit(1);
}

main().catch(fail);
