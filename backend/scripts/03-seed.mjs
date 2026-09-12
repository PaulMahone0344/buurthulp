// HeitjeHulp M1 stap 5 — testdata op de hh_-collecties. Vereist dat
// 01-collections.mjs en 02-rules.mjs al gedraaid zijn (--apply).
//
// Idempotent: accounts op e-mail, wijken op (gemeente, wijk), klustypes op
// naam, klussen op het merkteken "[seed kNN]" in de omschrijving, logregels op
// (klus, naar), beoordelingen op (klus, van_gebruiker), enz. Tweede keer
// draaien maakt niets dubbel.
//
// Seed loopt via de superuser (omzeilt de rules; de rulecheck logt daarna in
// als de echte accounts). Wachtwoorden zijn random en worden weggeschreven
// naar backend/seed-accounts.local.json (gitignored via *.local.*) en
// onderaan /Users/h/Desktop/GEHEIMEN.txt. Nooit naar stdout.
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/03-seed.mjs            (dry-run)
//   node scripts/03-seed.mjs --apply

import { randomBytes } from 'node:crypto';
import { readFileSync, writeFileSync, existsSync, appendFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ACCOUNTS_FILE = path.resolve(__dirname, '..', 'seed-accounts.local.json');
const GEHEIMEN_FILE = '/Users/h/Desktop/GEHEIMEN.txt';
const GEHEIMEN_KOP = 'HeitjeHulp seed-accounts (prod, 12 sep 2026)';

const DAG = 24 * 60 * 60 * 1000;
const iso = (offsetDagen, uur) => {
  const d = new Date(Date.now() + offsetDagen * DAG);
  d.setUTCHours(uur, 0, 0, 0);
  return d.toISOString();
};
const wachtwoord = () => randomBytes(18).toString('base64url'); // 24 tekens, sterk

// --- Vaste testdata -------------------------------------------------------

const WIJKEN = [
  { gemeente: 'Tiel', wijk: 'Tiel-West', postcodes: ['4003', '4004'], actief: true },
  { gemeente: 'Tiel', wijk: 'Passewaaij', postcodes: ['4007'], actief: true },
];

// richtduur in minuten, richtvergoeding in centen
const KLUSTYPES = [
  { naam: 'boodschappen', icoon: 'shopping_cart', richtduur: 60, richtvergoeding: 1000 },
  { naam: 'tuin', icoon: 'yard', richtduur: 90, richtvergoeding: 1500 },
  { naam: 'klusje in huis', icoon: 'handyman', richtduur: 60, richtvergoeding: 1250 },
  { naam: 'telefoon/tablet-hulp', icoon: 'devices', richtduur: 45, richtvergoeding: 750 },
  { naam: 'wandelen/gezelschap', icoon: 'directions_walk', richtduur: 60, richtvergoeding: 750 },
  { naam: 'vervoer', icoon: 'directions_car', richtduur: 90, richtvergoeding: 1500 },
];

const ACCOUNTS = [
  { key: 'hulpvrager1', rol: 'hulpvrager', naam: 'Mevrouw A. de Vries', telefoon: '0344-100001', geboortedatum: '1946-03-12', wijk: 'Tiel-West' },
  { key: 'hulpvrager2', rol: 'hulpvrager', naam: 'Meneer B. Jansen', telefoon: '0344-100002', geboortedatum: '1941-08-30', wijk: 'Passewaaij' },
  { key: 'jongere1', rol: 'jongere', naam: 'Yusuf el Amrani', telefoon: '06-10000001', geboortedatum: '2008-05-14', wijk: 'Tiel-West' },
  { key: 'jongere2', rol: 'jongere', naam: 'Sanne Bakker', telefoon: '06-10000002', geboortedatum: '2007-11-02', wijk: 'Tiel-West' },
  { key: 'jongere3', rol: 'jongere', naam: 'Daan Verhoeven', telefoon: '06-10000003', geboortedatum: '2008-01-20', wijk: 'Passewaaij' },
  { key: 'familie1', rol: 'familie', naam: 'Karin de Vries', telefoon: '06-10000004', geboortedatum: '1972-06-01', wijk: null },
  { key: 'coordinator1', rol: 'coordinator', naam: 'Meldkamer HeitjeHulp', telefoon: '0344-100000', geboortedatum: null, wijk: null },
];
const emailVan = (key) => `hh-seed-${key}@qawayah.nl`;

const BESCHIKBAAR = { ma: ['middag'], di: ['ochtend', 'middag'], wo: ['middag'], do: [], vr: ['middag', 'avond'], za: ['ochtend'], zo: [] };

// Profielen: jongeren volledig gescreend, rest minimaal.
const PROFIELEN = {
  hulpvrager1: {},
  hulpvrager2: {},
  jongere1: { verificatiestatus: 'goedgekeurd', vog_status: 'goedgekeurd', iban_geverifieerd: true, straal_km: 3, beschikbaarheid: BESCHIKBAAR, klustypes: ['boodschappen', 'klusje in huis', 'telefoon/tablet-hulp'], sterren_gemiddeld: 5, klussen_aantal: 1 },
  jongere2: { verificatiestatus: 'goedgekeurd', vog_status: 'goedgekeurd', iban_geverifieerd: true, straal_km: 5, beschikbaarheid: BESCHIKBAAR, klustypes: ['boodschappen', 'wandelen/gezelschap', 'vervoer'], sterren_gemiddeld: 0, klussen_aantal: 1 },
  jongere3: { verificatiestatus: 'goedgekeurd', vog_status: 'goedgekeurd', iban_geverifieerd: true, straal_km: 4, beschikbaarheid: BESCHIKBAAR, klustypes: ['tuin', 'wandelen/gezelschap', 'telefoon/tablet-hulp'], sterren_gemiddeld: 0, klussen_aantal: 1 },
  familie1: {},
  coordinator1: {},
};

const bedragen = (bruto) => ({ bedrag_bruto: bruto, commissie: Math.round(bruto * 0.2), vergoeding_jongere: bruto - Math.round(bruto * 0.2) });

// 12 klussen, minstens 1 per status. `door` = geplaatst_door; `jongere` = toegewezen_jongere.
const KLUSSEN = [
  { key: 'k01', status: 'concept', hulpvrager: 'hulpvrager1', door: 'hulpvrager1', bron: 'app', klustype: 'boodschappen', omschrijving: 'Weekboodschappen bij de Jumbo, lijstje ligt klaar', van: [1, 10], tot: [1, 11] },
  { key: 'k02', status: 'open', hulpvrager: 'hulpvrager1', door: 'hulpvrager1', bron: 'app', klustype: 'tuin', omschrijving: 'Heg knippen aan de voorkant en blad vegen', van: [2, 14], tot: [2, 15.5] },
  { key: 'k03', status: 'open', hulpvrager: 'hulpvrager2', door: 'coordinator1', bron: 'telefoon', klustype: 'boodschappen', omschrijving: 'Boodschappen halen, meneer belt zelf de lijst door', van: [1, 9], tot: [1, 10] },
  { key: 'k04', status: 'geaccepteerd', hulpvrager: 'hulpvrager1', door: 'hulpvrager1', bron: 'app', klustype: 'klusje in huis', omschrijving: 'Lamp in de gang vervangen en rookmelder testen', jongere: 'jongere1', van: [3, 10], tot: [3, 11] },
  { key: 'k05', status: 'onderweg', hulpvrager: 'hulpvrager1', door: 'familie1', bron: 'familie', klustype: 'boodschappen', omschrijving: 'Medicijnen ophalen bij apotheek De Betuwe', jongere: 'jongere2', van: [0, 15], tot: [0, 16] },
  { key: 'k06', status: 'bezig', hulpvrager: 'hulpvrager2', door: 'hulpvrager2', bron: 'app', klustype: 'wandelen/gezelschap', omschrijving: 'Rondje wandelen door het park, rustig tempo', jongere: 'jongere3', van: [0, 14], tot: [0, 15] },
  { key: 'k07', status: 'afgerond', hulpvrager: 'hulpvrager1', door: 'hulpvrager1', bron: 'app', klustype: 'boodschappen', omschrijving: 'Boodschappen voor het weekend', jongere: 'jongere1', van: [-3, 10], tot: [-3, 11] },
  { key: 'k08', status: 'afgerond', hulpvrager: 'hulpvrager2', door: 'coordinator1', bron: 'telefoon', klustype: 'tuin', omschrijving: 'Gras maaien achtertuin, maaier staat in de schuur', jongere: 'jongere3', van: [-5, 13], tot: [-5, 14.5] },
  { key: 'k09', status: 'geannuleerd', hulpvrager: 'hulpvrager1', door: 'familie1', bron: 'familie', klustype: 'vervoer', omschrijving: 'Rit naar het ziekenhuis in Tiel (afspraak verzet)', van: [-1, 8], tot: [-1, 9.5] },
  { key: 'k10', status: 'probleem', hulpvrager: 'hulpvrager2', door: 'hulpvrager2', bron: 'app', klustype: 'telefoon/tablet-hulp', omschrijving: 'Tablet doet het niet meer, videobellen met kleinkinderen', jongere: 'jongere3', van: [-1, 16], tot: [-1, 16.75] },
  { key: 'k11', status: 'open', hulpvrager: 'hulpvrager1', door: 'familie1', bron: 'familie', klustype: 'telefoon/tablet-hulp', omschrijving: 'Nieuwe telefoon instellen en WhatsApp overzetten', van: [4, 11], tot: [4, 11.75] },
  { key: 'k12', status: 'afgerond', hulpvrager: 'hulpvrager1', door: 'hulpvrager1', bron: 'app', klustype: 'wandelen/gezelschap', omschrijving: 'Samen koffie drinken en een stukje lopen', jongere: 'jongere2', van: [-7, 14], tot: [-7, 15] },
];

// Statusketen per eindstatus → logregels (van → naar). "door" per stap: p = plaatser, j = jongere.
const KETEN = {
  concept: [],
  open: [['', 'open', 'p']],
  geaccepteerd: [['', 'open', 'p'], ['open', 'geaccepteerd', 'j']],
  onderweg: [['', 'open', 'p'], ['open', 'geaccepteerd', 'j'], ['geaccepteerd', 'onderweg', 'j']],
  bezig: [['', 'open', 'p'], ['open', 'geaccepteerd', 'j'], ['geaccepteerd', 'onderweg', 'j'], ['onderweg', 'bezig', 'j']],
  afgerond: [['', 'open', 'p'], ['open', 'geaccepteerd', 'j'], ['geaccepteerd', 'onderweg', 'j'], ['onderweg', 'bezig', 'j'], ['bezig', 'afgerond', 'j']],
  geannuleerd: [['', 'open', 'p'], ['open', 'geannuleerd', 'p']],
  probleem: [['', 'open', 'p'], ['open', 'geaccepteerd', 'j'], ['geaccepteerd', 'onderweg', 'j'], ['onderweg', 'probleem', 'j']],
};

const BEOORDELINGEN = [
  { klus: 'k07', van: 'hulpvrager1', naar: 'jongere1', sterren: 5, tekst: 'Heel vriendelijk en netjes op tijd.' },
  { klus: 'k07', van: 'jongere1', naar: 'hulpvrager1', sterren: 5, tekst: 'Gezellig, duidelijke uitleg.' },
];
const KOPPELINGEN = [{ oudere: 'hulpvrager1', familielid: 'familie1', rechten: ['meekijken', 'plaatsen'] }];
const VERTROUWD = [{ oudere: 'hulpvrager1', jongere: 'jongere2' }];
const INCIDENTEN = [{ klus: 'k10', melder: 'jongere3', soort: 'probleem', omschrijving: 'Tablet start niet op, oplader lijkt kapot. Meneer wil liever dat iemand van de meldkamer belt.' }];
const BETALINGEN = [
  { klus: 'k07', betaler: 'hulpvrager1', bedrag: 1000, methode: 'ideal', psp_id: 'tr_seed_k07', status: 'betaald', betaald_op: iso(-3, 12) },
  { klus: 'k08', betaler: 'hulpvrager2', bedrag: 1500, methode: 'ideal', psp_id: '', status: 'open', betaald_op: '' },
];

// --- Helpers ----------------------------------------------------------------

let aangemaakt = 0;
let overgeslagen = 0;

async function eerste(pb, coll, filter) {
  return pb.collection(assertHh(coll)).getFirstListItem(filter).catch(() => null);
}

// Maakt een rij aan als hij niet bestaat (op `filter`). Geeft de rij (of null bij dry-run) terug.
async function zorg(pb, coll, filter, data, label) {
  assertHh(coll);
  const bestaand = await eerste(pb, coll, filter);
  if (bestaand) {
    overgeslagen++;
    console.log(`  ✓ bestaat al: ${coll} ${label}`);
    return bestaand;
  }
  if (!APPLY) {
    console.log(`  + ZOU aanmaken: ${coll} ${label} — dry-run`);
    return null;
  }
  const rij = await pb.collection(coll).create(data);
  aangemaakt++;
  console.log(`  ＋ aangemaakt: ${coll} ${label} (${rij.id})`);
  return rij;
}

function leesAccounts() {
  if (!existsSync(ACCOUNTS_FILE)) return {};
  return JSON.parse(readFileSync(ACCOUNTS_FILE, 'utf8'));
}

function schrijfAccounts(accounts, nieuw) {
  writeFileSync(ACCOUNTS_FILE, JSON.stringify(accounts, null, 2));
  if (!nieuw.length) return;
  const bestaandeTekst = existsSync(GEHEIMEN_FILE) ? readFileSync(GEHEIMEN_FILE, 'utf8') : '';
  let blok = '';
  if (!bestaandeTekst.includes(GEHEIMEN_KOP)) {
    blok += `\n\n${GEHEIMEN_KOP}\n${'-'.repeat(GEHEIMEN_KOP.length)}\nServer: https://api.qawayahbase.com, collectie hh_users\n`;
  }
  for (const a of nieuw) blok += `${a.rol.padEnd(12)} ${a.email.padEnd(40)} ${a.password}\n`;
  appendFileSync(GEHEIMEN_FILE, blok);
  console.log(`  → ${nieuw.length} nieuwe account(s) toegevoegd aan GEHEIMEN.txt en ${path.basename(ACCOUNTS_FILE)}`);
}

// --- Main ---------------------------------------------------------------------

async function main() {
  const pb = await superuserClient();
  logMode();

  console.log('Wijken');
  const wijkId = {};
  for (const w of WIJKEN) {
    const rij = await zorg(pb, 'hh_wijken', `gemeente = "${w.gemeente}" && wijk = "${w.wijk}"`, w, w.wijk);
    if (rij) wijkId[w.wijk] = rij.id;
  }

  console.log('Klustypes');
  const typeId = {};
  for (const t of KLUSTYPES) {
    const rij = await zorg(pb, 'hh_klustypes', `naam = "${t.naam}"`, t, t.naam);
    if (rij) typeId[t.naam] = rij.id;
  }

  console.log('Accounts');
  const accounts = leesAccounts();
  const nieuweAccounts = [];
  const userId = {};
  for (const a of ACCOUNTS) {
    const email = emailVan(a.key);
    const bestaand = await eerste(pb, 'hh_users', `email = "${email}"`);
    if (bestaand) {
      overgeslagen++;
      userId[a.key] = bestaand.id;
      console.log(`  ✓ bestaat al: hh_users ${email}`);
      if (!accounts[a.key]) console.log(`    ! wachtwoord onbekend in ${path.basename(ACCOUNTS_FILE)} — zie GEHEIMEN.txt`);
      continue;
    }
    if (!APPLY) {
      console.log(`  + ZOU aanmaken: hh_users ${email} (${a.rol}) — dry-run`);
      continue;
    }
    const password = wachtwoord();
    const rij = await pb.collection('hh_users').create({
      email,
      password,
      passwordConfirm: password,
      emailVisibility: true,
      verified: true,
      rol: a.rol,
      naam: a.naam,
      telefoon: a.telefoon,
      geboortedatum: a.geboortedatum ?? '',
      wijk: a.wijk ? wijkId[a.wijk] : '',
      taal: 'nl',
    });
    aangemaakt++;
    userId[a.key] = rij.id;
    accounts[a.key] = { email, password, rol: a.rol, id: rij.id };
    nieuweAccounts.push(accounts[a.key]);
    console.log(`  ＋ aangemaakt: hh_users ${email} (${a.rol}, ${rij.id})`);
  }
  if (APPLY) schrijfAccounts(accounts, nieuweAccounts);

  if (!APPLY && Object.keys(userId).length < ACCOUNTS.length) {
    console.log('\nDry-run: de rest (profielen, klussen, logregels, ...) hangt aan account-id\'s die nog niet bestaan.');
    console.log(`Zou nog aanmaken: ${ACCOUNTS.length} profielen, ${KLUSSEN.length} klussen, ${KLUSSEN.reduce((n, k) => n + KETEN[k.status].length, 0)} logregels, ${BEOORDELINGEN.length} beoordelingen, ${KOPPELINGEN.length} koppeling, ${VERTROUWD.length} vertrouwd, ${INCIDENTEN.length} incident, ${BETALINGEN.length} betalingen.`);
    console.log('Draai met --apply.');
    return;
  }

  console.log('Profielen');
  for (const a of ACCOUNTS) {
    const p = PROFIELEN[a.key];
    await zorg(pb, 'hh_profielen', `gebruiker = "${userId[a.key]}"`, {
      gebruiker: userId[a.key],
      verificatiestatus: p.verificatiestatus ?? 'nieuw',
      vog_status: p.vog_status ?? 'nieuw',
      iban_geverifieerd: p.iban_geverifieerd ?? false,
      straal_km: p.straal_km ?? 0,
      beschikbaarheid: p.beschikbaarheid ?? {},
      klustypes: (p.klustypes ?? []).map((n) => typeId[n]),
      sterren_gemiddeld: p.sterren_gemiddeld ?? 0,
      klussen_aantal: p.klussen_aantal ?? 0,
    }, a.key);
  }

  console.log('Koppelingen');
  for (const k of KOPPELINGEN) {
    await zorg(pb, 'hh_koppelingen', `oudere = "${userId[k.oudere]}" && familielid = "${userId[k.familielid]}"`, {
      oudere: userId[k.oudere], familielid: userId[k.familielid], rechten: k.rechten,
    }, `${k.oudere} ↔ ${k.familielid}`);
  }

  console.log('Klussen');
  const klusId = {};
  for (const k of KLUSSEN) {
    const merk = `[seed ${k.key}]`;
    const hv = ACCOUNTS.find((a) => a.key === k.hulpvrager);
    const adres = hv.wijk === 'Tiel-West' ? 'Prins Bernhardlaan 12, 4003 AB Tiel' : 'Passewaaijse Hogeweg 40, 4007 GS Tiel';
    const [lat, lon] = hv.wijk === 'Tiel-West' ? [51.8865, 5.4126] : [51.8712, 5.4045];
    const rij = await zorg(pb, 'hh_klussen', `omschrijving ~ "${merk}"`, {
      hulpvrager: userId[k.hulpvrager],
      geplaatst_door: userId[k.door],
      klustype: typeId[k.klustype],
      omschrijving: `${merk} ${k.omschrijving}`,
      adres,
      lat,
      lon,
      wanneer_van: iso(k.van[0], k.van[1]),
      wanneer_tot: iso(k.tot[0], k.tot[1]),
      status: k.status,
      ...bedragen(KLUSTYPES.find((t) => t.naam === k.klustype).richtvergoeding),
      toegewezen_jongere: k.jongere ? userId[k.jongere] : '',
      bron: k.bron,
    }, `${k.key} ${k.status}`);
    if (rij) klusId[k.key] = rij.id;
  }

  console.log('Logregels hh_klus_status');
  for (const k of KLUSSEN) {
    for (const [van, naar, wie] of KETEN[k.status]) {
      const door = wie === 'j' ? k.jongere : k.door;
      await zorg(pb, 'hh_klus_status', `klus = "${klusId[k.key]}" && naar = "${naar}"`, {
        klus: klusId[k.key], door: userId[door], van, naar,
      }, `${k.key} ${van || '·'} → ${naar}`);
    }
  }

  console.log('Beoordelingen');
  for (const b of BEOORDELINGEN) {
    await zorg(pb, 'hh_beoordelingen', `klus = "${klusId[b.klus]}" && van_gebruiker = "${userId[b.van]}"`, {
      klus: klusId[b.klus], van_gebruiker: userId[b.van], naar_gebruiker: userId[b.naar], sterren: b.sterren, tekst: b.tekst,
    }, `${b.klus} ${b.van} → ${b.naar}`);
  }

  console.log('Vertrouwd');
  for (const v of VERTROUWD) {
    await zorg(pb, 'hh_vertrouwd', `oudere = "${userId[v.oudere]}" && jongere = "${userId[v.jongere]}"`, {
      oudere: userId[v.oudere], jongere: userId[v.jongere],
    }, `${v.oudere} ↔ ${v.jongere}`);
  }

  console.log('Incidenten');
  for (const i of INCIDENTEN) {
    await zorg(pb, 'hh_incidenten', `klus = "${klusId[i.klus]}" && melder = "${userId[i.melder]}"`, {
      klus: klusId[i.klus], melder: userId[i.melder], soort: i.soort, omschrijving: i.omschrijving, afhandeling: '',
    }, `${i.klus} door ${i.melder}`);
  }

  console.log('Betalingen');
  for (const b of BETALINGEN) {
    await zorg(pb, 'hh_betalingen', `klus = "${klusId[b.klus]}"`, {
      klus: klusId[b.klus], betaler: userId[b.betaler], bedrag: b.bedrag, methode: b.methode, psp_id: b.psp_id, status: b.status, betaald_op: b.betaald_op,
    }, `${b.klus} ${b.status}`);
  }

  console.log(`\nKlaar. ${aangemaakt} aangemaakt, ${overgeslagen} bestonden al.`);
}

main().catch(fail);
