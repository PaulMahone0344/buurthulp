// HeitjeHulp B6 — bewijst de chat (110, 111, 113) op de ECHTE server. Werkt
// alleen met EIGEN tijdelijke accounts ("b6check-...@heitjehulp.invalid") en
// eigen klussen ("[b6check]"), en ruimt alles op. Seed-accounts schrijven
// NIETS; één afgelopen seed-klus wordt alleen gebruikt om te bewijzen dat
// schrijven na 72 uur geweigerd wordt (een verzoek dat moet mislukken).
//
//   A. opruimen van een eerdere (gecrashte) run
//   B. voorwaarden (ook in dry-run, alleen lezen): hh_berichten met de
//      velden van 110, de rules van 111 letterlijk, "bericht" in
//      hh_meldingen.soort
//   C. de twee partijen: bewoner en helper schrijven (tekst en snelknop) en
//      lezen elkaars berichten; helper staat op de klus-helper
//   D. derden lezen en schrijven niets: vreemde bewoner, vreemde helper,
//      andere helper, anoniem, coordinator ZONDER incident; de coordinator
//      schrijft ook niet
//   E. coordinator-inzage: pas als er een incident op de klus is
//   F. vervalsen kan niet: afzender = een ander, helper/gelezen_op/
//      gefilterd/contactverzoek meesturen, andermans tekst wijzigen, eigen
//      bericht "gelezen" zetten, verwijderen; de ontvanger zet alleen
//      gelezen_op (de tekst blijft)
//   G. filter: nummer, mailadres en link worden "•••", gefilterd = ja,
//      contactverzoek alleen zichtbaar voor de coordinator
//   H. meldingen: één melding "bericht" bij de ontvanger, niet bij de
//      afzender, en hooguit één per 10 minuten per chat
//   I. open/dicht: klus zonder helper dicht; afgerond (net) nog open; een
//      afgelopen klus van > 72 uur geleden: 403 "Deze chat is gesloten."
//      (bewoner en helper, via impersonate; er wordt niets geschreven)
//   J. wissel van helper: de oude helper leest niets meer, de nieuwe leest
//      het oude gesprek niet; de bewoner ziet alles
//   K. realtime: de bewoner krijgt het bericht van de helper binnen 5 s, een
//      vreemde en de coordinator (zonder incident) krijgen niets
//      (draai met node --experimental-eventsource; anders overgeslagen)
//   L. opruimen en nameten
//
// DRAAIEN (na 110 --apply, 111 --apply en 113-hook-deploy.sh):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/112-b6check.mjs                                        (dry-run)
//   node --experimental-eventsource scripts/112-b6check.mjs --apply
//   node scripts/112-b6check.mjs --apply --alleen-opruimen

import { randomBytes } from 'node:crypto';
import { superuserClient, userClient, anonClient, assertHh, APPLY, fail, PB_URL } from './_lib.mjs';
import { COLLECTIE, berichtVelden, MELDING_SOORT_BERICHT } from './110-b6-berichten.mjs';
import { BERICHTEN_RULES } from './111-b6-rules.mjs';

const MAIL_PREFIX = 'b6check-';
const MAIL_DOMEIN = '@heitjehulp.invalid';
const MERK = '[b6check]';
const ALLEEN_OPRUIMEN = process.argv.includes('--alleen-opruimen');
const WEIGER = [400, 403, 404];
const VERVANGING = '•••';
const DICHT_NA_MS = 72 * 3600 * 1000;

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
const slaOver = (t) => {
  overgeslagen++;
  console.log(`  - overgeslagen: ${t}`);
};
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
async function magNiet(label, fn, codes = WEIGER) {
  try {
    const r = await fn();
    check(label, false, 'verzoek is onterecht gelukt');
    return r ?? {};
  } catch (e) {
    check(`${label} (${e?.status})`, codes.includes(e?.status), `status=${e?.status} ${e?.response?.message ?? ''}`);
    return null;
  }
}
const wacht = (ms) => new Promise((r) => setTimeout(r, ms));
const lijst = (client, klusId) =>
  client.collection(COLLECTIE).getFullList({ filter: client.filter('klus = {:k}', { k: klusId }), sort: 'created' });

// --------------------------------------------------------------------------
// A en L: opruimen
// --------------------------------------------------------------------------
async function opruimen(su) {
  const weg = async (col, filter, params) => {
    const rijen = await su.collection(col).getFullList({ filter: su.filter(filter, params) });
    for (const r of rijen) await su.collection(assertHh(col)).delete(r.id);
    return rijen.length;
  };
  const tijdelijk = await su.collection('hh_users').getFullList({
    filter: su.filter('email ~ {:prefix}', { prefix: MAIL_PREFIX }),
  });
  let aantal = 0;
  // Klussen eerst: berichten en logregels gaan mee (cascade).
  const klussen = await su.collection('hh_klussen').getFullList({
    filter: su.filter('omschrijving ~ {:merk}', { merk: MERK }),
  });
  for (const k of klussen) {
    aantal += await weg('hh_meldingen', 'klus = {:id}', { id: k.id });
    aantal += await weg('hh_incidenten', 'klus = {:id}', { id: k.id });
    await su.collection(assertHh('hh_klussen')).delete(k.id);
    aantal++;
  }
  for (const u of tijdelijk) {
    aantal += await weg('hh_meldingen', 'ontvanger = {:id}', { id: u.id });
    aantal += await weg('hh_incidenten', 'melder = {:id}', { id: u.id });
    aantal += await weg(COLLECTIE, 'afzender = {:id}', { id: u.id });
    aantal += await weg('hh_profielen', 'gebruiker = {:id}', { id: u.id });
    aantal += await weg('hh_auditlog', 'door = {:id} || doel_id = {:id}', { id: u.id });
  }
  for (const u of tijdelijk) await su.collection(assertHh('hh_users')).delete(u.id);
  aantal += tijdelijk.length;
  if (aantal) console.log(`  ↻ ${aantal} record(s) verwijderd (waarvan ${tijdelijk.length} tijdelijk(e) account(s))`);
  return aantal;
}

// --------------------------------------------------------------------------
// B: voorwaarden (alleen lezen)
// --------------------------------------------------------------------------
async function voorwaarden(su) {
  kop('B. Voorwaarden op de server (alleen lezen)');
  let col = null;
  try {
    col = await su.collections.getOne(COLLECTIE);
  } catch (_) {
    col = null;
  }
  check(`${COLLECTIE} bestaat`, !!col, 'draai 110 --apply');
  if (col) {
    const namen = new Set(col.fields.map((f) => f.name));
    const mist = berichtVelden({ hh_users: '', hh_klussen: '' }).filter((f) => !namen.has(f.name)).map((f) => f.name);
    check(`${COLLECTIE} heeft alle velden van 110`, !mist.length, `mist: ${mist.join(', ')}`);
    for (const [k, v] of Object.entries(BERICHTEN_RULES)) {
      check(`${COLLECTIE}.${k} is gelijk aan 111`, (col[k] ?? null) === v, 'draai 111 --apply');
    }
  }
  const meld = await su.collections.getOne('hh_meldingen');
  const soort = meld.fields.find((f) => f.name === 'soort');
  check(`hh_meldingen.soort kent "${MELDING_SOORT_BERICHT}"`, !!soort?.values?.includes(MELDING_SOORT_BERICHT), 'draai 110 --apply');
  return !!col;
}

/// Een afgelopen klus (afgerond of geannuleerd, met helper) van langer dan
/// 72 uur geleden. Voorkeur: seed-klussen ("[seed"), anders niets (we
/// gebruiken nooit de klus van een echte gebruiker).
async function oudeKlus(su) {
  const kandidaten = await su.collection('hh_klussen').getFullList({
    filter: '(status = "afgerond" || status = "geannuleerd") && toegewezen_jongere != "" && omschrijving ~ "[seed"',
    sort: 'created',
  });
  const nu = Date.now();
  for (const k of kandidaten) {
    const regels = await su.collection('hh_klus_status').getList(1, 1, {
      filter: su.filter('klus = {:k} && naar = {:n}', { k: k.id, n: k.status }),
      sort: '-created',
    });
    const moment = Date.parse(String(regels.items[0]?.created ?? k.updated).replace(' ', 'T'));
    if (isFinite(moment) && nu - moment > DICHT_NA_MS + 3600 * 1000) return k;
  }
  return null;
}

/// Een client als deze gebruiker (superuser-impersonate, 10 minuten geldig).
/// Er wordt geen wachtwoord gebruikt en niets aan het account gewijzigd.
async function alsGebruiker(su, id) {
  const client = await su.collection('hh_users').impersonate(id, 600);
  client.autoCancellation(false);
  return client;
}

// --------------------------------------------------------------------------
// main
// --------------------------------------------------------------------------
async function main() {
  for (const c of ['hh_users', 'hh_klussen', 'hh_meldingen', 'hh_incidenten', COLLECTIE]) assertHh(c);
  const su = await superuserClient();
  console.log('Verbonden met', PB_URL, APPLY ? '(APPLY)' : '(DRY-RUN)', '\n');

  if (!APPLY) {
    console.log('DRY-RUN: er wordt NIETS geschreven.');
    await voorwaarden(su);
    const oud = await oudeKlus(su).catch(() => null);
    console.log(`\nAfgelopen seed-klus van > 72 uur voor sectie I: ${oud ? `${oud.id} (${oud.status})` : 'geen gevonden (I wordt dan deels overgeslagen)'}`);
    console.log('\nWat --apply ZOU doen:');
    console.log(`  · tijdelijke accounts maken (${MAIL_PREFIX}...${MAIL_DOMEIN}): coordinator, 2 bewoners, 3 helpers;`);
    console.log(`  · eigen klussen "${MERK}" (geaccepteerd, open, afgerond) en berichten daarin; één incident (meldt de coordinatoren kort, wordt opgeruimd);`);
    console.log('  · per rol nameten wie leest en schrijft, filter, meldingen, open/dicht, wissel van helper, realtime;');
    console.log('  · de oude seed-klus: een bericht proberen als bewoner en helper (impersonate) — moet 403 geven, niets geschreven;');
    console.log('  · alles opruimen en nameten.');
    console.log(`\n${groen} groen, ${rood} rood (leescontroles).`);
    if (rood > 0) console.log('Rood is verwacht zolang 110 en 111 nog niet uitgerold zijn.');
    return;
  }

  kop('A. Opruimen van een eerdere run');
  await opruimen(su);
  if (ALLEEN_OPRUIMEN) {
    console.log('\nAlleen opgeruimd.');
    return;
  }

  if (!(await voorwaarden(su))) {
    console.log('\nZonder hh_berichten kan de check niet verder.');
    process.exitCode = 1;
    return;
  }

  const wachtwoord = randomBytes(18).toString('base64url');
  const nieuwMail = (label) => `${MAIL_PREFIX}${label}-${randomBytes(4).toString('hex')}${MAIL_DOMEIN}`;
  async function account(label, rol, naam) {
    const email = nieuwMail(label);
    const extra = rol === 'jongere' ? { geboortedatum: '2000-01-01 00:00:00.000Z' } : {};
    const record = await su.collection(assertHh('hh_users')).create({
      email,
      password: wachtwoord,
      passwordConfirm: wachtwoord,
      rol,
      naam,
      taal: 'nl',
      ...extra,
    });
    const client = await userClient(email, wachtwoord);
    return { id: record.id, client };
  }
  async function klus(bewoner, helper, status) {
    return su.collection(assertHh('hh_klussen')).create({
      hulpvrager: bewoner.id,
      geplaatst_door: bewoner.id,
      bron: 'app',
      status,
      omschrijving: `${MERK} chat`,
      ...(helper ? { toegewezen_jongere: helper.id } : {}),
    });
  }
  const schrijf = (wie, klusId, tekst, extra = {}) =>
    wie.client.collection(COLLECTIE).create({ klus: klusId, afzender: wie.id, tekst, soort: 'tekst', ...extra });

  const c = await account('coordinator', 'coordinator', 'Check Coordinator');
  const b = await account('bewoner', 'hulpvrager', 'Bea Bewoner');
  const vb = await account('vreemde-bewoner', 'hulpvrager', 'Vera Vreemd');
  const h = await account('helper', 'jongere', 'Daan Helper');
  const h2 = await account('helper2', 'jongere', 'Sam Tweede');
  const vh = await account('vreemde-helper', 'jongere', 'Vic Vreemd');
  const anon = anonClient();

  // ---- C -------------------------------------------------------------------
  kop('C. De twee partijen schrijven en lezen');
  const k1 = await klus(b, h, 'geaccepteerd');
  const m1 = await mag('bewoner schrijft een bericht', () => schrijf(b, k1.id, 'Hoi Daan, de poort zit aan de zijkant.'));
  check('helper staat op het bericht (= toegewezen helper)', m1?.helper === h.id, `helper=${m1?.helper}`);
  check('gefilterd = nee bij een gewoon bericht', m1?.gefilterd === false);
  const m2 = await mag('helper stuurt een snelknop (soort snel)', () =>
    h.client.collection(COLLECTIE).create({ klus: k1.id, afzender: h.id, tekst: 'Ik ben onderweg', soort: 'snel' }),
  );
  check('snelknop wisselt de status NIET', (await su.collection('hh_klussen').getOne(k1.id)).status === 'geaccepteerd');
  check('bewoner leest 2 berichten', (await lijst(b.client, k1.id)).length === 2);
  check('helper leest 2 berichten', (await lijst(h.client, k1.id)).length === 2);
  await mag('bewoner bekijkt het bericht van de helper (view)', () => b.client.collection(COLLECTIE).getOne(m2.id));

  // ---- D -------------------------------------------------------------------
  kop('D. Derden lezen en schrijven niets');
  for (const [naam, wie] of [['vreemde bewoner', vb], ['vreemde helper', vh], ['andere helper', h2], ['coordinator zonder incident', c]]) {
    check(`${naam} ziet 0 berichten`, (await lijst(wie.client, k1.id)).length === 0);
    await magNiet(`${naam} kan een bericht niet openen`, () => wie.client.collection(COLLECTIE).getOne(m1.id), [404]);
    await magNiet(`${naam} kan niet schrijven`, () => schrijf(wie, k1.id, 'Hallo?'));
  }
  check('anoniem ziet 0 berichten', (await lijst(anon, k1.id).catch(() => [])).length === 0);
  await magNiet('anoniem kan niet schrijven', () =>
    anon.collection(COLLECTIE).create({ klus: k1.id, afzender: b.id, tekst: 'x', soort: 'tekst' }),
  );

  // ---- E -------------------------------------------------------------------
  kop('E. Coordinator-inzage alleen bij een incident op de klus');
  await mag('bewoner meldt een probleem op de klus', () =>
    b.client.collection('hh_incidenten').create({ klus: k1.id, melder: b.id, soort: 'probleem', omschrijving: `${MERK} chat` }),
  );
  check('coordinator ziet nu de 2 berichten', (await lijst(c.client, k1.id)).length === 2);
  await magNiet('coordinator kan nog steeds niet schrijven', () => schrijf(c, k1.id, 'Meldkamer hier'));
  check('vreemde bewoner ziet nog steeds 0', (await lijst(vb.client, k1.id)).length === 0);

  // ---- F -------------------------------------------------------------------
  kop('F. Vervalsen en wijzigen kan niet');
  await magNiet('helper schrijft namens de bewoner (afzender = bewoner)', () =>
    h.client.collection(COLLECTIE).create({ klus: k1.id, afzender: b.id, tekst: 'Namens jou', soort: 'tekst' }),
  );
  for (const veld of [{ helper: h2.id }, { gelezen_op: new Date().toISOString() }, { gefilterd: true }, { contactverzoek: false }]) {
    await magNiet(`bewoner stuurt ${Object.keys(veld)[0]} zelf mee`, () => schrijf(b, k1.id, 'Hoi', veld));
  }
  await magNiet('bewoner wijzigt de tekst van de helper', () => b.client.collection(COLLECTIE).update(m2.id, { tekst: 'Ik kom niet' }));
  await magNiet('helper wijzigt zijn eigen tekst', () => h.client.collection(COLLECTIE).update(m2.id, { tekst: 'Anders' }));
  await magNiet('helper zet zijn eigen bericht op gelezen', () =>
    h.client.collection(COLLECTIE).update(m2.id, { gelezen_op: new Date().toISOString() }),
  );
  const gelezen = await mag('bewoner (ontvanger) zet gelezen_op', () =>
    b.client.collection(COLLECTIE).update(m2.id, { gelezen_op: new Date().toISOString() }),
  );
  check('gelezen_op staat, tekst ongewijzigd', !!gelezen?.gelezen_op && gelezen?.tekst === 'Ik ben onderweg');
  await magNiet('bewoner verwijdert een bericht', () => b.client.collection(COLLECTIE).delete(m1.id), [400, 403, 404]);
  await magNiet('coordinator verwijdert een bericht', () => c.client.collection(COLLECTIE).delete(m1.id), [400, 403, 404]);
  await magNiet('bericht van 501 tekens', () => schrijf(b, k1.id, 'a'.repeat(501)));

  // ---- G -------------------------------------------------------------------
  kop('G. Filter: nummers, mail en links worden •••');
  const gf = await mag('bewoner schrijft nummer, mail en link', () =>
    schrijf(b, k1.id, 'App me op 06-12 34 56 78 of mail jan@gmail.com, zie www.voorbeeld.nl'),
  );
  check(
    `opgeslagen als "App me op ${VERVANGING} of mail ${VERVANGING}, zie ${VERVANGING}"`,
    gf?.tekst === `App me op ${VERVANGING} of mail ${VERVANGING}, zie ${VERVANGING}`,
    `tekst=${gf?.tekst}`,
  );
  check('gefilterd = ja', gf?.gefilterd === true);
  const opgeslagen = await su.collection(COLLECTIE).getOne(gf.id);
  check('contactverzoek = ja (superuser ziet het)', opgeslagen.contactverzoek === true);
  check('het origineel staat nergens', !JSON.stringify(opgeslagen).includes('12 34 56 78') && !JSON.stringify(opgeslagen).includes('gmail'));
  const doorHelper = await h.client.collection(COLLECTIE).getOne(gf.id);
  check('helper ziet contactverzoek NIET', !('contactverzoek' in doorHelper));
  check('helper ziet gefilterd wel', doorHelper.gefilterd === true);
  const doorCoord = await c.client.collection(COLLECTIE).getOne(gf.id);
  check('coordinator (met incident) ziet contactverzoek', doorCoord.contactverzoek === true);
  const plus = await mag('helper schrijft +31 6 12345678', () => schrijf(h, k1.id, 'Mijn nummer is +31 6 12345678'));
  check('+31-nummer gefilterd', plus?.tekst === `Mijn nummer is ${VERVANGING}`, `tekst=${plus?.tekst}`);

  // ---- H -------------------------------------------------------------------
  kop('H. Meldingen: één per chat per 10 minuten, alleen voor de ontvanger');
  const meldingen = (wie) =>
    su.collection('hh_meldingen').getFullList({
      filter: su.filter('ontvanger = {:o} && soort = {:s} && klus = {:k}', { o: wie.id, s: MELDING_SOORT_BERICHT, k: k1.id }),
    });
  const mh = await meldingen(h);
  const mb = await meldingen(b);
  check('helper kreeg precies 1 melding (3 berichten van de bewoner)', mh.length === 1, `aantal=${mh.length}`);
  check('bewoner kreeg precies 1 melding (2 berichten van de helper)', mb.length === 1, `aantal=${mb.length}`);
  check('melding in gewone taal, zonder inhoud', mh[0]?.titel === 'Nieuw bericht van Bea' && !String(mh[0]?.tekst).includes('poort'), `${mh[0]?.titel} / ${mh[0]?.tekst}`);
  const eigenLijst = await h.client.collection('hh_meldingen').getFullList({ filter: `soort = "${MELDING_SOORT_BERICHT}"` });
  check('helper leest zijn melding via de API', eigenLijst.some((m) => m.klus === k1.id));

  // ---- I -------------------------------------------------------------------
  kop('I. Open of dicht');
  const kOpen = await klus(b, null, 'open');
  await magNiet('klus zonder helper (open): bewoner kan niet schrijven', () => schrijf(b, kOpen.id, 'Iemand?'));
  const kAf = await klus(b, h, 'geaccepteerd');
  await su.collection(assertHh('hh_klus_status')).create({ klus: kAf.id, door: h.id, van: 'bezig', naar: 'afgerond' });
  await su.collection(assertHh('hh_klussen')).update(kAf.id, { status: 'afgerond' });
  await mag('net afgerond: bewoner schrijft nog (binnen 72 uur)', () => schrijf(b, kAf.id, 'Bedankt!'));
  await mag('net afgerond: helper schrijft nog', () => schrijf(h, kAf.id, 'Graag gedaan'));
  const oud = await oudeKlus(su);
  if (!oud) {
    slaOver('geen afgelopen seed-klus van > 72 uur gevonden ("[seed" in de omschrijving)');
  } else {
    const voor = (await su.collection(COLLECTIE).getFullList({ filter: su.filter('klus = {:k}', { k: oud.id }) })).length;
    for (const [rol, id] of [['bewoner', oud.hulpvrager], ['helper', oud.toegewezen_jongere]]) {
      const als = await alsGebruiker(su, id);
      await magNiet(`oude klus (${oud.status} > 72 uur): ${rol} kan niet meer schrijven`, () =>
        als.collection(COLLECTIE).create({ klus: oud.id, afzender: id, tekst: `${MERK} te laat`, soort: 'tekst' }),
      [403]);
      check(`  ${rol}: lezen mag nog wel (list geeft 200)`, Array.isArray(await lijst(als, oud.id)));
    }
    const na = await su.collection(COLLECTIE).getFullList({ filter: su.filter('klus = {:k}', { k: oud.id }) });
    check('op de oude klus is niets geschreven', na.length === voor, `voor=${voor} na=${na.length}`);
    for (const r of na.filter((x) => String(x.tekst).includes(MERK))) await su.collection(assertHh(COLLECTIE)).delete(r.id);
  }

  // ---- J -------------------------------------------------------------------
  kop('J. Wissel van helper');
  const kW = await klus(b, h, 'geaccepteerd');
  await mag('bewoner schrijft aan helper 1', () => schrijf(b, kW.id, 'Hoi helper 1'));
  await mag('helper 1 antwoordt', () => schrijf(h, kW.id, 'Hoi!'));
  await su.collection(assertHh('hh_klussen')).update(kW.id, { toegewezen_jongere: h2.id });
  check('helper 1 (niet meer op de klus) leest 0', (await lijst(h.client, kW.id)).length === 0);
  check('helper 2 leest het oude gesprek niet (0)', (await lijst(h2.client, kW.id)).length === 0);
  await magNiet('helper 1 kan niet meer schrijven', () => schrijf(h, kW.id, 'Nog iets'));
  const n2 = await mag('helper 2 schrijft', () => schrijf(h2, kW.id, 'Ik neem het over'));
  check('het nieuwe bericht hoort bij helper 2', n2?.helper === h2.id);
  check('helper 2 leest alleen zijn eigen gesprek (1)', (await lijst(h2.client, kW.id)).length === 1);
  check('bewoner leest alles (3)', (await lijst(b.client, kW.id)).length === 3);

  // ---- K -------------------------------------------------------------------
  kop('K. Realtime');
  if (typeof EventSource === 'undefined') {
    slaOver('geen EventSource in deze node (draai met --experimental-eventsource)');
  } else {
    const kR = await klus(b, h, 'onderweg');
    const binnen = { b: [], vb: [], c: [] };
    const stops = [];
    for (const [sleutel, wie] of [['b', b], ['vb', vb], ['c', c]]) {
      stops.push(await wie.client.collection(COLLECTIE).subscribe('*', (ev) => binnen[sleutel].push(ev)));
    }
    await wacht(500);
    const r = await mag('helper schrijft tijdens het luisteren', () => schrijf(h, kR.id, 'Ik ben er'));
    for (let i = 0; i < 50 && !binnen.b.some((ev) => ev.record?.id === r?.id); i++) await wacht(100);
    check('bewoner krijgt het bericht realtime binnen 5 s', binnen.b.some((ev) => ev.action === 'create' && ev.record?.id === r?.id));
    check('realtime-bericht zonder contactverzoek-veld', binnen.b.every((ev) => !('contactverzoek' in (ev.record ?? {}))));
    await wacht(500);
    check('vreemde bewoner krijgt niets', binnen.vb.length === 0, `aantal=${binnen.vb.length}`);
    check('coordinator (zonder incident op deze klus) krijgt niets', binnen.c.every((ev) => ev.record?.klus !== kR.id));
    for (const stop of stops) await stop();
  }

  // ---- L -------------------------------------------------------------------
  kop('L. Opruimen en nameten');
  await opruimen(su);
  const rest = await su.collection('hh_users').getFullList({ filter: su.filter('email ~ {:p}', { p: MAIL_PREFIX }) });
  const restKlus = await su.collection('hh_klussen').getFullList({ filter: su.filter('omschrijving ~ {:m}', { m: MERK }) });
  check('geen tijdelijke accounts en klussen meer', rest.length === 0 && restKlus.length === 0);

  console.log(`\n${groen} groen, ${rood} rood${overgeslagen ? `, ${overgeslagen} overgeslagen` : ''}.`);
  if (rood) process.exitCode = 1;
}

main().catch(fail);
