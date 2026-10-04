// HeitjeHulp ADRES — bewijst de strengere adresregels en de adres-suggestie
// (120 + 123) op de ECHTE server. Werkt alleen met EIGEN tijdelijke accounts
// (e-mail "adrescheck-...@heitjehulp.invalid") en eigen klussen, en ruimt
// alles op. Er doen GEEN seed-accounts mee.
//
//   A. opruimen van een eerdere (gecrashte) run
//   B. voorwaarden (ook in dry-run, alleen lezen): velden van 120, de route
//      /api/hh/adres antwoordt (ongeldige invoer = 400, kost PDOK niets), de
//      regio-wijk bestaat
//   C. de route: ongeldige postcode/huisnummer/toevoeging -> 400; een bestaand
//      adres -> straat + plaats + punt + binnen_werkgebied; niet bestaand ->
//      "nietgevonden"; Amsterdam -> buiten
//   D. aanmelden (anoniem): zonder adres, postcode "4001", huisnummer "x",
//      niet bestaand en een onbekende toevoeging geweigerd; bestaand adres
//      geaccepteerd; vrije straat/plaats overschreven door PDOK; werkgebied uit
//      het PDOK-punt (Tiel, Ochten binnen; Amsterdam buiten); lat/lon of
//      adres_bron zelf meesturen geweigerd
//   E. bijwerken door de eigenaar: naam wijzigen zonder adres mag (oud account);
//      vrije straat zonder geldig adres geweigerd; plaats overschreven;
//      verhuizen naar buiten wist de wijk, terug geeft hem weer; lat zelf zetten
//      geweigerd
//   F. meldkamer: zonder adres geweigerd, met PDOK-adres, uitzondering
//      "handmatig" zonder PDOK (markering)
//   G. klus op het adres van de bewoner krijgt EXACT het PDOK-punt (geen
//      Nominatim). (Dat een bewoner van zijn helper geen punt/toevoeging ziet,
//      staat in VERBORGEN_VOOR_ANDEREN; getest in tests/hh_aanmelden_hulp.)
//   K. vaag vóór de match (antwoord Ibrahim 3): een helper ziet de open klus
//      ~200 m verschoven (stabiel), zonder adres, met afstand_m (echt punt,
//      afgerond op 100 m); filteren/sorteren op locatie (ook via meldingen en
//      realtime) geweigerd; meldkamer exact; na accepteren exact + adres.
//      Realtime alleen met node --experimental-eventsource.
//   H. PDOK-storing -> terugval (aanmelden gaat door, ongecontroleerd, werkgebied
//      via Nominatim). ALLEEN LOKAAL: met HH_NEP_PDOK_BEDIENING (de nep-PDOK
//      gaat even uit). Op prod: overgeslagen (PDOK is niet uit te zetten).
//   I. rate-limit: anoniem hooguit 60 opzoekingen per IP per uur, daarna 429;
//      de superuser heeft geen grens. Met ONGELDIGE postcodes: kost PDOK niets.
//      LET OP: daarna kan dit IP een uur lang anoniem geen adres opzoeken
//      (ingelogd nog wel). Niet twee keer binnen een uur draaien; niet tijdens
//      een aanmeld-proef vanaf hetzelfde netwerk.
//   J. opruimen en nameten
//
// PDOK-verzoeken op prod: hooguit 4 (Tiel, Ochten, Amsterdam, niet-bestaand);
// de server onthoudt elk antwoord 10 minuten. Nominatim: 0 (lokaal 1 in H).
//
// DRAAIEN (na 120 --apply en 123-hook-deploy.sh):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/122-adrescheck.mjs            (dry-run: alleen leescontroles)
//   node --experimental-eventsource scripts/122-adrescheck.mjs --apply
//   node scripts/122-adrescheck.mjs --apply --alleen-opruimen
//   node scripts/122-adrescheck.mjs --apply --zonder-limiet   (I overslaan)

import { randomBytes } from 'node:crypto';
import { superuserClient, userClient, anonClient, assertHh, APPLY, fail, PB_URL } from './_lib.mjs';
import { ADRES_VELDNAMEN } from './120-adres-velden.mjs';
import { REGIO_WIJK } from './81-b2-werkgebied.mjs';
import { TIEL, OCHTEN, AMSTERDAM, NIET_BESTAAND, invoer, zelfdePunt, afstandKm } from './_adressen.mjs';

const MAIL_PREFIX = 'adrescheck-';
const MAIL_DOMEIN = '@heitjehulp.invalid';
const MERK = '[adrescheck]';
const ALLEEN_OPRUIMEN = process.argv.includes('--alleen-opruimen');
const ZONDER_LIMIET = process.argv.includes('--zonder-limiet');
const BEDIENING = process.env.HH_NEP_PDOK_BEDIENING || '';
const MAX_ANONIEM = 60;

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
async function magNiet(label, fn, codes = [400]) {
  try {
    await fn();
    check(label, false, 'verzoek is onterecht gelukt');
    return null;
  } catch (e) {
    check(`${label} (${e?.status})`, codes.includes(e?.status), `status=${e?.status} ${e?.response?.message ?? ''}`);
    return e;
  }
}
/// GET /api/hh/adres; geeft { status, body } (ook bij 4xx).
async function zoek(client, q) {
  try {
    return { status: 200, body: await client.send('/api/hh/adres', { method: 'GET', query: q }) };
  } catch (e) {
    return { status: e?.status ?? 0, body: e?.response ?? {} };
  }
}
const geboren = (jaren) => {
  const d = new Date();
  d.setUTCFullYear(d.getUTCFullYear() - jaren);
  return `${d.toISOString().slice(0, 10)} 00:00:00.000Z`;
};

async function opruimen(su) {
  const tijdelijk = await su.collection('hh_users').getFullList({
    filter: su.filter('email ~ {:prefix}', { prefix: MAIL_PREFIX }),
  });
  let aantal = 0;
  for (const u of tijdelijk) {
    const klussen = await su.collection('hh_klussen').getFullList({
      filter: su.filter('hulpvrager = {:id} || geplaatst_door = {:id}', { id: u.id }),
    });
    for (const k of klussen) {
      for (const m of await su.collection('hh_meldingen').getFullList({ filter: su.filter('klus = {:id}', { id: k.id }) })) {
        await su.collection(assertHh('hh_meldingen')).delete(m.id);
        aantal++;
      }
      await su.collection(assertHh('hh_klussen')).delete(k.id); // logregels gaan mee (cascade)
      aantal++;
    }
    for (const m of await su.collection('hh_meldingen').getFullList({ filter: su.filter('ontvanger = {:id}', { id: u.id }) })) {
      await su.collection(assertHh('hh_meldingen')).delete(m.id);
      aantal++;
    }
    for (const r of await su.collection('hh_auditlog').getFullList({ filter: su.filter('door = {:id} || doel_id = {:id}', { id: u.id }) })) {
      await su.collection(assertHh('hh_auditlog')).delete(r.id);
      aantal++;
    }
  }
  for (const u of tijdelijk) await su.collection(assertHh('hh_users')).delete(u.id);
  aantal += tijdelijk.length;
  if (aantal) console.log(`  ↻ ${aantal} record(s) verwijderd (waarvan ${tijdelijk.length} tijdelijk(e) account(s))`);
}

async function voorwaarden(su) {
  kop('B. Voorwaarden op de server (alleen lezen)');
  const users = await su.collections.getOne('hh_users');
  const namen = new Set(users.fields.map((f) => f.name));
  for (const v of ADRES_VELDNAMEN) check(`hh_users.${v} bestaat`, namen.has(v), 'draai 120 --apply');
  const r = await zoek(su, { postcode: 'abc', huisnummer: '1' });
  check(`de route /api/hh/adres bestaat (ongeldige postcode -> 400 postcode, kreeg ${r.status} ${r.body?.reden})`, r.status === 400 && r.body?.reden === 'postcode', 'draai 123-hook-deploy.sh');
  const wijken = await su.collection('hh_wijken').getFullList({ filter: 'actief = true' });
  const regio = wijken.find((w) => w.gemeente === REGIO_WIJK.gemeente && w.wijk === REGIO_WIJK.wijk && w.regio === true);
  check(`wijk "${REGIO_WIJK.wijk}" bestaat (actief, regio)`, !!regio, 'draai 81 --apply');
  return { regio };
}

async function main() {
  for (const c of ['hh_users', 'hh_klussen', 'hh_meldingen', 'hh_auditlog']) assertHh(c);
  const su = await superuserClient();
  console.log('Verbonden met', PB_URL, APPLY ? '(APPLY)' : '(DRY-RUN)', '\n');

  if (!APPLY) {
    console.log('DRY-RUN: er wordt NIETS geschreven (ook geen PDOK-verzoek).');
    await voorwaarden(su);
    console.log('\nWat --apply ZOU doen:');
    console.log(`  · tijdelijke accounts (${MAIL_PREFIX}...${MAIL_DOMEIN}): coordinator, ~6 bewoners, ~3 helpers;`);
    console.log('  · hooguit 4 PDOK-verzoeken (Tiel, Ochten, Amsterdam, niet-bestaand), 10 minuten onthouden;');
    console.log('  · een klus op het adres van een bewoner (punt = PDOK-punt, geen Nominatim);');
    console.log('  · twee tijdelijke helpers (goedgekeurd, VOG): vaag vóór de match, filters dicht, één accepteert de klus;');
    console.log(`  · rate-limit: tot ${MAX_ANONIEM + 1} anonieme opzoekingen met een ONGELDIGE postcode (dit IP daarna een uur geen anonieme opzoekingen);`);
    console.log('  · PDOK-storing alleen lokaal (HH_NEP_PDOK_BEDIENING); op prod overgeslagen;');
    console.log('  · alles opruimen en nameten.');
    console.log(`\n${groen} groen, ${rood} rood (leescontroles).`);
    if (rood > 0) console.log('Rood is verwacht zolang 120 en 123 nog niet uitgerold zijn.');
    return;
  }

  kop('A. Opruimen van een eerdere run');
  await opruimen(su);
  if (ALLEEN_OPRUIMEN) {
    console.log('\nAlleen opgeruimd.');
    return;
  }
  const { regio } = await voorwaarden(su);
  if (!regio) {
    console.log('\nZonder de regio-wijk kan de check niet verder.');
    process.exitCode = 1;
    return;
  }

  const wachtwoord = randomBytes(18).toString('base64url');
  const nieuwMail = (label) => `${MAIL_PREFIX}${label}-${randomBytes(4).toString('hex')}${MAIL_DOMEIN}`;
  const anon = anonClient();
  async function account(label, rol, extra = {}) {
    const email = nieuwMail(label);
    const record = await su.collection(assertHh('hh_users')).create({
      email, password: wachtwoord, passwordConfirm: wachtwoord, verified: true, rol, naam: `${MERK} ${label}`, taal: 'nl', ...extra,
    });
    return { id: record.id, record, email, client: await userClient(email, wachtwoord) };
  }
  const registreer = (label, extra) =>
    anon.collection('hh_users').create({
      email: nieuwMail(label), password: wachtwoord, passwordConfirm: wachtwoord, taal: 'nl', naam: `${MERK} ${label}`, ...extra,
    });
  const bewoner = (label, extra) => registreer(label, { rol: 'hulpvrager', ...extra });

  // ---------------------------------------------------------------- C
  kop('C. De route GET /api/hh/adres');
  let r = await zoek(anon, { postcode: '4001', huisnummer: '1' });
  check(`postcode zonder letters -> 400 postcode (kreeg ${r.status} ${r.body?.reden})`, r.status === 400 && r.body?.reden === 'postcode');
  r = await zoek(anon, { postcode: '0401 MA', huisnummer: '1' });
  check(`postcode met 0 vooraan -> 400 postcode (kreeg ${r.status})`, r.status === 400 && r.body?.reden === 'postcode');
  r = await zoek(anon, { postcode: TIEL.postcode, huisnummer: '1a' });
  check(`huisnummer met letter -> 400 huisnummer (kreeg ${r.status} ${r.body?.reden})`, r.status === 400 && r.body?.reden === 'huisnummer');
  r = await zoek(anon, { postcode: TIEL.postcode, huisnummer: '1', toevoeging: 'abcdefgh' });
  check(`toevoeging van 8 tekens -> 400 toevoeging (kreeg ${r.status})`, r.status === 400 && r.body?.reden === 'toevoeging');
  r = await zoek(anon, { postcode: TIEL.postcode.replace(' ', '').toLowerCase(), huisnummer: TIEL.huisnummer });
  const t = r.body?.adressen?.[0];
  check(`bestaand adres (4001ma 1) -> gevonden (kreeg ${r.status} ${r.body?.gevonden})`, r.status === 200 && r.body?.gevonden === true, JSON.stringify(r.body));
  check(`  "${t?.weergave}"`, t?.adres === TIEL.adres && t?.plaats === TIEL.plaats && t?.postcode === TIEL.postcode, JSON.stringify(t));
  check('  punt = PDOK-punt, binnen het werkgebied', zelfdePunt(t, TIEL) && t?.binnen_werkgebied === true, JSON.stringify(t));
  r = await zoek(anon, NIET_BESTAAND);
  check(`niet bestaand -> gevonden=false, reden nietgevonden (kreeg ${r.status} ${r.body?.reden})`, r.status === 200 && r.body?.gevonden === false && r.body?.reden === 'nietgevonden');
  check('  met de rustige melding', r.body?.melding === 'We vinden dit adres niet. Klopt de postcode en het huisnummer?', r.body?.melding);
  r = await zoek(anon, invoer(AMSTERDAM));
  check(`Amsterdam -> gevonden, binnen_werkgebied = nee (kreeg ${r.body?.adressen?.[0]?.binnen_werkgebied})`, r.body?.gevonden === true && r.body?.adressen?.[0]?.binnen_werkgebied === false);

  // ---------------------------------------------------------------- D
  kop('D. Aanmelden: alleen een bestaand adres');
  await magNiet('bewoner zonder postcode en huisnummer geweigerd', () => bewoner('zonder', {}));
  await magNiet('bewoner met postcode "4001" (zonder letters) geweigerd', () => bewoner('vier', { postcode: '4001', huisnummer: '1' }));
  await magNiet('bewoner met huisnummer "x" geweigerd', () => bewoner('x', { postcode: TIEL.postcode, huisnummer: 'x' }));
  const niet = await magNiet('bewoner op een adres dat niet bestaat geweigerd', () => bewoner('niet', NIET_BESTAAND));
  check('  melding "We vinden dit adres niet..."', /We vinden dit adres niet/.test(niet?.response?.message ?? ''), niet?.response?.message);
  await magNiet('helper met een onbekende toevoeging (1a, oude app) geweigerd', () =>
    registreer('toev', { rol: 'jongere', geboortedatum: geboren(20), postcode: TIEL.postcode, huisnummer: '1a' }));
  await magNiet('registreren met lat/lon geweigerd', () => bewoner('lat', { ...invoer(TIEL), lat: 52, lon: 5 }));
  await magNiet('registreren met adres_bron geweigerd', () => bewoner('bron', { ...invoer(TIEL), adres_bron: 'pdok' }));

  const b1 = await mag('bewoner op Kerkstraat 1, 4001 MA Tiel (met vrije straat/plaats)', () =>
    bewoner('tiel', { ...invoer(TIEL), postcode: '4001ma', adres: 'Verzonnenstraat 99', plaats: 'Nergenshuizen' }));
  check('  straat en plaats komen van PDOK (vrije invoer overschreven)', b1?.adres === TIEL.adres && b1?.plaats === TIEL.plaats, `${b1?.adres} / ${b1?.plaats}`);
  check('  postcode als "4001 MA", huisnummer "1", adres_bron pdok', b1?.postcode === TIEL.postcode && b1?.huisnummer === '1' && b1?.adres_bron === 'pdok', `${b1?.postcode} ${b1?.huisnummer} ${b1?.adres_bron}`);
  check('  punt = PDOK-punt', zelfdePunt(b1, TIEL), `${b1?.lat}, ${b1?.lon}`);
  check('  werkgebied uit het PDOK-punt: "Tiel en omstreken", binnen', b1?.wijk === regio.id && b1?.werkgebied_status === 'binnen', `${b1?.wijk} ${b1?.werkgebied_status}`);
  const h1 = await mag('helper (20) in Ochten (dorp binnen 20 km)', () =>
    registreer('ochten', { rol: 'jongere', geboortedatum: geboren(20), ...invoer(OCHTEN) }));
  check('  Ochten: binnen, regio-wijk, straat van PDOK', h1?.werkgebied_status === 'binnen' && h1?.wijk === regio.id && h1?.adres === OCHTEN.adres, `${h1?.werkgebied_status} ${h1?.adres}`);
  const ver = await mag('bewoner in Amsterdam mag zich aanmelden', () => bewoner('amsterdam', invoer(AMSTERDAM)));
  check('  buiten: geen wijk, status buiten', ver && !ver.wijk && ver.werkgebied_status === 'buiten', `${ver?.wijk} ${ver?.werkgebied_status}`);

  // ---------------------------------------------------------------- E
  kop('E. Bijwerken door de eigenaar');
  const oud = await account('oud', 'hulpvrager', { postcode: '4001', plaats: 'Tiel', adres: 'Kerkstraat', wijk: regio.id });
  await mag('oud account (postcode "4001", geen huisnummer) wijzigt alleen zijn naam', () =>
    oud.client.collection('hh_users').update(oud.id, { naam: `${MERK} oud nieuw` }));
  await magNiet('oud account wijzigt zijn straat zonder geldig adres: geweigerd', () =>
    oud.client.collection('hh_users').update(oud.id, { adres: 'Kerkstraat 1' }));
  const aangevuld = await mag('oud account vult zijn adres aan (postcode + huisnummer)', () =>
    oud.client.collection('hh_users').update(oud.id, invoer(TIEL)));
  check('  nu pdok met punt en straat', aangevuld?.adres_bron === 'pdok' && aangevuld?.adres === TIEL.adres && zelfdePunt(aangevuld, TIEL));

  const eigenaar = await account('eigenaar', 'hulpvrager', invoer(TIEL));
  check('superuser-aanmaak met postcode + huisnummer gaat ook via PDOK', eigenaar.record.adres_bron === 'pdok' && eigenaar.record.adres === TIEL.adres);
  const eig = eigenaar.client;
  const b1id = eigenaar.id;
  const pl = await mag('eigenaar wijzigt alleen zijn plaats in "Ergens"', () => eig.collection('hh_users').update(b1id, { plaats: 'Ergens' }));
  check('  plaats blijft die van PDOK', pl?.plaats === TIEL.plaats, pl?.plaats);
  await magNiet('eigenaar zet zelf lat/lon', () => eig.collection('hh_users').update(b1id, { lat: 50, lon: 4 }));
  await magNiet('eigenaar zet zelf adres_bron', () => eig.collection('hh_users').update(b1id, { adres_bron: 'handmatig' }));
  await magNiet('eigenaar verhuist naar een adres dat niet bestaat', () => eig.collection('hh_users').update(b1id, NIET_BESTAAND));
  const naNiet = await su.collection('hh_users').getOne(b1id);
  check('  er is niets veranderd', naNiet.adres === TIEL.adres && naNiet.huisnummer === '1' && naNiet.wijk === regio.id);
  const weg = await mag('eigenaar verhuist naar Amsterdam', () => eig.collection('hh_users').update(b1id, invoer(AMSTERDAM)));
  check('  wijk gewist, status buiten, punt Amsterdam', weg && !weg.wijk && weg.werkgebied_status === 'buiten' && zelfdePunt(weg, AMSTERDAM));
  const terug = await mag('eigenaar verhuist terug naar Tiel', () => eig.collection('hh_users').update(b1id, invoer(TIEL)));
  check('  weer "Tiel en omstreken", punt Tiel', terug?.wijk === regio.id && terug?.werkgebied_status === 'binnen' && zelfdePunt(terug, TIEL));

  // ---------------------------------------------------------------- F
  kop('F. Telefonische aanmelding door de meldkamer');
  const coord = await account('coordinator', 'coordinator');
  const telBasis = (label) => ({
    email: nieuwMail(label), password: wachtwoord, passwordConfirm: wachtwoord, rol: 'hulpvrager', naam: `${MERK} ${label}`, taal: 'nl',
  });
  await magNiet('meldkamer maakt een bewoner zonder adres: geweigerd', () =>
    coord.client.collection('hh_users').create({ ...telBasis('tel-leeg'), wijk: regio.id }));
  const telPdok = await mag('meldkamer maakt een bewoner op een PDOK-adres', () =>
    coord.client.collection('hh_users').create({ ...telBasis('tel-pdok'), ...invoer(TIEL) }));
  check('  pdok, straat van PDOK, binnen', telPdok?.adres_bron === 'pdok' && telPdok?.adres === TIEL.adres && telPdok?.wijk === regio.id);
  const telHand = await mag('meldkamer maakt een bewoner met adres_bron "handmatig" (uitzondering, zonder PDOK)', () =>
    coord.client.collection('hh_users').create({ ...telBasis('tel-hand'), adres: 'Woonwagenkamp 1', plaats: 'Tiel', adres_bron: 'handmatig', wijk: regio.id }));
  check('  markering handmatig, adres zoals getypt, geen punt, de gekozen wijk', telHand?.adres_bron === 'handmatig' && telHand?.adres === 'Woonwagenkamp 1' && !Number(telHand?.lat) && telHand?.wijk === regio.id);

  // ---------------------------------------------------------------- G
  kop('G. Klus op het adres van de bewoner: exact het PDOK-punt');
  const klustype = (await su.collection('hh_klustypes').getList(1, 1, { filter: 'actief = true' })).items[0]
    ?? (await su.collection('hh_klustypes').getList(1, 1)).items[0];
  const klus = await mag('meldkamer plaatst een klus op "Kerkstraat 1, 4001 MA Tiel" zonder lat/lon', () =>
    coord.client.collection('hh_klussen').create({
      hulpvrager: telPdok.id, geplaatst_door: coord.id, klustype: klustype.id, omschrijving: `${MERK} klus op het eigen adres`,
      adres: `${TIEL.adres}, ${TIEL.postcode} ${TIEL.plaats}`, wanneer_van: new Date(Date.now() + 86400000).toISOString(),
      status: 'open', bron: 'telefoon', bedrag_bruto: 0, vergoeding_jongere: 0, commissie: 0,
    }));
  check('  klus.lat/lon = het PDOK-punt van de bewoner', zelfdePunt(klus, TIEL), `${klus?.lat}, ${klus?.lon}`);


  // ---------------------------------------------------------------- K
  kop('K. Vaag vóór de match: helper ziet ~200 m verschoven, geen adres, afstand afgerond');
  const helperVaag = await account('helper-vaag', 'jongere', { geboortedatum: geboren(25), ...invoer(OCHTEN) });
  const helperAnder = await account('helper-ander', 'jongere', { geboortedatum: geboren(25), ...invoer(TIEL) });
  for (const h of [helperVaag, helperAnder]) {
    await su.collection(assertHh('hh_profielen')).create({ gebruiker: h.id, verificatiestatus: 'goedgekeurd', vog_gezien_op: new Date().toISOString().replace('T', ' ') });
  }
  check('helper heeft een PDOK-punt (Ochten) en de regio-wijk', helperVaag.record.adres_bron === 'pdok' && helperVaag.record.wijk === regio.id);
  const zichtbaar = async (h) => (await h.client.collection('hh_klussen').getList(1, 5, { filter: `id = "${klus?.id}"` })).items[0];
  const v1 = klus ? await zichtbaar(helperVaag) : null;
  check('helper ziet de open (telefonisch goedgekeurde) klus', !!v1);
  if (v1) {
    const d = afstandKm(v1, TIEL);
    check(`  punt verschoven: ${Math.round(d * 1000)} m van het echte punt (150-250)`, d > 0.15 && d < 0.25);
    check('  geen adres in het antwoord', !('adres' in v1) || !v1.adres, JSON.stringify(v1.adres));
    check('  locatie_vaag = ja', v1.locatie_vaag === true);
    const verwacht = Math.max(100, Math.round((afstandKm(OCHTEN, TIEL) * 1000) / 100) * 100);
    check(`  afstand_m = echte afstand afgerond op 100 m (${v1.afstand_m} = ${verwacht})`, v1.afstand_m === verwacht);
    const v2 = await zichtbaar(helperVaag);
    check('  stabiel: opnieuw opvragen geeft hetzelfde punt', v2?.lat === v1.lat && v2?.lon === v1.lon);
    const los = await helperVaag.client.collection('hh_klussen').getOne(klus.id);
    check('  ook los opgevraagd (view) vaag', los.lat === v1.lat && !los.adres);
  }
  const coordZiet = klus ? await coord.client.collection('hh_klussen').getOne(klus.id) : null;
  check('meldkamer ziet het exacte punt en het adres', zelfdePunt(coordZiet, TIEL) && !!coordZiet?.adres);
  for (const [label, q] of [
    ['filter op lat', { filter: 'lat > 51' }],
    ['sorteren op lat', { sort: '-lat' }],
    ['filter op adres', { filter: 'adres ~ "Kerk"' }],
    ['filter op hulpvrager.postcode', { filter: 'hulpvrager.postcode = "4001 MA"' }],
  ]) {
    await magNiet(`helper: ${label} geweigerd`, () => helperVaag.client.collection('hh_klussen').getList(1, 5, q));
  }
  await magNiet('helper: filter op klus.lat via meldingen geweigerd', () => helperVaag.client.collection('hh_meldingen').getList(1, 5, { filter: 'klus.lat > 51' }));
  await mag('helper: gewoon filteren (status) mag', () => helperVaag.client.collection('hh_klussen').getList(1, 5, { filter: 'status = "open"' }));
  if (typeof EventSource !== 'undefined' && klus) {
    const ontvangen = { coord: null, helper: null };
    const stopC = await coord.client.collection('hh_klussen').subscribe(klus.id, (ev) => { ontvangen.coord = ev.record; });
    const stopH = await helperAnder.client.collection('hh_klussen').subscribe(klus.id, (ev) => { ontvangen.helper = ev.record; });
    await su.collection(assertHh('hh_klussen')).update(klus.id, { omschrijving: `${MERK} klus op het eigen adres (realtime)` });
    for (let i = 0; i < 30 && (!ontvangen.coord || !ontvangen.helper); i++) await new Promise((r) => setTimeout(r, 100));
    check('realtime: meldkamer krijgt het exacte punt', zelfdePunt(ontvangen.coord, TIEL), JSON.stringify(ontvangen.coord?.lat));
    check('realtime: helper krijgt het vage punt, geen adres', !!ontvangen.helper && !zelfdePunt(ontvangen.helper, TIEL) && !ontvangen.helper.adres);
    await stopC();
    await stopH();
  } else {
    overgeslagen++;
    console.log('  ~ realtime overgeslagen (draai met node --experimental-eventsource)');
  }
  await magNiet('realtime: helper abonneert met een filter op lat: geweigerd', () =>
    helperVaag.client.collection('hh_klussen').subscribe('*', () => {}, { filter: 'lat > 51' }));
  const acc = klus ? await helperVaag.client.send(`/api/hh/klussen/${klus.id}/accepteren`, { method: 'POST' }).then(() => 200, (e) => e?.status) : 0;
  check(`helper accepteert de klus (kreeg ${acc})`, acc === 200);
  const na = klus ? await helperVaag.client.collection('hh_klussen').getOne(klus.id) : null;
  check('na de match: exact punt en adres', zelfdePunt(na, TIEL) && !!na?.adres && na?.locatie_vaag !== true, JSON.stringify({ lat: na?.lat, adres: na?.adres }));
  const ander = klus ? await zichtbaar(helperAnder).catch(() => null) : null;
  check('een andere helper ziet hem niet meer (niet meer open)', !ander);

  // ---------------------------------------------------------------- H
  kop('H. PDOK-storing -> terugval');
  if (!BEDIENING) {
    overgeslagen++;
    console.log('  ~ overgeslagen: alleen lokaal te bewijzen (HH_NEP_PDOK_BEDIENING). PDOK is op prod niet uit te zetten.');
  } else {
    await fetch(`${BEDIENING}?storing=1`);
    try {
      r = await zoek(anon, { postcode: TIEL.postcode, huisnummer: '3' });
      check(`route: reden dienst (kreeg ${r.status} ${r.body?.reden})`, r.status === 200 && r.body?.gevonden === false && r.body?.reden === 'dienst');
      const tv = await mag('aanmelden gaat door tijdens de storing', () => bewoner('storing', { postcode: '4001ma', huisnummer: '3', toevoeging: 'b' }));
      check('  adres_bron ongecontroleerd, postcode/nummer netjes, geen punt', tv?.adres_bron === 'ongecontroleerd' && tv?.postcode === '4001 MA' && tv?.huisnummer === '3' && tv?.toevoeging === 'b' && !Number(tv?.lat));
      check('  werkgebied via de terugval (Nominatim op postcode): binnen', tv?.werkgebied_status === 'binnen' && tv?.wijk === regio.id, `${tv?.werkgebied_status}`);
    } finally {
      await fetch(`${BEDIENING}?storing=0`);
    }
  }

  // ---------------------------------------------------------------- I
  kop('I. Rate-limit per IP');
  if (ZONDER_LIMIET) {
    overgeslagen++;
    console.log('  ~ overgeslagen (--zonder-limiet)');
  } else {
    let eerste429 = 0;
    let na429Weer200 = false;
    for (let i = 1; i <= MAX_ANONIEM + 1; i++) {
      const x = await zoek(anon, { postcode: 'xx', huisnummer: '1' });
      if (x.status === 429 && !eerste429) eerste429 = i;
      if (eerste429 && x.status !== 429) na429Weer200 = true;
    }
    check(`na hooguit ${MAX_ANONIEM} anonieme opzoekingen komt 429 (bij nummer ${eerste429} van deze reeks)`, eerste429 > 0 && eerste429 <= MAX_ANONIEM + 1);
    check('  daarna blijft het 429', !na429Weer200);
    r = await zoek(anon, { postcode: 'xx', huisnummer: '1' });
    check(`  reden limiet (kreeg ${r.status} ${r.body?.reden})`, r.status === 429 && r.body?.reden === 'limiet');
    r = await zoek(su, { postcode: 'xx', huisnummer: '1' });
    check(`superuser heeft geen grens (400 i.p.v. 429, kreeg ${r.status})`, r.status === 400);
  }

  // ---------------------------------------------------------------- J
  kop('J. Opruimen en nameten');
  await opruimen(su);
  const over = await su.collection('hh_users').getFullList({ filter: su.filter('email ~ {:p}', { p: MAIL_PREFIX }) });
  check('geen tijdelijke accounts meer', over.length === 0, `${over.length} over`);

  console.log(`\n${groen} groen, ${rood} rood${overgeslagen ? `, ${overgeslagen} overgeslagen` : ''}.`);
  if (rood > 0) process.exitCode = 1;
}

main().catch(fail);
