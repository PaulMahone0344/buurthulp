// HeitjeHulp B11 stap 3 — check meldkamer tegen een ECHTE PocketBase (lokaal
// of prod).
//
// Zonder --apply: alleen lezen (collectie, velden, rules, sloten, instellingen,
// routes).
// Met --apply: tijdelijke accounts b11check-...@heitjehulp.invalid (nooit
// mail), partners met code "B11CHK...", klussen "[b11check]" (door de
// superuser gemaakt), één tijdelijk klustype (niet actief). De schakelaars
// b11_kennismaking_verplicht en b11_zelfde_paar_aan staan hooguit een paar
// seconden AAN en gaan in een finally terug naar hun oude waarde.
//   C partnercode bij aanmelden + tellers + wie partner mag zetten
//   D kennismaking: nog/gesproken, sloten, route, auditregel, verrijken
//   E keuren wacht op de kennismaking (schakelaar aan), daarna goedkeuren
//   F kennismaking geweigerd: geblokkeerd + open klus geannuleerd
//   G VOG-wachtrij (18+ zonder VOG; <18 niet)
//   H chat: meldkamer leest zonder melding; vreemde bewoner niet
//   I zelfde paar: helper 15, 3e klus niets, 4e klus één signaal; 18+ nooit
//   J klustype min_leeftijd wijzigen (coordinator)
//   N opruimen en nameten
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/152-b11check.mjs            (dry-run, alleen lezen)
//   node scripts/152-b11check.mjs --apply
//   node scripts/152-b11check.mjs --apply --alleen-opruimen

import { randomBytes } from 'node:crypto';
import { superuserClient, userClient, anonClient, assertHh, APPLY, PB_URL } from './_lib.mjs';
import { NIEUWE_COLLECTIES, PARTNERS, HULP } from './150-b11-velden.mjs';
import { PARTNER_RULES, USERS_SLOT_KENNISMAKING, USERS_SLOT_PARTNER, BERICHTEN_NIEUW } from './151-b11-rules.mjs';
import { REGIO_WIJK } from './81-b2-werkgebied.mjs';
import { TIEL, invoer } from './_adressen.mjs';

const MAIL_PREFIX = 'b11check-';
const MAIL_DOMEIN = '@heitjehulp.invalid';
const MERK = '[b11check]';
const CODE_PREFIX = 'B11CHK';
const ALLEEN_OPRUIMEN = process.argv.includes('--alleen-opruimen');
const I = HULP.INSTELLING;

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
async function magNiet(label, fn, codes = [400, 403, 404]) {
  try {
    await fn();
    check(label, false, 'verzoek is onterecht gelukt');
    return null;
  } catch (e) {
    check(`${label} (${e?.status})`, codes.includes(e?.status), `status=${e?.status} ${e?.response?.message ?? ''}`);
    return e;
  }
}
async function mag(label, fn) {
  try {
    const r = await fn();
    check(label, true);
    return r;
  } catch (e) {
    check(label, false, `status=${e?.status} ${JSON.stringify(e?.response ?? e?.message)}`);
    return null;
  }
}
async function route(client, pad, body = {}, method = 'POST') {
  try {
    return { status: 200, body: await client.send(pad, method === 'GET' ? { method } : { method, body }) };
  } catch (e) {
    return { status: e?.status ?? 0, body: e?.response ?? {} };
  }
}
const nu = () => new Date().toISOString().replace('T', ' ');
function geboren(jaren) {
  const d = new Date();
  d.setUTCFullYear(d.getUTCFullYear() - jaren);
  d.setUTCDate(d.getUTCDate() - 3);
  return `${d.toISOString().slice(0, 10)} 00:00:00.000Z`;
}
const morgen = (uur) => {
  const d = new Date(Date.now() + 3 * 24 * 3600 * 1000);
  d.setUTCHours(uur, 0, 0, 0);
  return d.toISOString();
};

// ---------------------------------------------------------------- opruimen

async function opruimen(su) {
  const accounts = await su.collection('hh_users').getFullList({ filter: su.filter('email ~ {:p}', { p: MAIL_PREFIX }) });
  let aantal = 0;
  const weg = async (col, filter, params) => {
    const rijen = await su.collection(col).getFullList({ filter: su.filter(filter, params) });
    for (const r of rijen) await su.collection(assertHh(col)).delete(r.id);
    return rijen.length;
  };
  aantal += await weg('hh_klussen', 'omschrijving ~ {:m}', { m: MERK }).catch(() => 0);
  for (const u of accounts) {
    const klussen = await su.collection('hh_klussen').getFullList({
      filter: su.filter('hulpvrager = {:id} || geplaatst_door = {:id} || toegewezen_jongere = {:id}', { id: u.id }),
    });
    for (const k of klussen) {
      aantal += await weg('hh_meldingen', 'klus = {:id}', { id: k.id });
      aantal += await weg('hh_incidenten', 'klus = {:id}', { id: k.id });
      aantal += await weg('hh_berichten', 'klus = {:id}', { id: k.id });
      aantal += await weg('hh_beoordelingen', 'klus = {:id}', { id: k.id });
      await su.collection(assertHh('hh_klussen')).delete(k.id);
      aantal++;
    }
  }
  for (const u of accounts) {
    aantal += await weg('hh_meldingen', 'ontvanger = {:id}', { id: u.id });
    aantal += await weg('hh_incidenten', 'melder = {:id}', { id: u.id });
    aantal += await weg('hh_ouder_toestemming', 'helper = {:id}', { id: u.id }).catch(() => 0);
    const profielen = await su.collection('hh_profielen').getFullList({ filter: su.filter('gebruiker = {:id}', { id: u.id }) });
    for (const id of [u.id, ...profielen.map((p) => p.id)]) aantal += await weg('hh_auditlog', 'door = {:id} || doel_id = {:id}', { id });
  }
  for (const u of accounts) await su.collection(assertHh('hh_users')).delete(u.id);
  aantal += accounts.length;
  aantal += await weg('hh_klustypes', 'naam ~ {:m}', { m: MERK });
  try {
    aantal += await weg(PARTNERS, 'code ~ {:c}', { c: CODE_PREFIX });
  } catch (_) {
    // hh_partners bestaat nog niet (vóór 150): niets op te ruimen.
  }
  if (aantal) console.log(`  ↻ ${aantal} record(s) verwijderd (waarvan ${accounts.length} tijdelijk(e) account(s))`);
}

// ---------------------------------------------------------------- B

async function voorwaarden(su) {
  kop('B. Voorwaarden op de server (alleen lezen)');
  const norm = (s) => s.replace(/[`"]/g, '').replace(/\s+/g, ' ').trim();
  for (const def of NIEUWE_COLLECTIES) {
    let col = null;
    try {
      col = await su.collections.getOne(def.naam);
    } catch (_) {
      col = null;
    }
    check(`${def.naam} bestaat`, !!col, 'draai 150 --apply');
    if (!col) continue;
    for (const idx of def.indexen) check(`  index: ${idx.replace(/^CREATE (UNIQUE )?INDEX \S+ ON /, '')}`, (col.indexes || []).some((i) => norm(i) === norm(idx)));
    const zelfde = Object.keys(PARTNER_RULES).every((k) => (col[k] ?? null) === PARTNER_RULES[k]);
    check('  rules gelijk aan 151', zelfde, 'draai 151 --apply');
  }
  const users = await su.collections.getOne('hh_users');
  const mist = ['kennismaking_status', 'kennismaking_op', 'kennismaking_door', 'kennismaking_notitie', 'partner'].filter((v) => !users.fields.some((f) => f.name === v));
  check('hh_users: B11-velden bestaan', !mist.length, `ontbreekt: ${mist.join(', ')}`);
  const slot = ['createRule', 'updateRule'].every((k) => users[k] === null || (String(users[k]).includes(USERS_SLOT_KENNISMAKING) && String(users[k]).includes(USERS_SLOT_PARTNER)));
  check('hh_users: B11-sloten op create/update', slot, 'draai 151 --apply');
  const ber = await su.collections.getOne('hh_berichten');
  check('hh_berichten: meldkamer leest alles (list/view)', ['listRule', 'viewRule'].every((k) => String(ber[k]).includes(BERICHTEN_NIEUW) && !String(ber[k]).includes('hh_incidenten')));
  for (const { sleutel } of HULP.STANDAARD_INSTELLINGEN) {
    const r = await su.collection('hh_instellingen').getList(1, 1, { filter: su.filter('sleutel = {:s}', { s: sleutel }) });
    check(`instelling ${sleutel} bestaat (${r.items.length ? JSON.stringify(r.items[0].waarde) : '-'})`, r.items.length === 1, 'draai 150 --apply');
  }
  const anon = anonClient();
  for (const pad of ['/api/hh/meldkamer/vog', '/api/hh/meldkamer/partners']) {
    const r = await route(anon, pad, {}, 'GET');
    check(`route ${pad} bestaat (anoniem 401, kreeg ${r.status})`, r.status === 401, 'draai 153-hook-deploy.sh');
  }
  const r = await route(anon, '/api/hh/meldkamer/kennismaking/x', { besluit: 'gesproken' });
  check(`route meldkamer/kennismaking bestaat (anoniem 401, kreeg ${r.status})`, r.status === 401);
  const regio = (await su.collection('hh_wijken').getFullList({ filter: su.filter('wijk = {:w}', { w: REGIO_WIJK.wijk }) }))[0];
  check(`wijk "${REGIO_WIJK.wijk}" bestaat`, !!regio);
  return regio;
}

// ---------------------------------------------------------------- main

async function main() {
  for (const c of ['hh_users', 'hh_profielen', 'hh_klussen', 'hh_instellingen', PARTNERS]) assertHh(c);
  const su = await superuserClient();
  console.log('Verbonden met', PB_URL, APPLY ? '(APPLY)' : '(DRY-RUN)', '\n');
  if (!APPLY) {
    console.log('DRY-RUN: er wordt NIETS geschreven.');
    await voorwaarden(su);
    console.log('\nWat --apply ZOU doen:');
    console.log(`  · tijdelijke accounts (${MAIL_PREFIX}...${MAIL_DOMEIN}); 4 aanmeldingen als anoniem (1 PDOK-verzoek: Kerkstraat 1 Tiel, 10 min onthouden);`);
    console.log(`  · 2 tijdelijke partners (${CODE_PREFIX}...), 1 tijdelijk klustype (niet actief), ±8 klussen door de superuser;`);
    console.log('  · b11_kennismaking_verplicht en b11_zelfde_paar_aan een paar seconden AAN, daarna terug;');
    console.log('  · één klus goedgekeurd (B4: "nieuwe klus"-melding aan beschikbare helpers in de regio);');
    console.log('  · alles opruimen en nameten.');
    console.log(`\n${groen} groen, ${rood} rood (leescontroles).`);
    if (rood > 0) console.log('Rood is verwacht zolang 150, 151 en 153 nog niet uitgerold zijn.');
    return;
  }
  kop('A. Opruimen van een eerdere run');
  await opruimen(su);
  if (ALLEEN_OPRUIMEN) {
    console.log('\nAlleen opgeruimd.');
    return;
  }
  const regio = await voorwaarden(su);
  const licht = (await su.collection('hh_klustypes').getFullList()).find((t) => t.naam === 'Boodschappen');
  if (!regio || !licht) {
    console.log('\nZonder regio-wijk en categorie Boodschappen kan de check niet verder.');
    process.exitCode = 1;
    return;
  }
  const oud = {};
  for (const s of [I.KENNISMAKING, I.PAAR_AAN]) oud[s] = (await instelling(su, s))?.waarde ?? false;
  try {
    await secties(su, regio, licht);
  } finally {
    kop('N. Opruimen en nameten');
    for (const [s, w] of Object.entries(oud)) await zetInstelling(su, s, w);
    for (const s of Object.keys(oud)) {
      const na = await instelling(su, s);
      check(`instelling ${s} terug op ${JSON.stringify(oud[s])}`, JSON.stringify(na?.waarde) === JSON.stringify(oud[s]), JSON.stringify(na?.waarde));
    }
    await opruimen(su);
    const rest = await su.collection('hh_users').getFullList({ filter: su.filter('email ~ {:p}', { p: MAIL_PREFIX }) });
    check('geen tijdelijke accounts meer', rest.length === 0, `${rest.length} over`);
    const klussen = await su.collection('hh_klussen').getFullList({ filter: su.filter('omschrijving ~ {:m}', { m: MERK }) });
    check('geen [b11check]-klussen meer', klussen.length === 0, `${klussen.length} over`);
    const partners = await su.collection(PARTNERS).getFullList({ filter: su.filter('code ~ {:c}', { c: CODE_PREFIX }) });
    check('geen tijdelijke partners meer', partners.length === 0, `${partners.length} over`);
    console.log(`\n${groen} groen, ${rood} rood.`);
    if (rood > 0) process.exitCode = 1;
  }
}

async function instelling(su, sleutel) {
  const r = await su.collection('hh_instellingen').getList(1, 1, { filter: su.filter('sleutel = {:s}', { s: sleutel }) });
  return r.items[0] ?? null;
}
async function zetInstelling(su, sleutel, waarde) {
  const rij = await instelling(su, sleutel);
  if (rij) await su.collection(assertHh('hh_instellingen')).update(rij.id, { waarde });
  else await su.collection(assertHh('hh_instellingen')).create({ sleutel, waarde });
}

// ---------------------------------------------------------------- secties

async function secties(su, regio, licht) {
  const wachtwoord = randomBytes(18).toString('base64url');
  const nieuwMail = (label) => `${MAIL_PREFIX}${label.toLowerCase()}-${randomBytes(4).toString('hex')}${MAIL_DOMEIN}`;
  const anon = anonClient();
  async function account(label, rol, extra = {}) {
    const email = nieuwMail(label);
    const record = await su.collection(assertHh('hh_users')).create({
      email, password: wachtwoord, passwordConfirm: wachtwoord, verified: true, rol, naam: `${label} ${MERK}`, taal: 'nl', wijk: regio.id, ...extra,
    });
    return { id: record.id, email, record, client: await userClient(email, wachtwoord) };
  }
  async function registreer(label, extra) {
    const email = nieuwMail(label);
    const record = await anon.collection('hh_users').create({
      email, password: wachtwoord, passwordConfirm: wachtwoord, taal: 'nl', naam: `${label} ${MERK}`, ...invoer(TIEL), ...extra,
    });
    await su.collection('hh_users').update(record.id, { verified: true });
    return { id: record.id, email, record, client: await userClient(email, wachtwoord) };
  }
  async function profiel(h, extra = {}) {
    const er = await su.collection('hh_profielen').getFullList({ filter: su.filter('gebruiker = {:g}', { g: h.id }) });
    if (er.length) return su.collection(assertHh('hh_profielen')).update(er[0].id, extra);
    return su.collection(assertHh('hh_profielen')).create({ gebruiker: h.id, verificatiestatus: 'in_behandeling', ...extra });
  }
  let teller = 0;
  const klus = (bewoner, extra = {}) =>
    su.collection(assertHh('hh_klussen')).create({
      hulpvrager: bewoner.id, geplaatst_door: bewoner.id, klustype: licht.id, bron: 'telefoon',
      omschrijving: `${MERK} klus ${++teller}`, adres: 'Kerkstraat 1, 4001 MA Tiel', lat: TIEL.lat, lon: TIEL.lon,
      wanneer_van: morgen(10), wanneer_tot: morgen(11), vergoeding_jongere: 10, bedrag_bruto: 10, status: 'open', ...extra,
    });
  const coord = await account('Meldkamer', 'coordinator');
  const zelf = (u) => u.client.collection('hh_users').getOne(u.id);

  // ---------------------------------------------------------------- C
  kop('C. Partnercode bij aanmelden helper');
  const code = `${CODE_PREFIX}-${randomBytes(3).toString('hex').toUpperCase()}`;
  const partner = await su.collection(assertHh(PARTNERS)).create({ naam: `Jongerenwerk ${MERK}`, code, actief: true });
  const slapend = await su.collection(assertHh(PARTNERS)).create({ naam: `Oud ${MERK}`, code: `${code}-OUD`, actief: false });
  const metCode = await mag('helper (20) registreert met de code in kleine letters', () =>
    registreer('partner', { rol: 'jongere', geboortedatum: geboren(20), partner_code: ` ${code.toLowerCase()} ` }));
  check('  partner gezet', (await su.collection('hh_users').getOne(metCode.id)).partner === partner.id);
  check('  helper ziet zijn eigen partner', (await zelf(metCode)).partner === partner.id);
  const fout = await magNiet('onbekende code -> 400', () => registreer('fout', { rol: 'jongere', geboortedatum: geboren(20), partner_code: 'BESTAATNIET' }), [400]);
  check('  data.partner_code.code = hh_partner_code', fout?.response?.data?.partner_code?.code === 'hh_partner_code', JSON.stringify(fout?.response?.data));
  await magNiet('code van een niet-actieve partner -> 400', () => registreer('slaapt', { rol: 'jongere', geboortedatum: geboren(20), partner_code: slapend.code }), [400]);
  await magNiet('partner-id zelf meesturen -> geweigerd', () => registreer('zelfid', { rol: 'jongere', geboortedatum: geboren(20), partner: partner.id }), [400]);
  const bewonerCode = await mag('bewoner met een code: code genegeerd', () => registreer('bewcode', { rol: 'hulpvrager', partner_code: code }));
  check('  bewoner zonder partner', !(await su.collection('hh_users').getOne(bewonerCode.id)).partner);
  await magNiet('helper zet eigen partner niet', () => metCode.client.collection('hh_users').update(metCode.id, { partner: '' }), [400, 403, 404]);
  let r = await route(metCode.client, '/api/hh/meldkamer/partners', {}, 'GET');
  check(`helper GET partners -> 403 (kreeg ${r.status})`, r.status === 403);
  const lijstHelper = await metCode.client.collection(PARTNERS).getList(1, 50).catch((e) => ({ items: [], status: e.status }));
  check('helper ziet hh_partners niet', lijstHelper.items.length === 0);
  r = await route(coord.client, '/api/hh/meldkamer/partners', {}, 'GET');
  let p = r.body?.partners?.find((x) => x.id === partner.id);
  check(`meldkamer: teller aangemeld 1, goedgekeurd 0 (kreeg ${JSON.stringify(p)})`, p?.aangemeld === 1 && p?.goedgekeurd === 0);
  await profiel(metCode, { verificatiestatus: 'goedgekeurd' });
  r = await route(coord.client, '/api/hh/meldkamer/partners', {}, 'GET');
  p = r.body?.partners?.find((x) => x.id === partner.id);
  check(`  na goedkeuren: goedgekeurd 1 (kreeg ${p?.goedgekeurd})`, p?.goedgekeurd === 1);
  check('  niet-actieve partner staat er ook (0/0)', r.body?.partners?.some((x) => x.id === slapend.id && x.aangemeld === 0 && x.actief === false));
  await mag('meldkamer zet partner van een helper (Gebruikers)', () => coord.client.collection('hh_users').update(metCode.id, { partner: slapend.id }));
  await mag('meldkamer maakt/wijzigt een partner', () => coord.client.collection(PARTNERS).update(slapend.id, { notitie: 'check' }));

  // ---------------------------------------------------------------- D
  kop('D. Kennismaking');
  const anja = await mag('bewoner registreert (Tiel)', () => registreer('anja', { rol: 'hulpvrager' }));
  let rec = await su.collection('hh_users').getOne(anja.id);
  check(`  kennismaking_status "nog" (kreeg "${rec.kennismaking_status}")`, rec.kennismaking_status === 'nog');
  const zichzelf = await zelf(anja);
  check('  bewoner ziet eigen status, niet notitie/door', zichzelf.kennismaking_status === 'nog' && !('kennismaking_notitie' in zichzelf) && !('kennismaking_door' in zichzelf));
  await magNiet('bewoner zet eigen kennismaking niet', () => anja.client.collection('hh_users').update(anja.id, { kennismaking_status: 'gesproken' }), [400, 403, 404]);
  await magNiet('ook de meldkamer zet hem niet via de API (route)', () => coord.client.collection('hh_users').update(anja.id, { kennismaking_status: 'gesproken' }), [400, 403, 404]);
  const tel = await mag('meldkamer meldt een bewoner telefonisch aan', () =>
    coord.client.collection('hh_users').create({
      email: nieuwMail('telefoon'), password: wachtwoord, passwordConfirm: wachtwoord, rol: 'hulpvrager', naam: `Tel ${MERK}`, taal: 'nl', ...invoer(TIEL),
    }));
  check('  telefonisch aangemeld = meteen gesproken', tel?.kennismaking_status === 'gesproken' && tel?.kennismaking_door === coord.id, JSON.stringify(tel?.kennismaking_status));
  const kRoute = (u, body) => route(coord.client, `/api/hh/meldkamer/kennismaking/${u.id}`, body);
  r = await route(anja.client, `/api/hh/meldkamer/kennismaking/${anja.id}`, { besluit: 'gesproken' });
  check(`bewoner roept de route aan -> 403 (kreeg ${r.status})`, r.status === 403);
  r = await kRoute(anja, { besluit: 'misschien' });
  check(`fout besluit -> 400 (kreeg ${r.status} ${r.body?.reden})`, r.status === 400 && r.body?.reden === 'besluit');
  r = await kRoute(metCode, { besluit: 'gesproken' });
  check(`kennismaking voor een helper -> 409 rol (kreeg ${r.status} ${r.body?.reden})`, r.status === 409 && r.body?.reden === 'rol');

  // ---------------------------------------------------------------- E
  kop('E. Keuren wacht op de kennismaking (schakelaar even aan)');
  // De superuser (beheer) krijgt een klus meteen goedgekeurd (B4); hier weer
  // ongekeurd maken, zoals een klus die de bewoner zelf plaatst.
  const kAnja = await klus(anja);
  await su.collection(assertHh('hh_klussen')).update(kAnja.id, { klus_goedgekeurd_op: '', klus_goedgekeurd_door: '' });
  const keur = (k, besluit = 'goedkeuren', reden = '') => route(coord.client, `/api/hh/klussen/${k.id}/keuren`, { besluit, reden });
  await zetInstelling(su, I.KENNISMAKING, true);
  try {
    r = await keur(kAnja);
    check(`goedkeuren -> 409 kennismaking (kreeg ${r.status} ${r.body?.reden})`, r.status === 409 && r.body?.reden === 'kennismaking');
    check('  melding noemt het belletje', /Bel eerst/.test(r.body?.melding ?? ''), r.body?.melding);
    const gezien = await anja.client.collection('hh_klussen').getOne(kAnja.id);
    check('  bewoner ziet wacht_op_kennismaking = true', gezien.wacht_op_kennismaking === true, JSON.stringify(gezien.wacht_op_kennismaking));
    r = await kRoute(anja, { besluit: 'gesproken', notitie: 'Aardige dame, wil hulp met boodschappen.' });
    check(`route gesproken -> 200 (kreeg ${r.status})`, r.status === 200 && r.body?.kennismaking_status === 'gesproken', JSON.stringify(r.body));
    rec = await coord.client.collection('hh_users').getOne(anja.id);
    check('  meldkamer ziet status, datum, door en notitie', rec.kennismaking_status === 'gesproken' && !!rec.kennismaking_op && rec.kennismaking_door === coord.id && /Aardige/.test(rec.kennismaking_notitie));
    const audit = await su.collection('hh_auditlog').getFullList({ filter: su.filter('doel_id = {:d} && door = {:c}', { d: anja.id, c: coord.id }) });
    check('  auditregel in hh_auditlog', audit.some((a) => a.detail?.velden?.includes('kennismaking_status')), JSON.stringify(audit.map((a) => a.detail)));
    const naGesprek = await anja.client.collection('hh_klussen').getOne(kAnja.id);
    check('  wacht_op_kennismaking weg', naGesprek.wacht_op_kennismaking !== true);
    r = await keur(kAnja);
    check(`nu goedkeuren -> 200 (kreeg ${r.status})`, r.status === 200, JSON.stringify(r.body));
  } finally {
    await zetInstelling(su, I.KENNISMAKING, false);
  }
  const bert = await registreer('bert', { rol: 'hulpvrager' });
  const kBert = await klus(bert);
  r = await keur(kBert, 'afkeuren', 'Dit is een testklus van de check.');
  check(`schakelaar uit: afkeuren werkt gewoon (kreeg ${r.status})`, r.status === 200);

  // ---------------------------------------------------------------- F
  kop('F. Kennismaking geweigerd');
  const kOpen = await klus(bert, { omschrijving: `${MERK} open klus van bert` });
  r = await kRoute(bert, { besluit: 'geweigerd', notitie: 'Wilde iemand voor zorgtaken.' });
  check(`route geweigerd -> 200, 1 klus geannuleerd (kreeg ${r.status} ${r.body?.geannuleerd})`, r.status === 200 && r.body?.geannuleerd === 1, JSON.stringify(r.body));
  check('  open klus nu geannuleerd', (await su.collection('hh_klussen').getOne(kOpen.id)).status === 'geannuleerd');
  const log = await su.collection('hh_klus_status').getFullList({ filter: su.filter('klus = {:k}', { k: kOpen.id }) });
  check('  logregel open -> geannuleerd', log.some((l) => l.van === 'open' && l.naar === 'geannuleerd' && /kennismaking/.test(l.toelichting)));
  check('  account geblokkeerd', (await su.collection('hh_users').getOne(bert.id)).geblokkeerd === true);
  await magNiet('geblokkeerde bewoner kan niet meer inloggen', () => userClient(bert.email, wachtwoord), [400, 403]);

  // ---------------------------------------------------------------- G
  kop('G. VOG-wachtrij');
  const vol = await account('Volwassen', 'jongere', { geboortedatum: geboren(25) });
  await profiel(vol, { verificatiestatus: 'in_behandeling' });
  const jong = await account('Jong', 'jongere', { geboortedatum: geboren(16) });
  await profiel(jong, { verificatiestatus: 'goedgekeurd' });
  r = await route(coord.client, '/api/hh/meldkamer/vog', {}, 'GET');
  const rij = r.body?.helpers?.find((x) => x.gebruiker === vol.id);
  check(`helper 25 zonder VOG staat erin (reden geen, kreeg ${JSON.stringify(rij)})`, rij?.reden === 'geen' && rij?.leeftijd === 25);
  check('  helper 16 staat er niet in', !r.body?.helpers?.some((x) => x.gebruiker === jong.id));
  await profiel(vol, { vog_gezien_op: nu() });
  r = await route(coord.client, '/api/hh/meldkamer/vog', {}, 'GET');
  check('  na "VOG gezien" weg uit de wachtrij', !r.body?.helpers?.some((x) => x.gebruiker === vol.id));
  r = await route(vol.client, '/api/hh/meldkamer/vog', {}, 'GET');
  check(`helper GET vog -> 403 (kreeg ${r.status})`, r.status === 403);

  // ---------------------------------------------------------------- H
  kop('H. Chat: meldkamer leest zonder melding');
  const ruud = await account('Ruud', 'jongere', { geboortedatum: geboren(25) });
  await profiel(ruud, { verificatiestatus: 'goedgekeurd', vog_gezien_op: nu() });
  const kChat = await klus(anja, { status: 'geaccepteerd', toegewezen_jongere: ruud.id, klus_goedgekeurd_op: nu() });
  await mag('bewoner stuurt een bericht', () => anja.client.collection('hh_berichten').create({ klus: kChat.id, afzender: anja.id, soort: 'tekst', tekst: 'Hoi Ruud, tot zaterdag!' }));
  const incidenten = await su.collection('hh_incidenten').getFullList({ filter: su.filter('klus = {:k}', { k: kChat.id }) });
  check('  (geen melding op deze klus)', incidenten.length === 0);
  const leest = await coord.client.collection('hh_berichten').getFullList({ filter: coord.client.filter('klus = {:k}', { k: kChat.id }) });
  check(`meldkamer leest het gesprek (kreeg ${leest.length})`, leest.length === 1 && leest[0].tekst === 'Hoi Ruud, tot zaterdag!');
  const niets = await bewonerCode.client.collection('hh_berichten').getFullList({ filter: bewonerCode.client.filter('klus = {:k}', { k: kChat.id }) });
  check('andere bewoner leest niets', niets.length === 0);
  const helperZiet = await ruud.client.collection('hh_users').getOne(anja.id);
  check('helper ziet geen kennismaking-velden of partner van de bewoner', !('kennismaking_status' in helperZiet) && !('kennismaking_notitie' in helperZiet) && !('partner' in helperZiet), Object.keys(helperZiet).join(','));

  // ---------------------------------------------------------------- I
  kop('I. Zelfde paar (schakelaar even aan)');
  const daan = await account('Daan', 'jongere', { geboortedatum: geboren(15) });
  const kees = await account('Kees', 'hulpvrager');
  const afgerond = async (h) => {
    const k = await klus(kees, { status: 'afgerond', toegewezen_jongere: h.id, klus_goedgekeurd_op: nu() });
    await su.collection(assertHh('hh_klus_status')).create({ klus: k.id, door: h.id, van: 'bezig', naar: 'afgerond' });
    return k;
  };
  const signalen = async () => {
    const rijen = await su.collection('hh_incidenten').getFullList({ filter: su.filter('soort = "signaal" && omschrijving ~ {:c}', { c: `zp:${daan.id}:${kees.id}` }) });
    return rijen;
  };
  await zetInstelling(su, I.PAAR_AAN, true);
  try {
    for (let i = 0; i < 3; i++) await afgerond(daan);
    check('3 klussen: geen signaal', (await signalen()).length === 0);
    await afgerond(daan);
    let s = await signalen();
    check(`4e klus: één signaal (kreeg ${s.length})`, s.length === 1);
    check('  soort signaal, tekst met voornamen en leeftijd', s[0]?.soort === 'signaal' && /^\[zelfde paar\] Helper Daan \(15\) en bewoner Kees deden 4 klussen/.test(s[0]?.omschrijving ?? ''), s[0]?.omschrijving);
    check('  melder is een coordinator, niet de helper of bewoner', s[0] && s[0].melder !== daan.id && s[0].melder !== kees.id);
    const hZiet = await daan.client.collection('hh_incidenten').getFullList();
    check('  helper ziet het signaal niet', !hZiet.some((x) => x.id === s[0]?.id));
    await afgerond(daan);
    s = await signalen();
    check('5e klus: geen tweede signaal', s.length === 1);
    const eva = await account('Eva', 'jongere', { geboortedatum: geboren(30) });
    for (let i = 0; i < 4; i++) await afgerond(eva);
    const volw = await su.collection('hh_incidenten').getFullList({ filter: su.filter('omschrijving ~ {:c}', { c: `zp:${eva.id}:` }) });
    check('volwassen helper: nooit een signaal', volw.length === 0);
  } finally {
    await zetInstelling(su, I.PAAR_AAN, false);
  }

  // ---------------------------------------------------------------- J
  kop('J. Klustype: minimale leeftijd wijzigen');
  const type = await mag('meldkamer maakt een tijdelijk klustype (niet actief)', () =>
    coord.client.collection('hh_klustypes').create({ naam: `Test ${MERK}`, actief: false, min_leeftijd: 10, richtduur: 30, richtvergoeding: 5 }));
  if (type) {
    const na = await mag('meldkamer zet min_leeftijd op 16', () => coord.client.collection('hh_klustypes').update(type.id, { min_leeftijd: 16 }));
    check('  opgeslagen: 16', na?.min_leeftijd === 16);
    await magNiet('helper wijzigt min_leeftijd niet', () => ruud.client.collection('hh_klustypes').update(type.id, { min_leeftijd: 10 }), [400, 403, 404]);
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
