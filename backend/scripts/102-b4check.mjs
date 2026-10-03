// HeitjeHulp B4 — bewijst de B4-velden (100), -rules (101), -hooks (103) en
// de seed-goedkeuring (104) op de ECHTE server. Werkt alleen met EIGEN
// tijdelijke accounts ("b4check-...@heitjehulp.invalid") en eigen klussen, en
// ruimt alles op (ook bij een eerdere, gecrashte run). Seed-accounts doen
// niet mee; seed-klussen worden alleen gelezen.
//
//   A. opruimen van een eerdere run
//   B. voorwaarden (ook in dry-run, alleen lezen): velden, 13 categorieën,
//      oude types met een leeftijd, rules, keur-route bestaat, seed gekeurd
//   C. plaatsen door een bewoner: foto, omschrijving, vinkje en tijd
//      verplicht; keur- en rekenvelden niet zelf te zetten; markering en
//      leeftijdsgrens door de server; een concept mag nog zonder foto
//   D. ongekeurd = onzichtbaar voor helpers, niet te accepteren, geen melding
//   E. alleen de coordinator keurt
//   F. goedkeuren: helper van 14 en 25 zien de tuinklus, helper van 11 niet
//      en kan hem niet accepteren (403 leeftijd); melding "nieuwe klus" alleen
//      aan wie oud genoeg is; foto alleen met bestandstoken van wie hem ziet
//   G. leeftijd per categorie en de tijdregel (07:00-19:00, 2 uur, 17:00;
//      10 t/m 14 jaar: om 18:00 klaar, zonder eindtijd uiterlijk 16:00)
//   H. wijzigen na goedkeuring door de bewoner: opnieuw nakijken
//   I. afkeuren: geannuleerd, één melding met de reden
//   J. telefonische ingang: de coordinator plaatst namens een bewoner,
//      zonder foto, meteen goedgekeurd
//   K. opruimen en nameten
//
// DRAAIEN (na 100 --apply, 103-hook-deploy.sh, 101 --apply, 104 --apply):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/102-b4check.mjs            (dry-run: alleen leescontroles)
//   node scripts/102-b4check.mjs --apply
//   node scripts/102-b4check.mjs --apply --alleen-opruimen

import { randomBytes } from 'node:crypto';
import { superuserClient, userClient, anonClient, assertHh, APPLY, fail, PB_URL } from './_lib.mjs';
import { B4_VELDNAMEN, plaatsHulp } from './100-b4-velden.mjs';
import { B4_HELPER_VOORWAARDE, KEUR_SLOT } from './101-b4-rules.mjs';
import { SEED_MERK } from './104-b4-seed-keuren.mjs';
import { REGIO_WIJK } from './81-b2-werkgebied.mjs';

const MAIL_PREFIX = 'b4check-';
const MAIL_DOMEIN = '@heitjehulp.invalid';
const MERK = '[b4check]';
const ALLEEN_OPRUIMEN = process.argv.includes('--alleen-opruimen');

const PNG_1X1 = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
  'base64',
);
const png = () => new File([PNG_1X1], 'klus.png', { type: 'image/png' });

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
const kop = (t) => console.log(`\n${t}`);
async function mag(label, fn) {
  try {
    const r = await fn();
    check(label, true);
    return r;
  } catch (e) {
    check(label, false, `status=${e?.status} ${e?.response?.message ?? e?.message ?? ''}`);
    return null;
  }
}
async function magNiet(label, fn, codes = [400], tekst) {
  try {
    await fn();
    check(label, false, 'verzoek is onterecht gelukt');
    return null;
  } catch (e) {
    const melding = e?.response?.message ?? '';
    const goed = codes.includes(e?.status) && (!tekst || tekst.test(melding));
    check(`${label} (${e?.status})`, goed, `status=${e?.status} ${melding}`);
    return e;
  }
}
async function route(client, pad, body = {}) {
  try {
    return { status: 200, body: await client.send(pad, { method: 'POST', body }) };
  } catch (e) {
    return { status: e?.status ?? 0, body: e?.response ?? {} };
  }
}

/// Geboortedatum van iemand die op [opDag] ("YYYY-MM-DD") [jaren] oud is.
function geboren(jaren, opDag) {
  const [j, m, d] = opDag.split('-').map(Number);
  return `${j - jaren}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')} 00:00:00.000Z`;
}
const nu = () => new Date().toISOString().replace('T', ' ');

/// Overmorgen in Nederland: { datum, om(uur, minuut) -> ISO in UTC }.
function overmorgen() {
  const dag = plaatsHulp.nlTijd(new Date(Date.now() + 2 * 24 * 3600 * 1000).toISOString()).datum;
  const [j, m, d] = dag.split('-').map(Number);
  const om = (uur, minuut = 0) => {
    for (const verschil of [1, 2]) {
      const iso = new Date(Date.UTC(j, m - 1, d, uur - verschil, minuut)).toISOString();
      const t = plaatsHulp.nlTijd(iso);
      if (t.datum === dag && t.minuten === uur * 60 + minuut) return iso;
    }
    throw new Error(`geen UTC-moment voor ${dag} ${uur}:${minuut}`);
  };
  return { datum: dag, om };
}

async function opruimen(su) {
  const tijdelijk = await su.collection('hh_users').getFullList({
    filter: su.filter('email ~ {:prefix}', { prefix: MAIL_PREFIX }),
  });
  let aantal = 0;
  const weg = async (col, filter, params) => {
    const rijen = await su.collection(col).getFullList({ filter: su.filter(filter, params) });
    for (const r of rijen) await su.collection(assertHh(col)).delete(r.id);
    return rijen.length;
  };
  for (const u of tijdelijk) {
    const klussen = await su.collection('hh_klussen').getFullList({
      filter: su.filter('hulpvrager = {:id} || geplaatst_door = {:id} || toegewezen_jongere = {:id}', { id: u.id }),
    });
    for (const k of klussen) {
      aantal += await weg('hh_meldingen', 'klus = {:id}', { id: k.id });
      await su.collection(assertHh('hh_klussen')).delete(k.id); // logregels gaan mee (cascade)
      aantal++;
    }
    aantal += await weg('hh_meldingen', 'ontvanger = {:id}', { id: u.id });
    const profielen = await su.collection('hh_profielen').getFullList({ filter: su.filter('gebruiker = {:id}', { id: u.id }) });
    for (const id of [u.id, ...profielen.map((p) => p.id)]) {
      aantal += await weg('hh_auditlog', 'door = {:id} || doel_id = {:id}', { id });
    }
  }
  for (const u of tijdelijk) await su.collection(assertHh('hh_users')).delete(u.id);
  aantal += tijdelijk.length;
  if (aantal) console.log(`  ↻ ${aantal} record(s) verwijderd (waarvan ${tijdelijk.length} tijdelijk(e) account(s))`);
}

async function voorwaarden(su) {
  kop('B. Voorwaarden op de server (alleen lezen)');
  for (const [naam, velden] of Object.entries(B4_VELDNAMEN)) {
    const col = await su.collections.getOne(naam);
    const mist = velden.filter((v) => !col.fields.some((f) => f.name === v));
    check(`${naam}: B4-velden bestaan`, !mist.length, `ontbreekt: ${mist.join(', ')} — draai 100 --apply`);
  }
  const klussenCol = await su.collections.getOne('hh_klussen');
  const foto = klussenCol.fields.find((f) => f.name === 'foto');
  check('hh_klussen.foto is protected', foto?.protected === true);
  for (const rule of ['listRule', 'viewRule']) {
    check(`hh_klussen.${rule} heeft de B4-voorwaarde`, String(klussenCol[rule] ?? '').includes(B4_HELPER_VOORWAARDE), 'draai 101 --apply');
  }
  for (const rule of ['createRule', 'updateRule']) {
    check(`hh_klussen.${rule} heeft het keur-slot`, String(klussenCol[rule] ?? '').includes(KEUR_SLOT), 'draai 101 --apply');
  }
  const types = await su.collection('hh_klustypes').getFullList();
  const perNaam = new Map(types.map((t) => [t.naam, t]));
  const goed = plaatsHulp.KLUS_CATEGORIEEN.every((c) => {
    const t = perNaam.get(c.naam);
    return t && t.actief === true && t.min_leeftijd === c.min_leeftijd && t.volgorde === c.volgorde;
  });
  check('de 13 categorieën bestaan (actief, leeftijd, volgorde)', goed, 'draai 100 --apply');
  const oud = types.filter((t) => !plaatsHulp.KLUS_CATEGORIEEN.some((c) => c.naam === t.naam));
  check(`oude klustypes (${oud.length}) niet actief en met een leeftijd`, oud.every((t) => !t.actief && t.min_leeftijd >= 10), oud.map((t) => `${t.naam}:${t.min_leeftijd}`).join(' '));
  const r = await route(anonClient(), '/api/hh/klussen/bestaatniet/keuren', { besluit: 'goedkeuren' });
  check(`keur-route bestaat (anoniem 401, kreeg ${r.status})`, r.status === 401, 'draai 103-hook-deploy.sh');
  // Zonder het veld (100 nog niet gedraaid) weigert PocketBase het filter.
  const seedOngekeurd = await su
    .collection('hh_klussen')
    .getFullList({ filter: su.filter('omschrijving ~ {:merk} && klus_goedgekeurd_op = ""', { merk: SEED_MERK }) })
    .catch(() => null);
  check(
    'alle seed-klussen zijn goedgekeurd (104)',
    seedOngekeurd !== null && seedOngekeurd.length === 0,
    seedOngekeurd === null ? 'veld ontbreekt — draai 100 en 104 --apply' : `${seedOngekeurd.length} ongekeurd — draai 104 --apply`,
  );
  return { perNaam, regio: (await su.collection('hh_wijken').getFullList({ filter: su.filter('wijk = {:w}', { w: REGIO_WIJK.wijk }) }))[0] };
}

async function main() {
  for (const c of ['hh_users', 'hh_profielen', 'hh_klussen', 'hh_meldingen', 'hh_auditlog']) assertHh(c);
  const su = await superuserClient();
  console.log('Verbonden met', PB_URL, APPLY ? '(APPLY)' : '(DRY-RUN)', '\n');

  if (!APPLY) {
    console.log('DRY-RUN: er wordt NIETS geschreven.');
    await voorwaarden(su);
    console.log('\nWat --apply ZOU doen:');
    console.log(`  · tijdelijke accounts maken (${MAIL_PREFIX}...${MAIL_DOMEIN}): coordinator, 2 bewoners, helpers van 11, 14, 17 en 25;`);
    console.log('  · ±12 eigen klussen met een testfoto (1x1 png), keuren/afkeuren, accepteren, meldingen en foto-toegang nameten;');
    console.log('  · alles opruimen en nameten. Geen Nominatim: elke klus krijgt lat/lon mee.');
    console.log(`\n${groen} groen, ${rood} rood (leescontroles).`);
    if (rood > 0) console.log('Rood is verwacht zolang 100, 103, 101 en 104 nog niet uitgerold zijn.');
    return;
  }

  kop('A. Opruimen van een eerdere run');
  await opruimen(su);
  if (ALLEEN_OPRUIMEN) {
    console.log('\nAlleen opgeruimd.');
    return;
  }

  const { perNaam, regio } = await voorwaarden(su);
  const tuin = perNaam.get('Tuin');
  const boodschappen = perNaam.get('Boodschappen');
  const schoonmaak = perNaam.get('Schoonmaak');
  if (!tuin || !boodschappen || !schoonmaak || !regio) {
    console.log('\nZonder de categorieën en de regio-wijk kan de check niet verder.');
    process.exitCode = 1;
    return;
  }

  const dag = overmorgen();
  const wachtwoord = randomBytes(18).toString('base64url');
  async function account(label, rol, extra = {}) {
    const email = `${MAIL_PREFIX}${label}-${randomBytes(4).toString('hex')}${MAIL_DOMEIN}`;
    const record = await su.collection(assertHh('hh_users')).create({
      email, password: wachtwoord, passwordConfirm: wachtwoord, verified: true,
      rol, naam: `${MERK} ${label}`, taal: 'nl', ...extra,
    });
    return { id: record.id, record, client: await userClient(email, wachtwoord) };
  }
  async function helper(label, jaren) {
    const volwassen = jaren >= 18;
    const h = await account(label, 'jongere', {
      geboortedatum: geboren(jaren, dag.datum),
      wijk: regio.id,
      ...(volwassen ? {} : { ouder_toestemming_op: nu() }),
    });
    await su.collection(assertHh('hh_profielen')).create({
      gebruiker: h.id, verificatiestatus: 'goedgekeurd', ...(volwassen ? { vog_gezien_op: nu() } : {}),
    });
    return h;
  }

  const coord = await account('coordinator', 'coordinator');
  const bewoner = await account('bewoner', 'hulpvrager', { wijk: regio.id, adres: 'Teststraat 1', plaats: 'Tiel' });
  const bewoner2 = await account('bewoner-telefoon', 'hulpvrager', { wijk: regio.id, adres: 'Teststraat 2', plaats: 'Tiel' });
  const h11 = await helper('elf', 11);
  const h14 = await helper('veertien', 14);
  const h17 = await helper('zeventien', 17);
  const h25 = await helper('vijfentwintig', 25);

  const klus = (extra = {}) => ({
    hulpvrager: bewoner.id,
    geplaatst_door: bewoner.id,
    bron: 'app',
    status: 'open',
    klustype: tuin.id,
    omschrijving: `${MERK} De heg knippen, het afval mag in de groene bak.`,
    adres: 'Teststraat 1, Tiel',
    lat: 51.88,
    lon: 5.42,
    wanneer_van: dag.om(14),
    wanneer_tot: dag.om(15),
    nee_lijst_akkoord: true,
    foto: png(),
    ...extra,
  });
  const plaats = (extra) => bewoner.client.collection('hh_klussen').create(klus(extra));
  const ziet = async (h, k) => (await h.client.collection('hh_klussen').getList(1, 5, { filter: `id = "${k.id}"` })).totalItems === 1;
  const keur = (k, besluit = 'goedkeuren', reden = '') => route(coord.client, `/api/hh/klussen/${k.id}/keuren`, { besluit, reden });
  const meldingen = (k, soort) =>
    su.collection('hh_meldingen').getFullList({ filter: su.filter('klus = {:k} && soort = {:s}', { k: k.id, s: soort }) });

  // ---------------------------------------------------------------- C
  kop('C. Plaatsen door een bewoner');
  await magNiet('zonder foto: 400', () => plaats({ foto: undefined }), [400], /foto/i);
  await magNiet('zonder nee-lijst-vinkje: 400', () => plaats({ nee_lijst_akkoord: false }), [400], /vink/i);
  await magNiet('zonder omschrijving: 400', () => plaats({ omschrijving: '  ' }), [400], /woorden/i);
  await magNiet('omschrijving langer dan 300 tekens: 400', () => plaats({ omschrijving: 'x'.repeat(301) }), [400]);
  await magNiet('zonder begintijd: 400', () => plaats({ wanneer_van: '', wanneer_tot: '' }), [400], /wanneer/i);
  await magNiet('begintijd voorbij: 400', () => plaats({ wanneer_van: new Date(Date.now() - 3600e3).toISOString(), wanneer_tot: '' }), [400], /voorbij/i);
  await magNiet('eindtijd vóór begintijd: 400', () => plaats({ wanneer_tot: dag.om(13) }), [400], /eindtijd/i);
  await magNiet('zelf klus_goedgekeurd_op meesturen: geweigerd (rule)', () => plaats({ klus_goedgekeurd_op: nu() }));
  await magNiet('zelf min_leeftijd meesturen: geweigerd (rule)', () => plaats({ min_leeftijd: 10 }));
  await magNiet('zelf geboren_uiterlijk meesturen: geweigerd (rule)', () => plaats({ geboren_uiterlijk: '2020-01-01 00:00:00.000Z' }));
  const kTuin = await mag('compleet (Tuin, overmorgen 14:00-15:00, met foto): 200', () =>
    plaats({ omschrijving: `${MERK} Heg knippen. Bel 06-12345678 en neem een krat bier mee.` }));
  if (!kTuin) {
    console.log('\nZonder geplaatste klus kan de check niet verder.');
    process.exitCode = 1;
    await opruimen(su);
    return;
  }
  check('  begint ongekeurd (klus_goedgekeurd_op leeg)', !kTuin.klus_goedgekeurd_op, kTuin.klus_goedgekeurd_op);
  check('  min_leeftijd 13 (Tuin)', kTuin.min_leeftijd === 13, String(kTuin.min_leeftijd));
  check('  geboren_uiterlijk = overmorgen min 13 jaar', kTuin.geboren_uiterlijk === plaatsHulp.geborenUiterlijk(dag.om(14), 13), kTuin.geboren_uiterlijk);
  check('  markering telefoon + nee-lijst', JSON.stringify(kTuin.controle_markering) === JSON.stringify(['telefoon', 'neelijst']), JSON.stringify(kTuin.controle_markering));
  check('  één foto opgeslagen, vinkje bewaard', kTuin.foto?.length === 1 && kTuin.nee_lijst_akkoord === true);
  check('  de bewoner ziet zijn eigen ongekeurde klus', (await bewoner.client.collection('hh_klussen').getList(1, 5, { filter: `id = "${kTuin.id}"` })).totalItems === 1);
  await mag('een concept mag nog zonder foto (status concept)', () => plaats({ status: 'concept', foto: undefined, nee_lijst_akkoord: false }));
  check('  zonder eindtijd mag ook', !!(await mag('klus zonder eindtijd: 200', () => plaats({ klustype: boodschappen.id, wanneer_tot: '' }))));

  // ---------------------------------------------------------------- D
  kop('D. Ongekeurd: onzichtbaar voor helpers');
  check('helper van 25 ziet de ongekeurde klus NIET in de lijst', !(await ziet(h25, kTuin)));
  await magNiet('helper van 25 haalt hem ook niet los op (view)', () => h25.client.collection('hh_klussen').getOne(kTuin.id), [404]);
  let r = await route(h25.client, `/api/hh/klussen/${kTuin.id}/accepteren`);
  check(`accepteren kan niet (409 nietgekeurd, kreeg ${r.status} ${r.body?.reden})`, r.status === 409 && r.body?.reden === 'nietgekeurd');
  check('geen enkele melding "nieuwe klus" vóór de keuring', (await meldingen(kTuin, 'nieuwe_klus')).length === 0);

  // ---------------------------------------------------------------- E
  kop('E. Alleen de meldkamer keurt');
  r = await route(anonClient(), `/api/hh/klussen/${kTuin.id}/keuren`, { besluit: 'goedkeuren' });
  check(`anoniem 401 (kreeg ${r.status})`, r.status === 401);
  r = await route(bewoner.client, `/api/hh/klussen/${kTuin.id}/keuren`, { besluit: 'goedkeuren' });
  check(`bewoner 403 (kreeg ${r.status})`, r.status === 403 && r.body?.reden === 'rol');
  r = await route(h25.client, `/api/hh/klussen/${kTuin.id}/keuren`, { besluit: 'goedkeuren' });
  check(`helper 403 (kreeg ${r.status})`, r.status === 403);
  await magNiet('bewoner zet klus_goedgekeurd_op niet via een record-update', () =>
    bewoner.client.collection('hh_klussen').update(kTuin.id, { klus_goedgekeurd_op: nu() }), [400, 403, 404]);
  r = await keur(kTuin, 'misschien');
  check(`onbekend besluit 400 (kreeg ${r.status})`, r.status === 400 && r.body?.reden === 'besluit');
  r = await keur(kTuin, 'afkeuren', 'kort');
  check(`afkeuren zonder echte reden 400 (kreeg ${r.status})`, r.status === 400 && r.body?.reden === 'reden');
  r = await route(coord.client, '/api/hh/klussen/bestaatniet00000/keuren', { besluit: 'goedkeuren' });
  check(`onbekende klus 404 (kreeg ${r.status})`, r.status === 404);

  // ---------------------------------------------------------------- F
  kop('F. Goedkeuren: wie oud genoeg is ziet hem');
  r = await keur(kTuin);
  check(`coordinator keurt goed (kreeg ${r.status})`, r.status === 200 && r.body?.status === 'open', JSON.stringify(r.body));
  const naKeur = await su.collection('hh_klussen').getOne(kTuin.id);
  check('  klus_goedgekeurd_op gezet, _door = coordinator', !!naKeur.klus_goedgekeurd_op && naKeur.klus_goedgekeurd_door === coord.id);
  const logs = await su.collection('hh_klus_status').getFullList({ filter: su.filter('klus = {:k} && van = "open" && naar = "open"', { k: kTuin.id }) });
  check('  logregel open -> open "goedgekeurd door de meldkamer"', logs.length === 1 && /goedgekeurd/.test(logs[0].toelichting), JSON.stringify(logs.map((l) => l.toelichting)));
  r = await keur(kTuin);
  check(`  nog eens goedkeuren: 409 (kreeg ${r.status})`, r.status === 409 && r.body?.reden === 'algoedgekeurd');
  check('helper van 25 ziet de tuinklus', await ziet(h25, kTuin));
  check('helper van 14 ziet de tuinklus (13+)', await ziet(h14, kTuin));
  check('helper van 11 ziet de tuinklus NIET', !(await ziet(h11, kTuin)));
  await magNiet('helper van 11 haalt hem ook niet los op', () => h11.client.collection('hh_klussen').getOne(kTuin.id), [404]);
  r = await route(h11.client, `/api/hh/klussen/${kTuin.id}/accepteren`);
  check(`helper van 11 accepteert NIET (403 leeftijd, kreeg ${r.status} ${r.body?.reden})`, r.status === 403 && r.body?.reden === 'leeftijd' && /13 jaar/.test(r.body?.melding ?? ''), r.body?.melding);
  const nieuw = await meldingen(kTuin, 'nieuwe_klus');
  const aan = new Set(nieuw.map((m) => m.ontvanger));
  check('melding "nieuwe klus" voor de helpers van 14, 17 en 25', aan.has(h14.id) && aan.has(h17.id) && aan.has(h25.id), [...aan].join(','));
  check('GEEN melding "nieuwe klus" voor de helper van 11', !aan.has(h11.id));
  // Foto: protected. Alleen met een bestandstoken van wie de klus mag zien.
  const bestand = naKeur.foto?.[0];
  const haal = async (client) => {
    const token = client ? await client.files.getToken() : '';
    const url = su.files.getURL(naKeur, bestand, token ? { token } : {});
    return (await fetch(url)).status;
  };
  check(`foto: helper van 25 met token 200 (kreeg ${await haal(h25.client)})`, (await haal(h25.client)) === 200);
  check(`foto: bewoner met token 200`, (await haal(bewoner.client)) === 200);
  check(`foto: helper van 11 met eigen token NIET (kreeg ${await haal(h11.client)})`, (await haal(h11.client)) !== 200);
  check(`foto: zonder token NIET (kreeg ${await haal(null)})`, (await haal(null)) !== 200);

  // ---------------------------------------------------------------- G
  kop('G. Leeftijd per categorie en de tijdregel');
  const geval = async (label, extra, verwachtMin, zien) => {
    const k = await mag(`${label}: geplaatst`, () => plaats(extra));
    if (!k) return null;
    await keur(k);
    const opgeslagen = await su.collection('hh_klussen').getOne(k.id);
    check(`  min_leeftijd ${verwachtMin}`, opgeslagen.min_leeftijd === verwachtMin, String(opgeslagen.min_leeftijd));
    for (const [h, jaren] of [[h11, 11], [h14, 14], [h17, 17], [h25, 25]]) {
      const moet = zien.includes(jaren);
      check(`  helper van ${jaren} ${moet ? 'ziet hem' : 'ziet hem NIET'}`, (await ziet(h, k)) === moet);
    }
    return k;
  };
  await geval('Schoonmaak 10:00-11:00', { klustype: schoonmaak.id, wanneer_van: dag.om(10), wanneer_tot: dag.om(11) }, 16, [17, 25]);
  const kAvond = await geval('Boodschappen 20:00 zonder eindtijd', { klustype: boodschappen.id, wanneer_van: dag.om(20), wanneer_tot: '' }, 18, [25]);
  await geval('Boodschappen 06:30-07:30 (te vroeg)', { klustype: boodschappen.id, wanneer_van: dag.om(6, 30), wanneer_tot: dag.om(7, 30) }, 18, [25]);
  await geval('Boodschappen 13:00-16:00 (langer dan 2 uur)', { klustype: boodschappen.id, wanneer_van: dag.om(13), wanneer_tot: dag.om(16) }, 18, [25]);
  await geval('Boodschappen 17:30 zonder eindtijd', { klustype: boodschappen.id, wanneer_van: dag.om(17, 30), wanneer_tot: '' }, 18, [25]);
  await geval('Boodschappen 18:00-19:30 (eindigt na 19:00)', { klustype: boodschappen.id, wanneer_van: dag.om(18), wanneer_tot: dag.om(19, 30) }, 18, [25]);
  const kLicht = await geval('Boodschappen 16:30-18:00 (precies 18:00 klaar)', { klustype: boodschappen.id, wanneer_van: dag.om(16, 30), wanneer_tot: dag.om(18) }, 10, [11, 14, 17, 25]);
  // Antwoord Ibrahim 4 okt: 10 t/m 14 jaar om 18:00 klaar; 15-17 tot 19:00.
  const kNa18 = await geval('Boodschappen 17:30-18:30 (eindigt na 18:00)', { klustype: boodschappen.id, wanneer_van: dag.om(17, 30), wanneer_tot: dag.om(18, 30) }, 15, [17, 25]);
  await geval('Boodschappen 16:30 zonder eindtijd (na 16:00)', { klustype: boodschappen.id, wanneer_van: dag.om(16, 30), wanneer_tot: '' }, 15, [17, 25]);
  await geval('Boodschappen 16:00 zonder eindtijd', { klustype: boodschappen.id, wanneer_van: dag.om(16), wanneer_tot: '' }, 10, [11, 14, 17, 25]);
  if (kNa18) {
    r = await route(h14.client, `/api/hh/klussen/${kNa18.id}/accepteren`);
    check(`helper van 14 accepteert de klus tot 18:30 NIET (403 leeftijd, kreeg ${r.status})`, r.status === 403 && r.body?.reden === 'leeftijd' && /15 jaar/.test(r.body?.melding ?? ''), r.body?.melding);
    r = await route(h17.client, `/api/hh/klussen/${kNa18.id}/accepteren`);
    check(`helper van 17 accepteert de klus tot 18:30 wel (kreeg ${r.status})`, r.status === 200, JSON.stringify(r.body));
  }
  if (kAvond) {
    r = await route(h17.client, `/api/hh/klussen/${kAvond.id}/accepteren`);
    check(`helper van 17 accepteert de klus van 20:00 NIET (403 leeftijd, kreeg ${r.status})`, r.status === 403 && r.body?.reden === 'leeftijd' && /18 jaar/.test(r.body?.melding ?? ''), r.body?.melding);
  }
  if (kLicht) {
    r = await route(h11.client, `/api/hh/klussen/${kLicht.id}/accepteren`);
    check(`helper van 11 accepteert de lichte klus wel (kreeg ${r.status})`, r.status === 200, JSON.stringify(r.body));
  }
  r = await route(h25.client, `/api/hh/klussen/${kTuin.id}/accepteren`);
  check(`helper van 25 accepteert de tuinklus (kreeg ${r.status})`, r.status === 200, JSON.stringify(r.body));

  // ---------------------------------------------------------------- H
  kop('H. Wijzigen na goedkeuring');
  const kWijzig = await mag('nog een tuinklus, goedgekeurd', () => plaats());
  if (kWijzig) {
    await keur(kWijzig);
    check('  helper van 25 ziet hem', await ziet(h25, kWijzig));
    const gewijzigd = await mag('bewoner wijzigt de omschrijving', () =>
      bewoner.client.collection('hh_klussen').update(kWijzig.id, { omschrijving: `${MERK} Toch ook de dakgoot, mail a@b.nl` }));
    check('  goedkeuring vervalt', gewijzigd && !gewijzigd.klus_goedgekeurd_op, gewijzigd?.klus_goedgekeurd_op);
    check('  markering opnieuw (e-mail + nee-lijst)', JSON.stringify(gewijzigd?.controle_markering) === JSON.stringify(['email', 'neelijst']), JSON.stringify(gewijzigd?.controle_markering));
    check('  helper van 25 ziet hem niet meer', !(await ziet(h25, kWijzig)));
    const later = await mag('bewoner verschuift naar 20:00', () =>
      bewoner.client.collection('hh_klussen').update(kWijzig.id, { wanneer_van: dag.om(20), wanneer_tot: '' }));
    check('  min_leeftijd opnieuw: 18', later?.min_leeftijd === 18, String(later?.min_leeftijd));
    await keur(kWijzig);
    await mag('coordinator wijzigt de omschrijving', () =>
      coord.client.collection('hh_klussen').update(kWijzig.id, { omschrijving: `${MERK} Heg knippen.` }));
    const naCoord = await su.collection('hh_klussen').getOne(kWijzig.id);
    check('  goedkeuring blijft bij een wijziging door de coordinator', !!naCoord.klus_goedgekeurd_op);
  }

  // ---------------------------------------------------------------- I
  kop('I. Afkeuren');
  const kAf = await mag('een klus om af te keuren', () => plaats({ omschrijving: `${MERK} Sigaretten halen bij de tabakszaak.` }));
  if (kAf) {
    const reden = 'Sigaretten halen kan niet via HeitjeHulp.';
    r = await keur(kAf, 'afkeuren', reden);
    check(`coordinator keurt af (kreeg ${r.status})`, r.status === 200 && r.body?.status === 'geannuleerd', JSON.stringify(r.body));
    const af = await su.collection('hh_klussen').getOne(kAf.id);
    check('  status geannuleerd, reden en datum bewaard', af.status === 'geannuleerd' && af.klus_afkeur_reden === reden && !!af.klus_afgekeurd_op);
    const mb = (await su.collection('hh_meldingen').getFullList({ filter: su.filter('klus = {:k}', { k: kAf.id }) }));
    check('  de bewoner krijgt precies één melding', mb.length === 1 && mb[0].ontvanger === bewoner.id, `${mb.length}`);
    check('  "Je klus is afgekeurd" met de reden', mb[0]?.titel === 'Je klus is afgekeurd' && mb[0]?.tekst.includes(reden), `${mb[0]?.titel} / ${mb[0]?.tekst}`);
    r = await keur(kAf, 'afkeuren', reden);
    check(`  nog eens: 409 (kreeg ${r.status})`, r.status === 409 && r.body?.reden === 'status');
    check('  geen helper ziet hem', !(await ziet(h25, kAf)));
  }

  // ---------------------------------------------------------------- J
  kop('J. Telefonische ingang: de meldkamer plaatst namens een bewoner');
  const kTel = await mag('coordinator plaatst namens bewoner 2, zonder foto (bron telefoon)', () =>
    coord.client.collection('hh_klussen').create({
      hulpvrager: bewoner2.id, geplaatst_door: coord.id, bron: 'telefoon', status: 'open',
      klustype: boodschappen.id, omschrijving: `${MERK} Boodschappen, meneer belt de lijst door.`,
      adres: 'Teststraat 2, Tiel', lat: 51.88, lon: 5.42, wanneer_van: dag.om(10), wanneer_tot: dag.om(11),
    }));
  if (kTel) {
    check('  meteen goedgekeurd door de coordinator', !!kTel.klus_goedgekeurd_op && kTel.klus_goedgekeurd_door === coord.id);
    check('  helper van 11 ziet hem (Boodschappen 10+)', await ziet(h11, kTel));
  }

  // ---------------------------------------------------------------- K
  kop('K. Opruimen en nameten');
  await opruimen(su);
  const over = await su.collection('hh_users').getFullList({ filter: su.filter('email ~ {:p}', { p: MAIL_PREFIX }) });
  check('geen tijdelijke accounts meer', over.length === 0, `${over.length} over`);
  const klussenOver = await su.collection('hh_klussen').getFullList({ filter: su.filter('omschrijving ~ {:m}', { m: MERK }) });
  check('geen tijdelijke klussen meer', klussenOver.length === 0, `${klussenOver.length} over`);

  console.log(`\n${groen} groen, ${rood} rood.`);
  if (rood > 0) process.exitCode = 1;
}

main().catch(fail);
