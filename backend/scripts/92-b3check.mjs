// HeitjeHulp B3 — bewijst de ouder-toestemming (90, 91, 93) op de ECHTE
// server. Werkt alleen met EIGEN tijdelijke accounts (e-mail
// "b3check-...@heitjehulp.invalid") en een eigen klus, en ruimt alles op.
// Er doen GEEN seed-accounts mee.
//
// GEEN ECHTE MAIL: de ouder-adressen eindigen op .invalid; de hook verstuurt
// daar nooit mail heen (hh_ouder_hulp.js isNepAdres). Omdat de check de code
// dus niet uit een mail kan halen, zet hij als superuser zelf een BEKENDE
// code (en link-token) in de rij: alleen de hash, precies zoals de hook dat
// doet (codeHash/tokenHash uit hh_ouder_hulp.js).
//
//   A. opruimen van een eerdere (gecrashte) run
//   B. voorwaarden (ook in dry-run, alleen lezen): collectie, rules, hidden
//      hash-velden, routes (anoniem 401), Tiel-wijken regio (91)
//   C. versturen: anoniem 401, bewoner 403, 18+ 409, eigen adres 400;
//      helper < 18 200; de rij heeft hashes, nergens een leesbare code
//   D. code: 4x fout 400, 5e keer 429 geblokkeerd, dan ook de goede code
//      429; opnieuw sturen: oude code vervalt, nieuwe werkt (sessie);
//      verlopen (24 uur) geeft 400 en de link "verlopen"; max 3 per dag
//   E. toestemming: zonder sessie 401, zonder vinkje / fout IBAN 400; daarna
//      ouder_toestemming_op + ouder_iban_ok op de helper; vóór: geen open
//      klus en accepteren 403 ouder; na: de klus zichtbaar; zonder
//      goedkeuring meldkamer nog steeds niet
//   F. intrekken met de link: veld gewist, klus direct weg, accepteren 403
//      ouder, nogmaals intrekken 200, status "ingetrokken"
//   G. API: helper, bewoner en anoniem lezen niets; coordinator leest wel
//      maar zonder hash-velden; niemand schrijft; helper zet
//      ouder_toestemming_op niet zelf
//   H. opruimen en nameten
//
// LET OP: alle publieke ouder-routes samen hooguit 30 per IP per uur. Deze
// check doet er ~20. Draai hem dus niet twee keer binnen een uur vanaf
// hetzelfde adres (dan 429 "teveel"; de grens zelf is getest in
// backend/tests/hh_ouder_hulp.test.mjs en in de lokale proef).
//
// DRAAIEN (na 90 --apply, 91 --apply en 93-hook-deploy.sh):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/92-b3check.mjs            (dry-run: alleen leescontroles)
//   node scripts/92-b3check.mjs --apply
//   node scripts/92-b3check.mjs --apply --alleen-opruimen

import { randomBytes, createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, userClient, anonClient, assertHh, APPLY, fail, PB_URL } from './_lib.mjs';
import { COLLECTIE, B3_RULES, GEHEIM } from './90-b3-collectie.mjs';
import { WIJKEN } from './91-b3-wijken.mjs';
import { KLUS_VOORWAARDE } from './80-b2-rules.mjs';
import { REGIO_WIJK } from './81-b2-werkgebied.mjs';

const hier = path.dirname(fileURLToPath(import.meta.url));
const hulpBron = readFileSync(path.join(hier, '..', 'pb_hooks', 'hh_ouder_hulp.js'), 'utf8');
const hulpModule = { exports: {} };
new Function('module', 'exports', hulpBron)(hulpModule, hulpModule.exports);
const hulp = hulpModule.exports;
const sha256 = (s) => createHash('sha256').update(s).digest('hex');

const MAIL_PREFIX = 'b3check-';
const MAIL_DOMEIN = '@heitjehulp.invalid';
const MERK = '[b3check]';
const ALLEEN_OPRUIMEN = process.argv.includes('--alleen-opruimen');
const WEIGER = [400, 403, 404];
const IBAN = 'NL91ABNA0417164300';

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
async function magNiet(label, fn, codes = WEIGER) {
  try {
    await fn();
    check(label, false, 'verzoek is onterecht gelukt');
  } catch (e) {
    check(`${label} (${e?.status})`, codes.includes(e?.status), `status=${e?.status} ${e?.response?.message ?? ''}`);
  }
}
async function verzoek(client, pad, method = 'POST', body) {
  try {
    return { status: 200, body: await client.send(pad, { method, ...(body ? { body } : {}) }) };
  } catch (e) {
    return { status: e?.status ?? 0, body: e?.response ?? {} };
  }
}
const toon = (r) => `kreeg ${r.status} ${r.body?.reden ?? ''}`.trim();

function geboren(jaren) {
  const d = new Date();
  d.setUTCFullYear(d.getUTCFullYear() - jaren);
  return `${d.toISOString().slice(0, 10)} 00:00:00.000Z`;
}
const isoOver = (ms) => new Date(Date.now() + ms).toISOString().replace('T', ' ');

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
      await su.collection(assertHh('hh_klussen')).delete(k.id);
      aantal++;
    }
    aantal += await weg('hh_meldingen', 'ontvanger = {:id}', { id: u.id });
    aantal += await weg(COLLECTIE, 'helper = {:id}', { id: u.id });
    const profielen = await su.collection('hh_profielen').getFullList({ filter: su.filter('gebruiker = {:id}', { id: u.id }) });
    for (const id of [u.id, ...profielen.map((p) => p.id)]) {
      aantal += await weg('hh_auditlog', 'door = {:id} || doel_id = {:id}', { id });
    }
  }
  for (const u of tijdelijk) await su.collection(assertHh('hh_users')).delete(u.id);
  aantal += tijdelijk.length;
  if (aantal) console.log(`  ↻ ${aantal} record(s) verwijderd (waarvan ${tijdelijk.length} tijdelijk(e) account(s))`);
  return tijdelijk.length;
}

async function voorwaarden(su) {
  kop('B. Voorwaarden op de server (alleen lezen)');
  let col = null;
  try {
    col = await su.collections.getOne(COLLECTIE);
  } catch (_) {
    col = null;
  }
  check(`collectie ${COLLECTIE} bestaat`, !!col, 'draai 90 --apply');
  if (col) {
    for (const [k, v] of Object.entries(B3_RULES)) check(`${COLLECTIE}.${k} = ${v === null ? 'null (niemand)' : 'alleen coordinator'}`, (col[k] ?? null) === v);
    for (const g of GEHEIM) check(`${COLLECTIE}.${g} is hidden`, col.fields.find((f) => f.name === g)?.hidden === true);
  }
  const anon = anonClient();
  for (const [pad, method] of [['/api/hh/ouder/versturen', 'POST'], ['/api/hh/ouder/status', 'GET']]) {
    const r = await verzoek(anon, pad, method);
    check(`route ${method} ${pad} bestaat (anoniem 401, ${toon(r)})`, r.status === 401, 'draai 93-hook-deploy.sh');
  }
  const wijken = await su.collection('hh_wijken').getFullList({ filter: 'actief = true' });
  const regio = wijken.find((w) => w.gemeente === REGIO_WIJK.gemeente && w.wijk === REGIO_WIJK.wijk && w.regio === true);
  check(`wijk "${REGIO_WIJK.wijk}" bestaat (B2)`, !!regio);
  for (const w of WIJKEN) check(`wijk ${w} is regio (91)`, wijken.some((r) => r.wijk === w && r.regio === true), 'draai 91 --apply');
  const klussen = await su.collections.getOne('hh_klussen');
  check('hh_klussen.listRule eist ouder-toestemming of VOG (B2)', String(klussen.listRule).includes(KLUS_VOORWAARDE));
  return { col, regio };
}

async function main() {
  for (const c of ['hh_users', 'hh_profielen', 'hh_klussen', 'hh_meldingen', 'hh_auditlog', COLLECTIE]) assertHh(c);
  const su = await superuserClient();
  console.log('Verbonden met', PB_URL, APPLY ? '(APPLY)' : '(DRY-RUN)', '\n');

  if (!APPLY) {
    console.log('DRY-RUN: er wordt NIETS geschreven.');
    await voorwaarden(su);
    console.log('\nWat --apply ZOU doen:');
    console.log(`  · tijdelijke accounts maken (${MAIL_PREFIX}...${MAIL_DOMEIN}): coordinator, bewoner, 4 helpers;`);
    console.log('  · ouder-mails "versturen" naar .invalid-adressen (de hook verstuurt daar NOOIT mail);');
    console.log('  · als superuser een bekende code/link-token (alleen de hash) in de rij zetten en de routes nalopen;');
    console.log('  · één eigen open klus: wie ziet hem en wie mag accepteren, vóór/na toestemming en na intrekken;');
    console.log('  · leesrechten op hh_ouder_toestemming per rol;');
    console.log('  · alles opruimen en nameten.');
    console.log(`\n${groen} groen, ${rood} rood (leescontroles).`);
    if (rood > 0) console.log('Rood is verwacht zolang 90, 91 en 93 nog niet uitgerold zijn.');
    return;
  }

  kop('A. Opruimen van een eerdere run');
  await opruimen(su);
  if (ALLEEN_OPRUIMEN) {
    console.log('\nAlleen opgeruimd.');
    return;
  }

  const { col, regio } = await voorwaarden(su);
  if (!col || !regio) {
    console.log('\nZonder de collectie en de regio-wijk kan de check niet verder.');
    process.exitCode = 1;
    return;
  }

  const wachtwoord = randomBytes(18).toString('base64url');
  const nieuwMail = (label) => `${MAIL_PREFIX}${label}-${randomBytes(4).toString('hex')}${MAIL_DOMEIN}`;
  async function account(label, rol, extra = {}) {
    const email = nieuwMail(label);
    const record = await su.collection(assertHh('hh_users')).create({
      email, password: wachtwoord, passwordConfirm: wachtwoord, verified: true, rol, naam: `${MERK} ${label}`, taal: 'nl', ...extra,
    });
    return { id: record.id, email, client: await userClient(email, wachtwoord) };
  }
  const anon = anonClient();
  const rijVan = async (helperId) => su.collection(COLLECTIE).getFirstListItem(su.filter('helper = {:id}', { id: helperId }));
  /// Zet als superuser een bekende code en link-token (alleen de hashes).
  async function plant(helperId, code, token) {
    const rij = await rijVan(helperId);
    await su.collection(assertHh(COLLECTIE)).update(rij.id, {
      code_hash: hulp.codeHash(sha256, helperId, code),
      ...(token ? { token_hash: hulp.tokenHash(sha256, token) } : {}),
    });
  }
  const codeRoute = (body) => verzoek(anon, '/api/hh/ouder/code', 'POST', body);

  // ---------------------------------------------------------------- C
  kop('C. Versturen (helper < 18, ingelogd)');
  const coord = await account('coord', 'coordinator');
  const bewoner = await account('bewoner', 'hulpvrager', { wijk: regio.id });
  const ouderMail = nieuwMail('ouder');
  const kind = await account('kind', 'jongere', { geboortedatum: geboren(14), wijk: regio.id, ouder_email: ouderMail });
  const volwassen = await account('volwassen', 'jongere', { geboortedatum: geboren(25), wijk: regio.id });
  const tweede = await account('tweede', 'jongere', { geboortedatum: geboren(15), wijk: regio.id });
  const nietGoedgekeurd = await account('wacht', 'jongere', { geboortedatum: geboren(13), wijk: regio.id });
  for (const [h, status] of [[kind, 'goedgekeurd'], [volwassen, 'goedgekeurd'], [tweede, 'goedgekeurd'], [nietGoedgekeurd, 'in_behandeling']]) {
    await su.collection(assertHh('hh_profielen')).create({ gebruiker: h.id, verificatiestatus: status });
  }

  let r = await verzoek(anon, '/api/hh/ouder/versturen', 'POST', { ouder_email: ouderMail });
  check(`anoniem versturen geweigerd (401, ${toon(r)})`, r.status === 401);
  r = await verzoek(bewoner.client, '/api/hh/ouder/versturen', 'POST', { ouder_email: ouderMail });
  check(`bewoner versturen geweigerd (403 rol, ${toon(r)})`, r.status === 403 && r.body?.reden === 'rol');
  r = await verzoek(volwassen.client, '/api/hh/ouder/versturen', 'POST', { ouder_email: ouderMail });
  check(`helper 18+ hoeft niet (409 volwassen, ${toon(r)})`, r.status === 409 && r.body?.reden === 'volwassen');
  r = await verzoek(kind.client, '/api/hh/ouder/versturen', 'POST', { ouder_email: kind.email });
  check(`eigen adres als ouder-adres geweigerd (400 eigenadres, ${toon(r)})`, r.status === 400 && r.body?.reden === 'eigenadres');
  r = await verzoek(kind.client, '/api/hh/ouder/versturen', 'POST', {});
  check(`helper < 18 verstuurt naar het bewaarde adres (200, ${toon(r)})`, r.status === 200 && r.body?.ouder_email === ouderMail && r.body?.nog_te_sturen === 2, JSON.stringify(r.body));
  let rij = await rijVan(kind.id);
  check('de rij staat op verstuurd met pogingen 0', rij.status === 'verstuurd' && rij.pogingen === 0);
  check('code_hash en token_hash zijn sha256 (64 hex)', /^[0-9a-f]{64}$/.test(rij.code_hash) && /^[0-9a-f]{64}$/.test(rij.token_hash));
  const zesCijfers = Object.entries(rij).filter(([, v]) => /^\d{6}$/.test(String(v)));
  check('nergens in de rij een leesbare code van 6 cijfers (ook niet voor de superuser)', zesCijfers.length === 0, JSON.stringify(zesCijfers));
  const verloopt = Date.parse(String(rij.code_verloopt_op).replace(' ', 'T')) - Date.now();
  check('de code verloopt over 24 uur', verloopt > 23.9 * 3600e3 && verloopt <= 24 * 3600e3);
  r = await verzoek(kind.client, '/api/hh/ouder/status', 'GET');
  check(`status voor de helper: verstuurd, nodig (${toon(r)})`, r.status === 200 && r.body?.status === 'verstuurd' && r.body?.nodig === true);
  check('status bevat geen hash, token, sessie of IBAN', !Object.keys(r.body || {}).some((k) => /hash|token|sessie|iban/.test(k)));

  // ---------------------------------------------------------------- D
  kop('D. Code invullen (publiek)');
  await plant(kind.id, '111111');
  for (let i = 1; i <= 4; i++) {
    r = await codeRoute({ email: ouderMail, code: '222222' });
    check(`foute code ${i} (400 code, ${toon(r)})`, r.status === 400 && r.body?.reden === 'code');
  }
  r = await codeRoute({ email: ouderMail, code: '222222' });
  check(`5e foute code: geblokkeerd (429, ${toon(r)})`, r.status === 429 && r.body?.reden === 'geblokkeerd');
  r = await codeRoute({ email: ouderMail, code: '111111' });
  check(`daarna ook de goede code geblokkeerd (429, ${toon(r)})`, r.status === 429 && r.body?.reden === 'geblokkeerd');
  r = await verzoek(kind.client, '/api/hh/ouder/status', 'GET');
  check('de app ziet "geblokkeerd"', r.body?.geblokkeerd === true);

  r = await verzoek(kind.client, '/api/hh/ouder/versturen', 'POST', {});
  check(`opnieuw sturen (200, nog 1, ${toon(r)})`, r.status === 200 && r.body?.nog_te_sturen === 1);
  rij = await rijVan(kind.id);
  check('pogingen weer 0 na opnieuw sturen', rij.pogingen === 0);
  r = await codeRoute({ email: ouderMail, code: '111111' });
  check(`de oude code vervalt na opnieuw sturen (400, ${toon(r)})`, r.status === 400 && r.body?.reden === 'code');
  const token = randomBytes(30).toString('base64url').replace(/[^A-Za-z0-9]/g, 'x');
  await plant(kind.id, '333333', token);
  r = await codeRoute({ email: ouderMail.toUpperCase(), code: '333333' });
  check(`goede code + e-mail geeft een ouder-sessie (${toon(r)})`, r.status === 200 && r.body?.status === 'verstuurd' && String(r.body?.sessie || '').length >= 32, JSON.stringify(r.body));
  check('de pagina krijgt alleen de voornaam', r.body?.voornaam === MERK);
  const sessieUitCode = r.body?.sessie;

  // Verlopen: tweede helper, code 24 uur oud.
  await verzoek(tweede.client, '/api/hh/ouder/versturen', 'POST', { ouder_email: nieuwMail('ouder2') });
  const token2 = randomBytes(30).toString('hex');
  const rij2 = await rijVan(tweede.id);
  await plant(tweede.id, '444444', token2);
  await su.collection(assertHh(COLLECTIE)).update(rij2.id, { code_verloopt_op: isoOver(-60e3) });
  r = await codeRoute({ email: rij2.ouder_email, code: '444444' });
  check(`verlopen code (400 code, ${toon(r)})`, r.status === 400 && r.body?.reden === 'code');
  r = await codeRoute({ token: token2 });
  check(`de link na 24 uur: status verlopen, geen sessie (${toon(r)})`, r.status === 200 && r.body?.status === 'verlopen' && !r.body?.sessie);
  r = await codeRoute({ token: 'bestaatniet' });
  check(`onbekende link (404 link, ${toon(r)})`, r.status === 404 && r.body?.reden === 'link');
  r = await verzoek(tweede.client, '/api/hh/ouder/versturen', 'POST', {});
  r = await verzoek(tweede.client, '/api/hh/ouder/versturen', 'POST', {});
  check(`3e mail van vandaag lukt (${toon(r)})`, r.status === 200 && r.body?.nog_te_sturen === 0);
  r = await verzoek(tweede.client, '/api/hh/ouder/versturen', 'POST', {});
  check(`4e mail van vandaag geweigerd (429 limiet, ${toon(r)})`, r.status === 429 && r.body?.reden === 'limiet');

  // ---------------------------------------------------------------- E
  kop('E. Toestemming geven');
  const klus = await su.collection(assertHh('hh_klussen')).create({
    hulpvrager: bewoner.id, geplaatst_door: bewoner.id,
    klustype: (await su.collection('hh_klustypes').getList(1, 1)).items[0].id,
    omschrijving: `${MERK} testklus`, adres: 'Teststraat 1', lat: 51.88, lon: 5.42, status: 'open', bron: 'app',
    bedrag_bruto: 1000, vergoeding_jongere: 800, commissie: 200,
  });
  const ziet = async (h) => (await h.client.collection('hh_klussen').getList(1, 5, { filter: `id = "${klus.id}"` })).totalItems === 1;
  check('vóór toestemming: helper < 18 ziet de open klus NIET', !(await ziet(kind)));
  r = await verzoek(kind.client, `/api/hh/klussen/${klus.id}/accepteren`);
  check(`vóór toestemming: accepteren geweigerd (403 ouder, ${toon(r)})`, r.status === 403 && r.body?.reden === 'ouder');

  const toestemming = (body) => verzoek(anon, '/api/hh/ouder/toestemming', 'POST', body);
  const goed = { sessie: sessieUitCode, naam: 'B3check Ouder', iban: IBAN, akkoord: true, avp: true };
  r = await toestemming({ ...goed, sessie: 'onzin' });
  check(`zonder geldige sessie (401 sessie, ${toon(r)})`, r.status === 401 && r.body?.reden === 'sessie');
  r = await toestemming({ ...goed, akkoord: false });
  check(`zonder vinkje akkoord (400 akkoord, ${toon(r)})`, r.status === 400 && r.body?.reden === 'akkoord');
  r = await toestemming({ ...goed, iban: 'NL91ABNA0417164301' });
  check(`foute IBAN (400 iban, ${toon(r)})`, r.status === 400 && r.body?.reden === 'iban');
  r = await toestemming(goed);
  check(`toestemming gegeven (200 gegeven, ${toon(r)})`, r.status === 200 && r.body?.status === 'gegeven' && r.body?.avp === true, JSON.stringify(r.body));
  const kindNa = await su.collection('hh_users').getOne(kind.id);
  check('hh_users.ouder_toestemming_op is gezet', !!kindNa.ouder_toestemming_op);
  check('hh_users.ouder_iban_ok = ja', kindNa.ouder_iban_ok === true);
  rij = await rijVan(kind.id);
  check('rij: gegeven, naam, IBAN, AVP, code gewist', rij.status === 'gegeven' && rij.ouder_naam === 'B3check Ouder' && rij.iban === IBAN && rij.avp_verklaard === true && rij.code_hash === '');
  check('na toestemming: helper ziet de open klus', await ziet(kind));
  r = await verzoek(kind.client, '/api/hh/ouder/status', 'GET');
  check(`status voor de helper: gegeven (${toon(r)})`, r.body?.status === 'gegeven');
  r = await verzoek(kind.client, '/api/hh/ouder/versturen', 'POST', {});
  check(`na toestemming geen nieuwe mail (409 algegeven, ${toon(r)})`, r.status === 409 && r.body?.reden === 'algegeven');
  await su.collection(assertHh('hh_users')).update(nietGoedgekeurd.id, { ouder_toestemming_op: isoOver(0) });
  check('met toestemming maar nog niet goedgekeurd door de meldkamer: geen klus', !(await ziet(nietGoedgekeurd)));

  // ---------------------------------------------------------------- F
  kop('F. Intrekken met de link (altijd geldig)');
  r = await codeRoute({ token });
  check(`de link toont "gegeven" en geen nieuwe sessie (${toon(r)})`, r.status === 200 && r.body?.status === 'gegeven' && !r.body?.sessie);
  r = await verzoek(anon, '/api/hh/ouder/intrekken', 'POST', { token });
  check(`intrekken (200 ingetrokken, ${toon(r)})`, r.status === 200 && r.body?.status === 'ingetrokken');
  const kindWeer = await su.collection('hh_users').getOne(kind.id);
  check('ouder_toestemming_op is gewist, ouder_iban_ok nee', !kindWeer.ouder_toestemming_op && kindWeer.ouder_iban_ok === false);
  check('helper ziet de open klus direct niet meer', !(await ziet(kind)));
  r = await verzoek(kind.client, `/api/hh/klussen/${klus.id}/accepteren`);
  check(`na intrekken accepteren geweigerd (403 ouder, ${toon(r)})`, r.status === 403 && r.body?.reden === 'ouder');
  r = await verzoek(anon, '/api/hh/ouder/intrekken', 'POST', { token });
  check(`nog een keer intrekken: zelfde uitkomst (${toon(r)})`, r.status === 200 && r.body?.status === 'ingetrokken');
  r = await verzoek(kind.client, '/api/hh/ouder/status', 'GET');
  check(`status voor de helper: ingetrokken (${toon(r)})`, r.body?.status === 'ingetrokken');

  // ---------------------------------------------------------------- G
  kop('G. API-toegang tot hh_ouder_toestemming');
  for (const [wie, c] of [['helper', kind.client], ['bewoner', bewoner.client], ['anoniem', anon]]) {
    const lijst = await c.collection(COLLECTIE).getList(1, 50);
    check(`${wie} ziet geen enkele rij (lijst leeg)`, lijst.totalItems === 0);
    await magNiet(`${wie} haalt de eigen rij niet los op`, () => c.collection(COLLECTIE).getOne(rij.id));
  }
  const coordLijst = await coord.client.collection(COLLECTIE).getFullList({ filter: `helper = "${kind.id}"` });
  check('coordinator leest de rij', coordLijst.length === 1);
  check('coordinator ziet GEEN code_hash, token_hash of sessie_hash', coordLijst.length === 1 && GEHEIM.every((g) => !(g in coordLijst[0])), JSON.stringify(Object.keys(coordLijst[0] || {})));
  await magNiet('coordinator filtert niet op code_hash', () => coord.client.collection(COLLECTIE).getFullList({ filter: `code_hash != ""` }), [400, 403]);
  await magNiet('helper maakt zelf geen rij', () => kind.client.collection(COLLECTIE).create({ helper: kind.id, ouder_email: ouderMail, status: 'gegeven' }));
  await magNiet('coordinator maakt ook geen rij via de API', () => coord.client.collection(COLLECTIE).create({ helper: kind.id, ouder_email: ouderMail, status: 'gegeven' }));
  await magNiet('coordinator wijzigt geen rij via de API', () => coord.client.collection(COLLECTIE).update(rij.id, { status: 'gegeven' }));
  await magNiet('helper zet ouder_toestemming_op niet zelf (slot B1)', () => kind.client.collection('hh_users').update(kind.id, { ouder_toestemming_op: isoOver(0) }));

  // ---------------------------------------------------------------- H
  kop('H. Opruimen en nameten');
  await opruimen(su);
  const rest = await su.collection('hh_users').getFullList({ filter: su.filter('email ~ {:p}', { p: MAIL_PREFIX }) });
  check('geen tijdelijke accounts meer', rest.length === 0);
  const restRijen = await su.collection(COLLECTIE).getFullList({ filter: su.filter('ouder_email ~ {:p}', { p: MAIL_PREFIX }) });
  check('geen tijdelijke toestemmingsrijen meer', restRijen.length === 0);

  console.log(`\n${groen} groen, ${rood} rood.`);
  if (rood > 0) process.exitCode = 1;
}

main().catch(fail);
