// HeitjeHulp M14 — bewijst het beheerpaneel op de ECHTE server. Werkt alleen
// met EIGEN tijdelijke accounts (e-mail "beheercheck-...@heitjehulp.invalid",
// door de superuser gemaakt en bevestigd) en eigen records met het merk
// "[beheercheck]". Er doen GEEN seed-accounts mee. Alles wordt aan het eind
// opgeruimd en nagemeten.
//
//   A. opruimen van een eerdere (gecrashte) run
//   B. voorwaarden (ook in dry-run): velden, collecties, rules met slot,
//      anoniem ziet niets op de nieuwe collecties
//   C. KEUZE 2 — elke andere rol en anoniem krijgt op elke paneel-aanroep
//      niets (lege lijst of 4xx), ook op de nieuwe collecties en routes;
//      de coordinator wel
//   D. de nieuwe velden kan alleen de coordinator zetten
//   E. blokkeren: niet meer inloggen, een oud token werkt niet meer op
//      hh-collecties en hh-routes; deblokkeren en weer binnen
//   F. een auditregel per beheerhandeling (wijk, klustype, gebruiker,
//      profiel, instelling, incident; aanmaken/wijzigen/verwijderen), en
//      geen regel bij een handeling van een niet-coordinator
//   G. telefonische aanmelding: coordinator maakt oudere + klus (bron
//      telefoon), die doorloopt accepteren -> onderweg -> bezig -> afgerond
//      via de bestaande routes, precies zoals een app-klus
//   H. opruimen en nameten
//
// LET OP: het incident in F en de open klus in G laten de hook van M8
// meldingen maken (voor elke coordinator en de jongeren in de wijk). Die
// worden in H weer verwijderd.
//
// DRAAIEN (na 60 --apply, 61 --apply en 63-hook-deploy.sh):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/62-beheercheck.mjs            (dry-run: alleen leescontroles)
//   node scripts/62-beheercheck.mjs --apply
//   node scripts/62-beheercheck.mjs --apply --alleen-opruimen

import { randomBytes } from 'node:crypto';
import { superuserClient, userClient, anonClient, assertHh, APPLY, fail, PB_URL } from './_lib.mjs';
import { EXTRA_VELDEN } from './60-beheer-velden.mjs';
import { NIEUWE_RULES, SLOT_VELDEN, slot } from './61-beheer-rules.mjs';

const MERK = '[beheercheck]';
const MAIL_PREFIX = 'beheercheck-';
const MAIL_DOMEIN = '@heitjehulp.invalid';
const TEL_DOMEIN = '@telefonisch.heitjehulp.invalid';
const INSTELLING = 'beheercheck_test';
const ALLEEN_OPRUIMEN = process.argv.includes('--alleen-opruimen');
const MELDING_GEBLOKKEERD = 'geblokkeerd';

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

async function route(client, pad, body) {
  try {
    return { status: 200, body: await client.send(pad, { method: 'POST', body }) };
  } catch (e) {
    return { status: e?.status ?? 0, body: e?.response ?? {} };
  }
}

/// Een lijst die "niets" geeft: 200 met 0 rijen, of een 4xx.
async function niets(client, col, filter = '') {
  const r = await probeer(() => client.collection(col).getList(1, 50, filter ? { filter } : {}));
  if (r.status !== 200) return { ok: r.status >= 400 && r.status < 500, uitleg: `status ${r.status}` };
  return { ok: r.record.totalItems === 0, uitleg: `${r.record.totalItems} rij(en)` };
}

async function opruimen(su) {
  let aantal = 0;
  const weg = async (col, filter, params) => {
    const rijen = await su.collection(col).getFullList({ filter: su.filter(filter, params) });
    for (const r of rijen) await su.collection(assertHh(col)).delete(r.id);
    aantal += rijen.length;
    return rijen;
  };
  const klussen = await su.collection('hh_klussen').getFullList({
    filter: su.filter('omschrijving ~ {:merk}', { merk: MERK }),
  });
  const incidenten = await su.collection('hh_incidenten').getFullList({
    filter: su.filter('omschrijving ~ {:merk}', { merk: MERK }),
  });
  // Meldingen van M8 over onze klussen en incidenten (ook bij seed-jongeren
  // en echte coordinatoren): eerst weg, ze verwijzen zonder cascade.
  for (const k of klussen) await weg('hh_meldingen', 'klus = {:id}', { id: k.id });
  for (const i of incidenten) await weg('hh_meldingen', 'incident = {:id}', { id: i.id });
  for (const k of klussen) await su.collection(assertHh('hh_klussen')).delete(k.id);
  for (const i of incidenten) await su.collection(assertHh('hh_incidenten')).delete(i.id);
  aantal += klussen.length + incidenten.length;

  await weg('hh_wijken', 'wijk ~ {:merk}', { merk: MERK });
  await weg('hh_klustypes', 'naam ~ {:merk}', { merk: MERK });
  await weg('hh_instellingen', 'sleutel = {:s}', { s: INSTELLING });

  const tijdelijk = await su.collection('hh_users').getFullList({
    filter: su.filter('email ~ {:prefix} || naam ~ {:merk}', { prefix: MAIL_PREFIX, merk: MERK }),
  });
  for (const u of tijdelijk) {
    // Verplichte relaties ZONDER cascade: eerst die records weg.
    await weg('hh_koppelingen', 'oudere = {:id} || familielid = {:id}', { id: u.id });
    await weg('hh_incidenten', 'melder = {:id}', { id: u.id });
    await weg('hh_beoordelingen', 'van_gebruiker = {:id} || naar_gebruiker = {:id}', { id: u.id });
    const eigenKlussen = await su.collection('hh_klussen').getFullList({
      filter: su.filter('hulpvrager = {:id} || geplaatst_door = {:id} || toegewezen_jongere = {:id}', { id: u.id }),
    });
    for (const k of eigenKlussen) {
      await weg('hh_meldingen', 'klus = {:id}', { id: k.id });
      await su.collection(assertHh('hh_klussen')).delete(k.id);
    }
    // Auditregels van en over onze tijdelijke accounts.
    await weg('hh_auditlog', 'door = {:id} || doel_id = {:id}', { id: u.id });
  }
  for (const u of tijdelijk) await su.collection(assertHh('hh_users')).delete(u.id);
  aantal += tijdelijk.length;
  if (aantal) console.log(`  ↻ ${aantal} record(s) verwijderd (waarvan ${tijdelijk.length} tijdelijk(e) account(s))`);
  return aantal;
}

async function voorwaarden(su) {
  kop('B. Voorwaarden op de server (alleen lezen)');
  for (const [naam, velden] of Object.entries(EXTRA_VELDEN)) {
    const col = await su.collections.getOne(naam);
    for (const v of velden) check(`${naam}.${v.name} bestaat`, col.fields.some((f) => f.name === v.name), 'draai 60 --apply');
  }
  for (const [naam, rules] of Object.entries(NIEUWE_RULES)) {
    const col = await probeer(() => su.collections.getOne(naam));
    check(`${naam} bestaat`, col.status === 200, 'draai 60 --apply');
    if (col.status !== 200) continue;
    for (const [k, r] of Object.entries(rules)) {
      check(`${naam}.${k} zoals 61 hem zet`, (col.record[k] ?? null) === r, JSON.stringify(col.record[k] ?? null));
    }
  }
  for (const [naam, velden] of Object.entries(SLOT_VELDEN)) {
    const col = await su.collections.getOne(naam);
    for (const k of ['createRule', 'updateRule']) {
      check(`${naam}.${k} heeft het M14-slot`, String(col[k] ?? '').includes(slot(velden)), 'draai 61 --apply');
    }
  }
  const anon = anonClient();
  for (const col of ['hh_instellingen', 'hh_auditlog']) {
    const n = await niets(anon, col);
    check(`anoniem ziet niets op ${col}`, n.ok, n.uitleg);
  }
}

async function main() {
  for (const c of ['hh_users', 'hh_profielen', 'hh_klussen', 'hh_instellingen', 'hh_auditlog']) assertHh(c);
  const su = await superuserClient();
  console.log('Verbonden met', PB_URL, APPLY ? '(APPLY)' : '(DRY-RUN)', '\n');

  if (!APPLY) {
    console.log('DRY-RUN: er wordt NIETS geschreven.');
    await voorwaarden(su);
    console.log('\nWat --apply ZOU doen:');
    console.log(`  · tijdelijke accounts maken (${MAIL_PREFIX}...${MAIL_DOMEIN}), één per rol, en records "${MERK}";`);
    console.log('  · per rol en anoniem nameten dat het paneel niets oplevert; de coordinator wel;');
    console.log('  · blokkeren, inloggen weigeren, oud token weigeren, deblokkeren;');
    console.log('  · per beheerhandeling een auditregel nameten;');
    console.log('  · een telefonische klus laten doorlopen tot afgerond;');
    console.log('  · alles opruimen en nameten.');
    console.log(`\n${groen} groen, ${rood} rood (leescontroles).`);
    if (rood > 0) console.log('Rood is verwacht zolang 60, 61 en 63 nog niet uitgerold zijn.');
    return;
  }

  kop('A. Opruimen van een eerdere run');
  await opruimen(su);
  if (ALLEEN_OPRUIMEN) {
    console.log('\nAlleen opgeruimd.');
    return;
  }

  await voorwaarden(su);

  const wijk = await su.collection('hh_wijken').getFirstListItem('wijk = "Tiel-West"');
  const klustype = await su.collection('hh_klustypes').getFirstListItem('naam = "boodschappen"');
  const wachtwoord = randomBytes(18).toString('base64url');

  async function tijdelijkAccount(label, rol, extra = {}) {
    const email = `${MAIL_PREFIX}${label}-${randomBytes(4).toString('hex')}${MAIL_DOMEIN}`;
    const record = await su.collection(assertHh('hh_users')).create({
      email,
      password: wachtwoord,
      passwordConfirm: wachtwoord,
      verified: true,
      rol,
      naam: `${MERK} ${label}`,
      taal: 'nl',
      wijk: wijk.id,
      ...extra,
    });
    return { id: record.id, email, client: await userClient(email, wachtwoord) };
  }

  const coord = await tijdelijkAccount('coordinator', 'coordinator');
  const oudere = await tijdelijkAccount('oudere', 'hulpvrager');
  const jongere = await tijdelijkAccount('jongere', 'jongere');
  const familie = await tijdelijkAccount('familie', 'familie');
  const profielJongere = await su.collection(assertHh('hh_profielen')).create({
    gebruiker: jongere.id,
    verificatiestatus: 'goedgekeurd',
    vog_status: 'goedgekeurd',
  });
  const profielFamilie = await su.collection(assertHh('hh_profielen')).create({ gebruiker: familie.id });
  // Een klus en een incident van een ANDER (de oudere), om te zien dat de
  // anderen er niet bij kunnen.
  const klusOudere = await su.collection(assertHh('hh_klussen')).create({
    hulpvrager: oudere.id,
    geplaatst_door: oudere.id,
    klustype: klustype.id,
    omschrijving: `${MERK} klus van de oudere`,
    adres: ADRES,
    lat: LAT,
    lon: LON,
    status: 'concept',
    bron: 'app',
  });
  const incidentOudere = await su.collection(assertHh('hh_incidenten')).create({
    melder: oudere.id,
    soort: 'overig',
    omschrijving: `${MERK} incident van de oudere`,
  });
  await su.collection(assertHh('hh_instellingen')).create({ sleutel: INSTELLING, waarde: 1 });

  kop('C. Keuze 2 — andere rollen en anoniem krijgen niets');
  const anderen = [
    ['anoniem', anonClient(), ''],
    ['oudere', oudere.client, oudere.id],
    ['jongere', jongere.client, jongere.id],
    ['familie', familie.client, familie.id],
  ];
  for (const [naam, client, id] of anderen) {
    for (const col of ['hh_instellingen', 'hh_auditlog']) {
      const n = await niets(client, col);
      check(`${naam}: geen ${col}`, n.ok, n.uitleg);
    }
    const nieuweInstelling = await probeer(() => client.collection('hh_instellingen').create({ sleutel: `${INSTELLING}_${naam}`, waarde: 1 }));
    check(`${naam}: instelling aanmaken geweigerd`, nieuweInstelling.status >= 400, `status ${nieuweInstelling.status}`);
    const nieuweRegel = await probeer(() =>
      client.collection('hh_auditlog').create({ actie: 'aanmaken', doel_collectie: 'hh_wijken', doel_id: 'x' }),
    );
    check(`${naam}: auditregel schrijven geweigerd`, nieuweRegel.status >= 400, `status ${nieuweRegel.status}`);
    const andermansProfiel = await niets(client, 'hh_profielen', `id = "${profielJongere.id}"`);
    if (naam !== 'jongere') check(`${naam}: profiel van de jongere onzichtbaar`, andermansProfiel.ok, andermansProfiel.uitleg);
    const gebruikers = await probeer(() => client.collection('hh_users').getList(1, 50, { filter: `id != "${id}"` }));
    if (naam === 'anoniem' || naam === 'familie') {
      check(
        `${naam}: geen andere gebruikers`,
        gebruikers.status >= 400 || gebruikers.record.totalItems === 0,
        gebruikers.record ? `${gebruikers.record.totalItems} rij(en)` : `status ${gebruikers.status}`,
      );
    }
    if (naam !== 'oudere') {
      const inc = await niets(client, 'hh_incidenten', `id = "${incidentOudere.id}"`);
      check(`${naam}: incident van een ander onzichtbaar`, inc.ok, inc.uitleg);
      const klus = await niets(client, 'hh_klussen', `id = "${klusOudere.id}"`);
      check(`${naam}: conceptklus van een ander onzichtbaar`, klus.ok, klus.uitleg);
      const afhandelen = await probeer(() => client.collection('hh_incidenten').update(incidentOudere.id, { afhandeling: 'x' }));
      check(`${naam}: incident afhandelen geweigerd`, afhandelen.status >= 400, `status ${afhandelen.status}`);
    }
    const blokkeer = await probeer(() => client.collection('hh_users').update(jongere.id === id ? oudere.id : jongere.id, { geblokkeerd: true }));
    check(`${naam}: iemand anders blokkeren geweigerd`, blokkeer.status >= 400, `status ${blokkeer.status}`);
    const rol = await probeer(() => client.collection('hh_users').update(jongere.id === id ? oudere.id : jongere.id, { rol: 'coordinator' }));
    check(`${naam}: rol van een ander wijzigen geweigerd`, rol.status >= 400, `status ${rol.status}`);
    const wijkUit = await probeer(() => client.collection('hh_wijken').update(wijk.id, { actief: wijk.actief }));
    check(`${naam}: wijk wijzigen geweigerd`, wijkUit.status >= 400, `status ${wijkUit.status}`);
    const kt = await probeer(() => client.collection('hh_klustypes').update(klustype.id, { richtduur: klustype.richtduur }));
    check(`${naam}: klustype wijzigen geweigerd`, kt.status >= 400, `status ${kt.status}`);
    const koppel = await route(client, `/api/hh/klussen/${klusOudere.id}/koppelen`, { jongere: jongere.id });
    check(`${naam}: koppelen geweigerd (401/403)`, koppel.status === 401 || koppel.status === 403, `status ${koppel.status}`);
    const vrij = await route(client, `/api/hh/klussen/${klusOudere.id}/vrijgeven`, { reden: 'check' });
    check(`${naam}: vrijgeven geweigerd (401/403)`, vrij.status === 401 || vrij.status === 403, `status ${vrij.status}`);
    const bet = await niets(client, 'hh_betalingen', `klus = "${klusOudere.id}"`);
    if (naam !== 'oudere') check(`${naam}: betalingen van een ander onzichtbaar`, bet.ok, bet.uitleg);
  }
  const coordInst = await coord.client.collection('hh_instellingen').getList(1, 50, { filter: `sleutel = "${INSTELLING}"` });
  check('coordinator ziet de instellingen', coordInst.totalItems === 1);
  const coordProf = await coord.client.collection('hh_profielen').getList(1, 1, { filter: `id = "${profielJongere.id}"` });
  check('coordinator ziet het profiel van de jongere', coordProf.totalItems === 1);

  kop('D. Nieuwe velden: alleen de coordinator');
  const eigenBlok = await probeer(() => jongere.client.collection('hh_users').update(jongere.id, { geblokkeerd: false }));
  check('jongere zet zijn eigen geblokkeerd niet', eigenBlok.status >= 400, `status ${eigenBlok.status}`);
  const registratie = await probeer(() =>
    anonClient().collection('hh_users').create({
      email: `${MAIL_PREFIX}registratie-${randomBytes(4).toString('hex')}${MAIL_DOMEIN}`,
      password: wachtwoord,
      passwordConfirm: wachtwoord,
      rol: 'jongere',
      naam: `${MERK} registratie`,
      geblokkeerd: false,
    }),
  );
  check('registreren met geblokkeerd in de body geweigerd', registratie.status >= 400, `status ${registratie.status}`);
  const eigenNotitie = await probeer(() => jongere.client.collection('hh_profielen').update(profielJongere.id, { screening_notitie: 'zelf' }));
  check('jongere zet zijn eigen screening_notitie niet', eigenNotitie.status >= 400, `status ${eigenNotitie.status}`);
  const eigenVog = await probeer(() => familie.client.collection('hh_profielen').update(profielFamilie.id, { vog_geldig_tot: '2030-01-01 12:00:00.000Z' }));
  check('eigenaar zet vog_geldig_tot niet', eigenVog.status >= 400, `status ${eigenVog.status}`);
  const eigenOverMij = await probeer(() => familie.client.collection('hh_profielen').update(profielFamilie.id, { over_mij: `${MERK} gewoon` }));
  check('eigenaar mag de rest van zijn profiel nog wel wijzigen', eigenOverMij.status === 200, `status ${eigenOverMij.status}`);

  kop('E. Blokkeren');
  await coord.client.collection('hh_users').update(familie.id, { geblokkeerd: true });
  const login = await probeer(() => userClient(familie.email, wachtwoord));
  check('geblokkeerd: inloggen geweigerd (400)', login.status === 400, `status ${login.status}`);
  check('met een nette melding', String(login.body?.message || '').includes(MELDING_GEBLOKKEERD), JSON.stringify(login.body));
  const oudToken = await probeer(() => familie.client.collection('hh_klussen').getList(1, 1));
  check('geblokkeerd: oud token op hh-collectie 403', oudToken.status === 403, `status ${oudToken.status}`);
  const oudRoute = await route(familie.client, `/api/hh/klussen/${klusOudere.id}/annuleren`, { reden: 'geblokkeerd?' });
  check('geblokkeerd: oud token op hh-route 403', oudRoute.status === 403, `status ${oudRoute.status}`);
  const verversen = await probeer(() => familie.client.collection('hh_users').authRefresh());
  check('geblokkeerd: token verversen geweigerd', verversen.status === 403, `status ${verversen.status}`);
  await coord.client.collection('hh_users').update(familie.id, { geblokkeerd: false });
  const weer = await probeer(() => userClient(familie.email, wachtwoord));
  check('gedeblokkeerd: weer inloggen', weer.status === 200, `status ${weer.status}`);

  kop('F. Auditregel per beheerhandeling');
  async function regel(actie, col, id) {
    const rijen = await su.collection('hh_auditlog').getFullList({
      filter: su.filter('door = {:door} && actie = {:actie} && doel_collectie = {:col} && doel_id = {:id}', {
        door: coord.id,
        actie,
        col,
        id,
      }),
    });
    return rijen;
  }
  const geblokkeerdRegels = await regel('wijzigen', 'hh_users', familie.id);
  check('blokkeren en deblokkeren: twee regels op hh_users', geblokkeerdRegels.length === 2, `${geblokkeerdRegels.length}`);
  check(
    'detail noemt het veld geblokkeerd',
    geblokkeerdRegels.every((r) => (r.detail?.velden || []).includes('geblokkeerd')),
    JSON.stringify(geblokkeerdRegels[0]?.detail),
  );
  const nieuweWijk = await coord.client.collection('hh_wijken').create({ gemeente: 'Tiel', wijk: `${MERK} wijk`, postcodes: ['9999'], actief: false });
  await coord.client.collection('hh_wijken').update(nieuweWijk.id, { actief: true });
  await coord.client.collection('hh_wijken').delete(nieuweWijk.id);
  for (const actie of ['aanmaken', 'wijzigen', 'verwijderen']) {
    check(`hh_wijken ${actie}: één regel`, (await regel(actie, 'hh_wijken', nieuweWijk.id)).length === 1);
  }
  const nieuwType = await coord.client.collection('hh_klustypes').create({ naam: `${MERK} type`, richtduur: 30, richtvergoeding: 500 });
  await coord.client.collection('hh_klustypes').update(nieuwType.id, { richtvergoeding: 750 });
  check('hh_klustypes aanmaken: één regel', (await regel('aanmaken', 'hh_klustypes', nieuwType.id)).length === 1);
  const typeWijzig = await regel('wijzigen', 'hh_klustypes', nieuwType.id);
  check('hh_klustypes wijzigen: van 500 naar 750', typeWijzig[0]?.detail?.naar?.richtvergoeding === 750, JSON.stringify(typeWijzig[0]?.detail));
  await coord.client.collection('hh_klustypes').delete(nieuwType.id);
  await coord.client.collection('hh_profielen').update(profielJongere.id, {
    screening_notitie: `${MERK} goedgekeurd`,
    vog_geldig_tot: '2027-09-01 12:00:00.000Z',
  });
  check('hh_profielen wijzigen (screening): één regel', (await regel('wijzigen', 'hh_profielen', profielJongere.id)).length === 1);
  const inst = (await su.collection('hh_instellingen').getFirstListItem(su.filter('sleutel = {:s}', { s: INSTELLING }))).id;
  await coord.client.collection('hh_instellingen').update(inst, { waarde: 2 });
  check('hh_instellingen wijzigen: één regel', (await regel('wijzigen', 'hh_instellingen', inst)).length === 1);
  await coord.client.collection('hh_incidenten').update(incidentOudere.id, { afhandeling: `${MERK} gebeld` });
  check('hh_incidenten afhandelen: één regel', (await regel('wijzigen', 'hh_incidenten', incidentOudere.id)).length === 1);
  await oudere.client.collection('hh_users').update(oudere.id, { naam: `${MERK} oudere (zelf gewijzigd)` });
  const zelf = await su.collection('hh_auditlog').getFullList({ filter: su.filter('doel_id = {:id}', { id: oudere.id }) });
  check('een handeling van een niet-coordinator geeft geen regel', zelf.length === 0, `${zelf.length}`);
  const geheim = await su.collection('hh_auditlog').getFullList({ filter: su.filter('door = {:id}', { id: coord.id }) });
  check('geen wachtwoord of IBAN in het auditlog', !geheim.some((r) => /password":"|NL\d\d[A-Z]{4}/.test(JSON.stringify(r.detail))));

  kop('G. Telefonische aanmelding loopt als een app-klus');
  const telefoon = `09${String(Date.now()).slice(-8)}`;
  const nieuweOudere = await coord.client.collection('hh_users').create({
    email: `${telefoon}${TEL_DOMEIN}`,
    emailVisibility: false,
    password: wachtwoord,
    passwordConfirm: wachtwoord,
    rol: 'hulpvrager',
    naam: `${MERK} telefonische oudere`,
    telefoon,
    adres: 'Prins Bernhardlaan 12',
    plaats: 'Tiel',
    wijk: wijk.id,
    taal: 'nl',
  });
  check('coordinator maakt een oudere zonder e-mail (telefonisch adres)', nieuweOudere.rol === 'hulpvrager');
  check('auditregel bij het aanmaken van de oudere', (await regel('aanmaken', 'hh_users', nieuweOudere.id)).length === 1);
  const van = new Date(Date.now() + 24 * 3600 * 1000);
  const telKlus = await coord.client.collection('hh_klussen').create({
    hulpvrager: nieuweOudere.id,
    geplaatst_door: coord.id,
    klustype: klustype.id,
    omschrijving: `${MERK} telefonische klus`,
    adres: ADRES,
    lat: LAT,
    lon: LON,
    wanneer_van: van.toISOString(),
    wanneer_tot: new Date(van.getTime() + 3600 * 1000).toISOString(),
    status: 'open',
    bedrag_bruto: klustype.richtvergoeding,
    vergoeding_jongere: klustype.richtvergoeding,
    commissie: 0,
    bron: 'telefoon',
  });
  const ziet = await jongere.client.collection('hh_klussen').getList(1, 1, { filter: `id = "${telKlus.id}"` });
  check('de goedgekeurde jongere in de wijk ziet de klus', ziet.totalItems === 1);
  const acc = await route(jongere.client, `/api/hh/klussen/${telKlus.id}/accepteren`, {});
  check('accepteren 200', acc.status === 200, `status ${acc.status} ${JSON.stringify(acc.body)}`);
  for (const naar of ['onderweg', 'bezig', 'afgerond']) {
    const r = await route(jongere.client, `/api/hh/klussen/${telKlus.id}/status`, { naar });
    check(`status -> ${naar} 200`, r.status === 200, `status ${r.status} ${JSON.stringify(r.body)}`);
  }
  const eind = await su.collection('hh_klussen').getOne(telKlus.id);
  check('klus is afgerond, bron telefoon, geplaatst door de coordinator', eind.status === 'afgerond' && eind.bron === 'telefoon' && eind.geplaatst_door === coord.id);
  const logs = await su.collection('hh_klus_status').getFullList({ filter: su.filter('klus = {:id}', { id: telKlus.id }), sort: 'created' });
  check(
    'vijf logregels: open, geaccepteerd, onderweg, bezig, afgerond',
    logs.map((l) => l.naar).join(',') === 'open,geaccepteerd,onderweg,bezig,afgerond',
    logs.map((l) => l.naar).join(','),
  );

  kop('H. Opruimen en nameten');
  await opruimen(su);
  const rest = await su.collection('hh_users').getFullList({
    filter: su.filter('email ~ {:prefix} || naam ~ {:merk}', { prefix: MAIL_PREFIX, merk: MERK }),
  });
  const restKlus = await su.collection('hh_klussen').getFullList({ filter: su.filter('omschrijving ~ {:merk}', { merk: MERK }) });
  check('geen tijdelijke accounts meer', rest.length === 0, `${rest.length}`);
  check('geen eigen klussen meer', restKlus.length === 0, `${restKlus.length}`);

  console.log(`\n${groen} groen, ${rood} rood.`);
  if (rood > 0) process.exitCode = 1;
}

main().catch(async (e) => {
  console.error('\nAFGEBROKEN — draai daarna --apply --alleen-opruimen.');
  fail(e);
});
