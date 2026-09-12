// HeitjeHulp M3 stap 3 — smoketest van de screeningvelden (05) en de twee
// screeningregels (06). Logt in als de ECHTE seed-jongere (jongere 1) en als
// een tijdelijke jongere zonder profiel, en bewijst positief én negatief:
//
//   - jongere kan eigen profiel aanmaken zonder geblokkeerde velden
//   - jongere kan over_mij, iban, straal_km, beschikbaarheid, klustypes,
//     vog_aangevraagd_op, document_foto en selfie zetten
//   - jongere kan vog_status en iban_geverifieerd NIET zetten
//   - nieuw -> in_behandeling mag; in_behandeling -> goedgekeurd mag NIET;
//     goedgekeurd zetten door de jongere mag NIET
//   - jongere met status nieuw ziet GEEN open klussen in eigen wijk; dezelfde
//     jongere na superuser-goedkeuring ziet ze WEL; toegewezen klussen
//     blijven altijd zichtbaar
//   - oudere kan document_foto van een jongere NIET ophalen (protected)
//   - superuser zet alles terug zoals het was en meet dat na
//
// De tijdelijke jongere (hh-screeningcheck-j@qawayah.nl, wijk Tiel-West)
// wordt door de superuser aangemaakt en aan het eind verwijderd (profiel
// verdwijnt mee, cascade). Seed-jongere 1 wordt tijdens de test gewijzigd en
// daarna teruggezet op de SEED-waarden uit 03-seed.mjs; het script vergelijkt
// het eindresultaat veld voor veld met die waarden. Dat maakt dit script ook
// de "terugzet-knop" na een handmatige app-smoke met jongere 1.
//
// Herhaalbaar: ruimt resten van een gecrashte run op vóór het begint.
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/07-screeningcheck.mjs --apply     (zonder --apply: alleen uitleg)

import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, userClient, assertHh, APPLY, fail, PB_URL } from './_lib.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ACCOUNTS_FILE = path.resolve(__dirname, '..', 'seed-accounts.local.json');
const MERK = '[screeningcheck]';
const TIJDELIJK_EMAIL = 'hh-screeningcheck-j@qawayah.nl';
const TIJDELIJK_WACHTWOORD = 'Screeningcheck-2026!x';
const WEIGER = [400, 403, 404];

// Seed-waarden van jongere 1 (03-seed.mjs, PROFIELEN.jongere1 + de M3-velden leeg),
// en de accountvelden op hh_users die J1/J6 wijzigen (seed: geen foto, wijk Tiel-West).
const SEED_J1_ACCOUNT = { foto: '', geboortedatum: '2008-05-14 00:00:00.000Z' };
const SEED_J1 = {
  verificatiestatus: 'goedgekeurd',
  vog_status: 'goedgekeurd',
  iban_geverifieerd: true,
  straal_km: 3,
  beschikbaarheid: { ma: ['middag'], di: ['ochtend', 'middag'], wo: ['middag'], do: [], vr: ['middag', 'avond'], za: ['ochtend'], zo: [] },
  klustypeNamen: ['boodschappen', 'klusje in huis', 'telefoon/tablet-hulp'],
  sterren_gemiddeld: 5,
  klussen_aantal: 1,
  over_mij: '',
  iban: '',
  vog_aangevraagd_op: '',
  document_foto: '',
  selfie: '',
};

// Kleinste geldige PNG (1x1, wit). PocketBase controleert het mimetype op inhoud.
const PNG_1X1 = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
  'base64',
);
const png = (naam) => new File([PNG_1X1], naam, { type: 'image/png' });

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
// JSON met gesorteerde sleutels: PocketBase geeft json-velden met de sleutels op alfabet terug.
const canoniek = (v) => JSON.stringify(v, (_, x) => (x && typeof x === 'object' && !Array.isArray(x) ? Object.fromEntries(Object.keys(x).sort().map((k) => [k, x[k]])) : x));

// Haalt een (beschermd) bestand op zoals de app dat zou doen: met of zonder bestandstoken.
async function haalBestand(client, record, veld, metToken) {
  const token = metToken ? await client.files.getToken() : undefined;
  const url = client.files.getURL(record, record[veld], token ? { token } : {});
  const res = await fetch(url);
  return res.status;
}

async function main() {
  if (!APPLY) {
    console.log('DRY-RUN: dit script logt in als seed-jongere 1 en als een tijdelijke jongere, wijzigt hun profielen,');
    console.log('uploadt twee kleine testfoto\'s en zet daarna alles terug op de seed-waarden. Draai met --apply.');
    return;
  }
  if (!existsSync(ACCOUNTS_FILE)) throw new Error(`${ACCOUNTS_FILE} ontbreekt — draai eerst 03-seed.mjs --apply`);
  const acc = JSON.parse(readFileSync(ACCOUNTS_FILE, 'utf8'));

  const su = await superuserClient();
  console.log('Verbonden met', PB_URL, '\n');

  // --- Fixtures ------------------------------------------------------------
  const U = {};
  for (const key of ['hulpvrager1', 'jongere1', 'jongere2']) {
    U[key] = (await su.collection('hh_users').getFirstListItem(`email = "${acc[key].email}"`)).id;
  }
  const K = {};
  for (const n of ['k02', 'k03', 'k04', 'k07', 'k11']) {
    K[n] = (await su.collection('hh_klussen').getFirstListItem(`omschrijving ~ "[seed ${n}]"`)).id;
  }
  const wijkWest = await su.collection('hh_wijken').getFirstListItem('wijk = "Tiel-West"');
  const klustypes = await su.collection('hh_klustypes').getFullList();
  const typeId = Object.fromEntries(klustypes.map((t) => [t.naam, t.id]));
  const seedKlustypesJ1 = SEED_J1.klustypeNamen.map((n) => typeId[n]);

  // Velden van hh_profielen die het schema na 05 moet hebben.
  const profielCollectie = await su.collections.getOne('hh_profielen');
  const veldNamen = new Set(profielCollectie.fields.map((f) => f.name));
  kop('0. Schema (05-screening-velden)');
  for (const v of ['over_mij', 'document_foto', 'selfie', 'iban', 'vog_aangevraagd_op']) {
    check(`hh_profielen heeft veld ${v}`, veldNamen.has(v));
  }
  for (const v of ['document_foto', 'selfie']) {
    const f = profielCollectie.fields.find((x) => x.name === v);
    check(`${v} is protected, 1 bestand, max 10 MB, alleen afbeeldingen`,
      f?.protected === true && f?.maxSelect === 1 && f?.maxSize === 10 * 1024 * 1024 && (f?.mimeTypes ?? []).every((m) => m.startsWith('image/')));
  }

  // --- Opruimen van een eerdere (gecrashte) run ------------------------------
  async function ruimTijdelijkeOp() {
    const r = await su.collection('hh_users').getFirstListItem(`email = "${TIJDELIJK_EMAIL}"`).catch(() => null);
    if (r) await su.collection(assertHh('hh_users')).delete(r.id); // profiel verdwijnt mee (cascade)
  }
  async function zetJ1TerugOpSeed() {
    const p = await su.collection('hh_profielen').getFirstListItem(`gebruiker = "${U.jongere1}"`);
    const { klustypeNamen, ...velden } = SEED_J1;
    // Lege bestandsvelden: '' verwijdert het bestand; null-datum: ''.
    const profiel = await su.collection(assertHh('hh_profielen')).update(p.id, { ...velden, klustypes: seedKlustypesJ1 });
    // Ook het account (J1 foto/geboortedatum, J6 wijk) terug naar de seed.
    const account = await su.collection(assertHh('hh_users')).update(U.jongere1, { ...SEED_J1_ACCOUNT, wijk: wijkWest.id });
    return { profiel, account };
  }
  await ruimTijdelijkeOp();

  // --- Tijdelijke jongere zonder profiel ----------------------------------------
  const tijdelijk = await su.collection(assertHh('hh_users')).create({
    email: TIJDELIJK_EMAIL,
    password: TIJDELIJK_WACHTWOORD,
    passwordConfirm: TIJDELIJK_WACHTWOORD,
    emailVisibility: true,
    verified: true,
    rol: 'jongere',
    naam: `${MERK} tijdelijke jongere`,
    wijk: wijkWest.id,
    taal: 'nl',
  });
  const T = tijdelijk.id;

  // --- Clients ----------------------------------------------------------------
  const tj = await userClient(TIJDELIJK_EMAIL, TIJDELIJK_WACHTWOORD);
  const j1 = await userClient(acc.jongere1.email, acc.jongere1.password);
  const hv1 = await userClient(acc.hulpvrager1.email, acc.hulpvrager1.password);

  try {
    // =========================================================================
    kop('A. Profiel aanmaken (tijdelijke jongere zonder profiel)');
    await magNiet('jongere kan geen profiel aanmaken MET verificatiestatus', () =>
      tj.collection('hh_profielen').create({ gebruiker: T, verificatiestatus: 'goedgekeurd' }));
    await magNiet('jongere kan geen profiel aanmaken MET vog_status', () =>
      tj.collection('hh_profielen').create({ gebruiker: T, vog_status: 'goedgekeurd' }));
    const profielT = await mag('jongere maakt eigen profiel aan zonder geblokkeerde velden', () =>
      tj.collection('hh_profielen').create({ gebruiker: T, over_mij: `${MERK} hallo` }));
    if (!profielT) throw new Error('zonder profiel van de tijdelijke jongere kan de rest niet');
    check('nieuw profiel heeft lege verificatiestatus (= nieuw voor de app)', profielT.verificatiestatus === '');

    kop('B. Screeningvelden zetten (tijdelijke jongere)');
    const nu = new Date().toISOString();
    const gevuld = await mag('jongere zet over_mij, iban, straal_km, beschikbaarheid, klustypes, vog_aangevraagd_op', () =>
      tj.collection('hh_profielen').update(profielT.id, {
        over_mij: `${MERK} Ik help graag met boodschappen.`,
        iban: 'NL91ABNA0417164300',
        straal_km: 5,
        beschikbaarheid: { ma: ['middag'], di: [], wo: ['ochtend', 'avond'], do: [], vr: [], za: ['ochtend'], zo: [] },
        klustypes: [typeId['boodschappen'], typeId['tuin']],
        vog_aangevraagd_op: nu,
      }));
    if (gevuld) {
      check('waarden staan zoals gestuurd', gevuld.iban === 'NL91ABNA0417164300' && gevuld.straal_km === 5 && gevuld.klustypes.length === 2 && gevuld.beschikbaarheid?.wo?.length === 2 && gevuld.vog_aangevraagd_op !== '');
    }
    const metDoc = await mag('jongere uploadt document_foto', () =>
      tj.collection('hh_profielen').update(profielT.id, { document_foto: png('document.png') }));
    check('document_foto staat op het record', !!metDoc?.document_foto);
    const metSelfie = await mag('jongere uploadt selfie', () =>
      tj.collection('hh_profielen').update(profielT.id, { selfie: png('selfie.png') }));
    check('selfie staat op het record', !!metSelfie?.selfie);

    kop('C. Geblokkeerde velden blijven dicht (tijdelijke jongere)');
    await magNiet('jongere kan vog_status niet zetten', () => tj.collection('hh_profielen').update(profielT.id, { vog_status: 'goedgekeurd' }));
    await magNiet('jongere kan iban_geverifieerd niet zetten', () => tj.collection('hh_profielen').update(profielT.id, { iban_geverifieerd: true }));
    await magNiet('jongere kan sterren_gemiddeld niet zetten', () => tj.collection('hh_profielen').update(profielT.id, { sterren_gemiddeld: 5 }));
    await magNiet('jongere kan klussen_aantal niet zetten', () => tj.collection('hh_profielen').update(profielT.id, { klussen_aantal: 99 }));
    await magNiet('jongere kan gebruiker niet omhangen', () => tj.collection('hh_profielen').update(profielT.id, { gebruiker: U.jongere2 }));
    await magNiet('jongere kan over_mij niet samen met vog_status sturen', () =>
      tj.collection('hh_profielen').update(profielT.id, { over_mij: 'x', vog_status: 'nieuw' }));

    kop('D. Statusmachine: alleen nieuw -> in_behandeling door de jongere');
    await magNiet('leeg (nieuw) -> goedgekeurd door jongere mag NIET', () => tj.collection('hh_profielen').update(profielT.id, { verificatiestatus: 'goedgekeurd' }));
    await magNiet('leeg (nieuw) -> afgewezen door jongere mag NIET', () => tj.collection('hh_profielen').update(profielT.id, { verificatiestatus: 'afgewezen' }));
    await magNiet('leeg (nieuw) -> nieuw (ongewijzigd meesturen) mag NIET', () => tj.collection('hh_profielen').update(profielT.id, { verificatiestatus: 'nieuw' }));
    const ingediend = await mag('leeg (nieuw) -> in_behandeling door jongere mag (ter controle aanbieden)', () =>
      tj.collection('hh_profielen').update(profielT.id, { verificatiestatus: 'in_behandeling' }));
    check('status is nu in_behandeling', ingediend?.verificatiestatus === 'in_behandeling');
    await magNiet('in_behandeling -> goedgekeurd door jongere mag NIET', () => tj.collection('hh_profielen').update(profielT.id, { verificatiestatus: 'goedgekeurd' }));
    await magNiet('in_behandeling -> in_behandeling (nogmaals) mag NIET', () => tj.collection('hh_profielen').update(profielT.id, { verificatiestatus: 'in_behandeling' }));
    await magNiet('in_behandeling -> nieuw (terugdraaien) mag NIET', () => tj.collection('hh_profielen').update(profielT.id, { verificatiestatus: 'nieuw' }));
    await mag('in_behandeling: gewone velden (over_mij) wijzigen mag nog wel', () => tj.collection('hh_profielen').update(profielT.id, { over_mij: `${MERK} aangepast` }));
    await su.collection('hh_profielen').update(profielT.id, { verificatiestatus: 'nieuw' });
    const ingediend2 = await mag('expliciet nieuw -> in_behandeling door jongere mag ook', () =>
      tj.collection('hh_profielen').update(profielT.id, { verificatiestatus: 'in_behandeling' }));
    check('status is weer in_behandeling', ingediend2?.verificatiestatus === 'in_behandeling');
    await magNiet('seed-jongere 1 (goedgekeurd) kan verificatiestatus niet op goedgekeurd zetten', async () => {
      const p = await su.collection('hh_profielen').getFirstListItem(`gebruiker = "${U.jongere1}"`);
      return j1.collection('hh_profielen').update(p.id, { verificatiestatus: 'goedgekeurd' });
    });
    await magNiet('seed-jongere 1 (goedgekeurd) kan niet terug naar in_behandeling', async () => {
      const p = await su.collection('hh_profielen').getFirstListItem(`gebruiker = "${U.jongere1}"`);
      return j1.collection('hh_profielen').update(p.id, { verificatiestatus: 'in_behandeling' });
    });

    kop('E. Klussen zichtbaar pas na goedkeuring (tijdelijke jongere, Tiel-West)');
    // Status staat nu op in_behandeling.
    let klussen = await tj.collection('hh_klussen').getFullList();
    check('in_behandeling: ziet open klussen k02/k11 in eigen wijk NIET', !heeft(klussen, K.k02) && !heeft(klussen, K.k11));
    check('in_behandeling: ziet helemaal geen klussen', klussen.length === 0);
    await magNiet('in_behandeling: kan k02 niet direct bekijken', () => tj.collection('hh_klussen').getOne(K.k02));
    await su.collection('hh_profielen').update(profielT.id, { verificatiestatus: 'nieuw' });
    klussen = await tj.collection('hh_klussen').getFullList();
    check('nieuw: ziet open klussen k02/k11 in eigen wijk NIET', !heeft(klussen, K.k02) && !heeft(klussen, K.k11));
    await su.collection('hh_profielen').update(profielT.id, { verificatiestatus: 'afgewezen' });
    klussen = await tj.collection('hh_klussen').getFullList();
    check('afgewezen: ziet open klussen k02/k11 in eigen wijk NIET', !heeft(klussen, K.k02) && !heeft(klussen, K.k11));
    await su.collection('hh_profielen').update(profielT.id, { verificatiestatus: 'goedgekeurd' });
    klussen = await tj.collection('hh_klussen').getFullList();
    check('na superuser-goedkeuring: ziet open klussen k02 en k11 WEL', heeft(klussen, K.k02) && heeft(klussen, K.k11));
    check('goedgekeurd: ziet open klus in Passewaaij (k03) nog steeds NIET', !heeft(klussen, K.k03));
    check('goedgekeurd: ziet toegewezen klus van jongere 1 (k04) NIET', !heeft(klussen, K.k04));
    await mag('goedgekeurd: kan k02 direct bekijken', () => tj.collection('hh_klussen').getOne(K.k02));

    kop('F. Seed-jongere 1: toegewezen klussen blijven zichtbaar ongeacht status');
    const profielJ1 = await su.collection('hh_profielen').getFirstListItem(`gebruiker = "${U.jongere1}"`);
    await su.collection('hh_profielen').update(profielJ1.id, { verificatiestatus: 'nieuw' });
    let klussenJ1 = await j1.collection('hh_klussen').getFullList();
    check('jongere 1 op nieuw: ziet toegewezen k04 en k07 WEL', heeft(klussenJ1, K.k04) && heeft(klussenJ1, K.k07));
    check('jongere 1 op nieuw: ziet open k02/k11 in eigen wijk NIET', !heeft(klussenJ1, K.k02) && !heeft(klussenJ1, K.k11));
    await mag('jongere 1 op nieuw: kan eigen over_mij en iban zetten', () =>
      j1.collection('hh_profielen').update(profielJ1.id, { over_mij: `${MERK} seed`, iban: 'NL02ABNA0123456789' }));
    await su.collection('hh_profielen').update(profielJ1.id, { verificatiestatus: 'goedgekeurd' });
    klussenJ1 = await j1.collection('hh_klussen').getFullList();
    check('jongere 1 weer goedgekeurd: ziet open k02/k11 WEER', heeft(klussenJ1, K.k02) && heeft(klussenJ1, K.k11));

    kop('G. Beschermde bestanden: alleen de eigenaar (met token) komt erbij');
    const recordT = await tj.collection('hh_profielen').getOne(profielT.id);
    const eigenaarMetToken = await haalBestand(tj, recordT, 'document_foto', true);
    check(`eigenaar haalt eigen document_foto op met bestandstoken (${eigenaarMetToken})`, eigenaarMetToken === 200);
    const eigenaarZonderToken = await haalBestand(tj, recordT, 'document_foto', false);
    check(`zonder token is zelfs de eigenaar geweigerd (${eigenaarZonderToken})`, WEIGER.includes(eigenaarZonderToken));
    await magNiet('oudere 1 kan het profiel van de jongere niet bekijken', () => hv1.collection('hh_profielen').getOne(profielT.id));
    const oudereMetToken = await haalBestand(hv1, recordT, 'document_foto', true);
    check(`oudere 1 kan document_foto NIET ophalen, ook niet met eigen bestandstoken (${oudereMetToken})`, WEIGER.includes(oudereMetToken));
    const oudereSelfie = await haalBestand(hv1, recordT, 'selfie', true);
    check(`oudere 1 kan selfie NIET ophalen (${oudereSelfie})`, WEIGER.includes(oudereSelfie));
    const suToken = await su.files.getToken();
    const suRes = await fetch(su.files.getURL(recordT, recordT.document_foto, { token: suToken }));
    check(`superuser (coordinator-pad) haalt document_foto wel op (${suRes.status})`, suRes.status === 200);
  } finally {
    // =========================================================================
    kop('H. Terugzetten en nameten');
    await ruimTijdelijkeOp();
    const weg = await su.collection('hh_users').getFirstListItem(`email = "${TIJDELIJK_EMAIL}"`).catch(() => null);
    check('tijdelijke jongere is verwijderd', weg === null);
    const profielWeg = await su.collection('hh_profielen').getFullList({ filter: `over_mij ~ "${MERK}" && gebruiker != "${U.jongere1}"` });
    check('profiel van de tijdelijke jongere is mee verwijderd (cascade)', profielWeg.length === 0);
    const { profiel: hersteld, account: accountNa } = await zetJ1TerugOpSeed();
    const { klustypeNamen, ...verwacht } = SEED_J1;
    for (const [veld, waarde] of Object.entries(verwacht)) {
      const echt = hersteld[veld];
      const gelijk = typeof waarde === 'object' ? canoniek(echt) === canoniek(waarde) : echt === waarde;
      check(`seed-jongere 1 ${veld} = ${JSON.stringify(waarde)}`, gelijk, `is ${JSON.stringify(echt)}`);
    }
    check('seed-jongere 1 account: foto leeg, geboortedatum en wijk = seed', accountNa.foto === '' && accountNa.geboortedatum === SEED_J1_ACCOUNT.geboortedatum && accountNa.wijk === wijkWest.id, `foto=${JSON.stringify(accountNa.foto)} geboortedatum=${accountNa.geboortedatum} wijk=${accountNa.wijk}`);
    check('seed-jongere 1 klustypes = seed (3 typen)', JSON.stringify([...hersteld.klustypes].sort()) === JSON.stringify([...seedKlustypesJ1].sort()));
    const klussenNa = await j1.collection('hh_klussen').getFullList();
    check('seed-jongere 1 ziet na afloop weer k02, k04, k07, k11', ['k02', 'k04', 'k07', 'k11'].every((k) => heeft(klussenNa, K[k])));
  }

  console.log(`\n${groen} groen, ${rood} rood (${groen + rood} checks).`);
  if (rood > 0) process.exit(1);
}

main().catch(fail);
