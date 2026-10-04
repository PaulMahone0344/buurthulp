// HeitjeHulp B9 stap 4 — check XP, badges, niveaus, verdiensten, verklaring
// en recensie verbergen tegen een ECHTE PocketBase (lokaal of prod).
//
// Zonder --apply: alleen lezen (collecties, velden, rules, sloten, routes).
// Met --apply: tijdelijke accounts b9check-...@heitjehulp.invalid (nooit
// mail) en eigen klussen "[b9check]". Klussen maakt de SUPERUSER meteen op
// "geaccepteerd" met een toegewezen helper: geen logregel naar open, dus geen
// "nieuwe klus"-melding voor echte helpers. Alleen sectie L plaatst één klus
// als bewoner (met foto, als superuser goedgekeurd: ook geen melding) om
// KiesHelper te bewijzen. Alles wordt aan het eind opgeruimd en nagemeten.
//   C afronden via de statusroute -> beloning (+75, eerste klus) + melding
//   D herboeking (zelfde bewoner) -> +125 en badge "Weer gevraagd"
//   E beoordeling 5 -> +30; 4 -> tegenboeking -15; weer 5 -> +15
//   F klus van afgerond af (superuser) -> tegenboeking; terug -> erbij
//   G niveau-overgang naar Ervaren + badge 5 klussen + melding
//   H rules en sloten (niemand zet XP/niveau/verborgen via de API)
//   I GET /api/hh/xp/mijn (overzicht, verdiensten, vertrouwen, recensies)
//   J recensie verbergen (meldkamer) -> sterren/XP/recensies; terugzetten
//   K verklaring van inzet + publieke controle met de code
//   L KiesHelper: echt niveau + "Nieuw in de buurt"
//   M naberekenen (alleen superuser; hier ALLEEN droog: echt naberekenen
//     raakt echte helpers = script 144 met eigen JA)
//   N opruimen en nameten
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/142-b9check.mjs            (dry-run, alleen lezen)
//   node scripts/142-b9check.mjs --apply
//   node scripts/142-b9check.mjs --apply --alleen-opruimen

import { randomBytes } from 'node:crypto';
import { superuserClient, userClient, anonClient, assertHh, APPLY, fail, PB_URL } from './_lib.mjs';
import { NIEUWE_COLLECTIES, MELDING_SOORT_BELONING, extraVelden } from './140-b9-xp.mjs';
import { NIEUWE_RULES, SLOTEN } from './141-b9-rules.mjs';
import { REGIO_WIJK } from './81-b2-werkgebied.mjs';

const MAIL_PREFIX = 'b9check-';
const MAIL_DOMEIN = '@heitjehulp.invalid';
const MERK = '[b9check]';
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
async function magNiet(label, fn, codes = [400, 403, 404]) {
  try {
    await fn();
    check(label, false, 'verzoek is onterecht gelukt');
  } catch (e) {
    check(`${label} (${e?.status})`, codes.includes(e?.status), `status=${e?.status} ${e?.response?.message ?? ''}`);
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
const dagenGeleden = (n, uur = 10) => {
  const d = new Date(Date.now() - n * 24 * 3600 * 1000);
  d.setUTCHours(uur, 0, 0, 0);
  return d.toISOString();
};

async function opruimen(su) {
  const accounts = await su.collection('hh_users').getFullList({ filter: su.filter('email ~ {:p}', { p: MAIL_PREFIX }) });
  let aantal = 0;
  const weg = async (col, filter, params) => {
    const rijen = await su.collection(col).getFullList({ filter: su.filter(filter, params) });
    for (const r of rijen) await su.collection(assertHh(col)).delete(r.id);
    return rijen.length;
  };
  for (const u of accounts) {
    const klussen = await su.collection('hh_klussen').getFullList({
      filter: su.filter('hulpvrager = {:id} || geplaatst_door = {:id} || toegewezen_jongere = {:id}', { id: u.id }),
    });
    for (const k of klussen) {
      aantal += await weg('hh_meldingen', 'klus = {:id}', { id: k.id });
      aantal += await weg('hh_beoordelingen', 'klus = {:id}', { id: k.id });
      aantal += await weg('hh_incidenten', 'klus = {:id}', { id: k.id });
      await su.collection(assertHh('hh_klussen')).delete(k.id);
      aantal++;
    }
  }
  for (const u of accounts) {
    aantal += await weg('hh_meldingen', 'ontvanger = {:id}', { id: u.id });
    aantal += await weg('hh_incidenten', 'melder = {:id}', { id: u.id });
    aantal += await weg('hh_beoordelingen', 'van_gebruiker = {:id} || naar_gebruiker = {:id}', { id: u.id });
    const profielen = await su.collection('hh_profielen').getFullList({ filter: su.filter('gebruiker = {:id}', { id: u.id }) });
    for (const id of [u.id, ...profielen.map((p) => p.id)]) aantal += await weg('hh_auditlog', 'door = {:id} || doel_id = {:id}', { id });
  }
  // hh_xp, hh_badges en hh_verklaringen gaan mee met het account (cascade).
  for (const u of accounts) await su.collection(assertHh('hh_users')).delete(u.id);
  aantal += accounts.length;
  if (aantal) console.log(`  ↻ ${aantal} record(s) verwijderd (waarvan ${accounts.length} tijdelijk(e) account(s))`);
}

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
    check(`${def.naam} bestaat`, !!col, 'draai 140 --apply');
    if (!col) continue;
    for (const idx of def.indexen) check(`  index: ${idx.replace(/^CREATE (UNIQUE )?INDEX \S+ ON /, '')}`, (col.indexes || []).some((i) => norm(i) === norm(idx)));
    const zelfde = ['listRule', 'viewRule', 'createRule', 'updateRule', 'deleteRule'].every((k) => (col[k] ?? null) === (NIEUWE_RULES[k] ?? null));
    check('  rules gelijk aan 141', zelfde, 'draai 141 --apply');
  }
  const ids = {};
  for (const n of ['hh_users', 'hh_klussen', 'hh_beoordelingen']) ids[n] = (await su.collections.getOne(n)).id;
  for (const [naam, velden] of Object.entries(extraVelden(ids))) {
    const c = await su.collections.getOne(naam);
    const mist = velden.filter((v) => !c.fields.some((f) => f.name === v.name)).map((v) => v.name);
    check(`${naam}: B9-velden bestaan`, !mist.length, `ontbreekt: ${mist.join(', ')}`);
  }
  for (const s of SLOTEN) {
    const c = await su.collections.getOne(s.naam);
    const ok = ['createRule', 'updateRule'].every((k) => c[k] === null || String(c[k]).includes(s.slot));
    check(`${s.naam}: B9-slot op create/update`, ok, 'draai 141 --apply');
  }
  const soort = (await su.collections.getOne('hh_meldingen')).fields.find((f) => f.name === 'soort');
  check(`hh_meldingen.soort kent "${MELDING_SOORT_BELONING}"`, !!soort?.values?.includes(MELDING_SOORT_BELONING));
  const anon = anonClient();
  const r1 = await route(anon, '/api/hh/xp/mijn', {}, 'GET');
  check(`route xp/mijn bestaat (anoniem 401, kreeg ${r1.status})`, r1.status === 401, 'draai 143-hook-deploy.sh');
  const r2 = await route(anon, '/api/hh/verklaring/ZZZZZ-ZZZZZ', {}, 'GET');
  check(`route verklaring/{code} bestaat (onbekend 404, kreeg ${r2.status})`, r2.status === 404);
  const r3 = await route(anon, '/api/hh/xp/naberekenen', { droog: true });
  check(`route naberekenen dicht voor anoniem (401, kreeg ${r3.status})`, r3.status === 401);
  const regio = (await su.collection('hh_wijken').getFullList({ filter: su.filter('wijk = {:w}', { w: REGIO_WIJK.wijk }) }))[0];
  check(`wijk "${REGIO_WIJK.wijk}" bestaat`, !!regio);
  return regio;
}

async function main() {
  for (const c of ['hh_users', 'hh_profielen', 'hh_klussen', 'hh_beoordelingen', 'hh_xp', 'hh_badges', 'hh_verklaringen']) assertHh(c);
  const su = await superuserClient();
  console.log('Verbonden met', PB_URL, APPLY ? '(APPLY)' : '(DRY-RUN)', '\n');
  if (!APPLY) {
    console.log('DRY-RUN: er wordt NIETS geschreven.');
    await voorwaarden(su);
    console.log('\nWat --apply ZOU doen:');
    console.log(`  · tijdelijke accounts (${MAIL_PREFIX}...${MAIL_DOMEIN}): coordinator, 2 bewoners, 2 helpers;`);
    console.log('  · ±8 eigen klussen, door de superuser meteen op geaccepteerd (geen "nieuwe klus"-meldingen);');
    console.log('  · één klus als bewoner geplaatst en als superuser goedgekeurd (KiesHelper), ook zonder melding;');
    console.log('  · afronden, beoordelen, verbergen, verklaring; naberekenen ALLEEN droog;');
    console.log('  · alles opruimen en nameten.');
    console.log(`\n${groen} groen, ${rood} rood (leescontroles).`);
    if (rood > 0) console.log('Rood is verwacht zolang 140, 141 en 143 nog niet uitgerold zijn.');
    return;
  }
  kop('A. Opruimen van een eerdere run');
  await opruimen(su);
  if (ALLEEN_OPRUIMEN) {
    console.log('\nAlleen opgeruimd.');
    return;
  }
  const regio = await voorwaarden(su);
  const types = await su.collection('hh_klustypes').getFullList();
  const licht = types.find((t) => t.naam === 'Boodschappen');
  if (!regio || !licht) {
    console.log('\nZonder regio-wijk en categorie Boodschappen kan de check niet verder.');
    process.exitCode = 1;
    return;
  }
  try {
    await secties(su, regio, licht);
  } finally {
    kop('N. Opruimen en nameten');
    await opruimen(su);
    const rest = await su.collection('hh_users').getFullList({ filter: su.filter('email ~ {:p}', { p: MAIL_PREFIX }) });
    check('geen tijdelijke accounts meer', rest.length === 0, `${rest.length} over`);
    const klussen = await su.collection('hh_klussen').getFullList({ filter: su.filter('omschrijving ~ {:m}', { m: MERK }) });
    check('geen [b9check]-klussen meer', klussen.length === 0, `${klussen.length} over`);
    console.log(`\n${groen} groen, ${rood} rood.`);
    if (rood > 0) process.exitCode = 1;
  }
}

async function secties(su, regio, licht) {
  const wachtwoord = randomBytes(18).toString('base64url');
  async function account(label, rol, extra = {}) {
    const email = `${MAIL_PREFIX}${label.toLowerCase()}-${randomBytes(4).toString('hex')}${MAIL_DOMEIN}`;
    const record = await su.collection(assertHh('hh_users')).create({
      email, password: wachtwoord, passwordConfirm: wachtwoord, verified: true, rol, naam: `${label} ${MERK}`, taal: 'nl', ...extra,
    });
    return { id: record.id, email, client: await userClient(email, wachtwoord) };
  }
  async function helper(label) {
    const h = await account(label, 'jongere', { geboortedatum: '1999-05-05 00:00:00.000Z', wijk: regio.id });
    const p = await su.collection(assertHh('hh_profielen')).create({ gebruiker: h.id, verificatiestatus: 'goedgekeurd', vog_gezien_op: nu() });
    await su.collection('hh_profielen').update(p.id, { id_gecontroleerd_op: nu() });
    return { ...h, profiel: p.id };
  }
  const coord = await account('Meldkamer', 'coordinator');
  const anja = await account('Anja', 'hulpvrager', { wijk: regio.id, adres: 'Teststraat 1', plaats: 'Tiel' });
  const kees = await account('Kees', 'hulpvrager', { wijk: regio.id, adres: 'Teststraat 2', plaats: 'Tiel' });
  const ruud = await helper('Ruud');
  const sanne = await helper('Sanne');

  let teller = 0;
  /// Superuser: klus meteen geaccepteerd met helper (geen logregel naar open).
  const klusVoor = (bewoner, h, dagen) =>
    su.collection(assertHh('hh_klussen')).create({
      hulpvrager: bewoner.id, geplaatst_door: bewoner.id, klustype: licht.id, bron: 'telefoon',
      omschrijving: `${MERK} klus ${++teller}`, adres: 'Teststraat 1, 4001 MA Tiel', lat: 51.88, lon: 5.42,
      wanneer_van: dagenGeleden(dagen, 10), wanneer_tot: dagenGeleden(dagen, 11),
      status: 'geaccepteerd', toegewezen_jongere: h.id, vergoeding_jongere: 10, bedrag_bruto: 10, klus_goedgekeurd_op: nu(),
    });
  const stap = (h, k, naar) => route(h.client, `/api/hh/klussen/${k.id}/status`, { naar });
  async function rondAf(h, k) {
    await stap(h, k, 'onderweg');
    await stap(h, k, 'bezig');
    return stap(h, k, 'afgerond');
  }
  const profiel = (h) => su.collection('hh_profielen').getOne(h.profiel);
  const xpRijen = (h) => su.collection('hh_xp').getFullList({ filter: su.filter('helper = {:h}', { h: h.id }), sort: 'created' });
  const beloningen = (h) => su.collection('hh_meldingen').getFullList({ filter: su.filter('ontvanger = {:o} && soort = "beloning"', { o: h.id }), sort: 'created' });

  // ---------------------------------------------------------------- C
  kop('C. Klus afronden via de statusroute -> beloning');
  const k1 = await klusVoor(anja, ruud, 9);
  let r = await rondAf(ruud, k1);
  const b = r.body?.beloning;
  check(`afgerond -> 200 met beloning (kreeg ${r.status})`, r.status === 200 && !!b, JSON.stringify(r.body));
  check(`  +75 XP (klaar 50 + eerste klus 25), kreeg ${b?.xp_erbij}`, b?.xp_erbij === 75 && b?.totaal === 75);
  check('  niveau Nieuw, niet omhoog', b?.niveau?.code === 'nieuw' && b?.niveau_omhoog === false);
  check('  nieuwe badge "Eerste klus" met icoon', b?.nieuwe_badges?.length === 1 && b.nieuwe_badges[0].code === 'eerste_klus' && !!b.nieuwe_badges[0].icoon, JSON.stringify(b?.nieuwe_badges));
  let rijen = await xpRijen(ruud);
  check('  2 boekingen in hh_xp (klus_klaar 50, eerste_klus 25)', JSON.stringify(rijen.map((x) => [x.soort, x.punten]).sort()) === JSON.stringify([['eerste_klus', 25], ['klus_klaar', 50]]));
  let p = await profiel(ruud);
  check(`  profiel xp_totaal 75, niveau nieuw (kreeg ${p.xp_totaal}, ${p.niveau})`, p.xp_totaal === 75 && p.niveau === 'nieuw');
  let m = await beloningen(ruud);
  check('  één melding "+75 XP · Nieuwe badge: Eerste klus"', m.length === 1 && m[0].tekst === '+75 XP · Nieuwe badge: Eerste klus' && m[0].klus === k1.id, JSON.stringify(m.map((x) => x.tekst)));
  r = await stap(ruud, k1, 'afgerond');
  check(`nog eens afronden -> 409 (kreeg ${r.status}), niets dubbel`, r.status === 409 && (await xpRijen(ruud)).length === 2);

  // ---------------------------------------------------------------- D
  kop('D. Herboeking: zelfde bewoner koos dezelfde helper opnieuw');
  const k2 = await klusVoor(anja, ruud, 8);
  r = await rondAf(ruud, k2);
  check(`+125 XP (klaar 50 + herboeking 75), kreeg ${r.body?.beloning?.xp_erbij}`, r.body?.beloning?.xp_erbij === 125 && r.body?.beloning?.totaal === 200);
  check('  badge "Weer gevraagd"', (r.body?.beloning?.nieuwe_badges || []).some((x) => x.code === 'herboekt'));

  // ---------------------------------------------------------------- E
  kop('E. Beoordeling door de bewoner');
  const o1 = await anja.client.collection('hh_beoordelingen').create({
    klus: k1.id, van_gebruiker: anja.id, naar_gebruiker: ruud.id, sterren: 5, tekst: 'Heel fijn geholpen, dank je!', alles_in_orde: 'ja',
  });
  p = await profiel(ruud);
  check(`5 sterren -> +30, totaal 230 (kreeg ${p.xp_totaal})`, p.xp_totaal === 230);
  m = await beloningen(ruud);
  check('  melding "+30 XP"', m.some((x) => x.tekst === '+30 XP'), JSON.stringify(m.map((x) => x.tekst)));
  await anja.client.collection('hh_beoordelingen').update(o1.id, { sterren: 4 });
  rijen = await xpRijen(ruud);
  const laatste = rijen[rijen.length - 1];
  check(`naar 4 sterren -> tegenboeking -15 (kreeg ${laatste.soort} ${laatste.punten}), totaal 215`, laatste.soort === 'tegenboeking' && laatste.punten === -15 && (await profiel(ruud)).xp_totaal === 215);
  await anja.client.collection('hh_beoordelingen').update(o1.id, { sterren: 5 });
  check('weer 5 sterren -> +15, totaal 230', (await profiel(ruud)).xp_totaal === 230);
  check('  geen enkele hh_xp-rij gewist (herleidbaar)', (await xpRijen(ruud)).length === 7);

  // ---------------------------------------------------------------- F
  kop('F. Klus van afgerond af (superuser) en terug');
  await su.collection('hh_klussen').update(k2.id, { status: 'probleem' });
  check('k2 op probleem -> -125, totaal 105', (await profiel(ruud)).xp_totaal === 105);
  await su.collection('hh_klussen').update(k2.id, { status: 'afgerond' });
  check('k2 weer afgerond -> +125, totaal 230', (await profiel(ruud)).xp_totaal === 230);
  const badgesRuud = await su.collection('hh_badges').getFullList({ filter: su.filter('helper = {:h}', { h: ruud.id }) });
  check('  badges niet dubbel en niet weg (eerste_klus, herboekt)', JSON.stringify(badgesRuud.map((x) => x.code).sort()) === JSON.stringify(['eerste_klus', 'herboekt']));

  // ---------------------------------------------------------------- G
  kop('G. Niveau-overgang naar Ervaren');
  for (const dagen of [7, 6]) {
    const k = await klusVoor(anja, ruud, dagen);
    await su.collection('hh_klussen').update(k.id, { status: 'afgerond' });
  }
  const k5 = await klusVoor(anja, ruud, 5);
  r = await rondAf(ruud, k5);
  // 5 klussen: 5x50 + 25 + 4x75 herboeking + 30 = 605
  check(`5e klus -> totaal 605, niveau Ervaren, omhoog (kreeg ${r.body?.beloning?.totaal} ${r.body?.beloning?.niveau?.code})`, r.body?.beloning?.totaal === 605 && r.body?.beloning?.niveau?.code === 'ervaren' && r.body?.beloning?.niveau_omhoog === true);
  check('  badge "5 klussen"', (r.body?.beloning?.nieuwe_badges || []).some((x) => x.code === 'vijf_klussen'));
  m = await beloningen(ruud);
  check('  melding "Nieuw niveau: Ervaren"', m.some((x) => x.titel === 'Nieuw niveau: Ervaren' && /Je bent nu Ervaren!/.test(x.tekst)), JSON.stringify(m.map((x) => x.titel)));
  check(`  profiel niveau ervaren`, (await profiel(ruud)).niveau === 'ervaren');

  // ---------------------------------------------------------------- H
  kop('H. Rules en sloten');
  await magNiet('helper zet eigen xp_totaal', () => ruud.client.collection('hh_profielen').update(ruud.profiel, { xp_totaal: 99999 }));
  await magNiet('helper zet eigen niveau', () => ruud.client.collection('hh_profielen').update(ruud.profiel, { niveau: 'top' }));
  await magNiet('helper zet eigen idin_geverifieerd_op', () => ruud.client.collection('hh_profielen').update(ruud.profiel, { idin_geverifieerd_op: nu() }));
  await magNiet('coordinator zet xp_totaal ook niet (alleen de hook)', () => coord.client.collection('hh_profielen').update(ruud.profiel, { xp_totaal: 1 }));
  check('  xp_totaal nog steeds 605', (await profiel(ruud)).xp_totaal === 605);
  await magNiet('bewoner verbergt zelf zijn beoordeling via de API', () => anja.client.collection('hh_beoordelingen').update(o1.id, { verborgen_op: nu() }));
  await magNiet('coordinator verbergt via de API (moet via de route)', () => coord.client.collection('hh_beoordelingen').update(o1.id, { verborgen_reden: 'x' }));
  await magNiet('helper maakt zelf XP', () => ruud.client.collection('hh_xp').create({ helper: ruud.id, bron: 'nep', soort: 'klus_klaar', punten: 500, sleutel: 'nep#1' }));
  await magNiet('helper maakt zelf een badge', () => ruud.client.collection('hh_badges').create({ helper: ruud.id, code: 'tien_klussen', behaald_op: nu() }));
  const eigen = await ruud.client.collection('hh_xp').getFullList();
  check(`helper leest zijn eigen XP (${eigen.length} rijen)`, eigen.length > 0 && eigen.every((x) => x.helper === ruud.id));
  check('andere helper leest niets van Ruud', (await sanne.client.collection('hh_xp').getFullList({ filter: `helper = "${ruud.id}"` })).length === 0);
  check('bewoner leest geen XP', (await anja.client.collection('hh_xp').getFullList()).length === 0);
  check('bewoner leest geen badges', (await anja.client.collection('hh_badges').getFullList()).length === 0);
  check('coordinator leest de XP van Ruud', (await coord.client.collection('hh_xp').getFullList({ filter: `helper = "${ruud.id}"` })).length === eigen.length);
  check('anoniem leest geen XP', (await anonClient().collection('hh_xp').getFullList().catch(() => [])).length === 0);

  // ---------------------------------------------------------------- I
  kop('I. Overzicht GET /api/hh/xp/mijn');
  r = await route(ruud.client, '/api/hh/xp/mijn', {}, 'GET');
  const o = r.body;
  check(`200 met xp_totaal 605 en niveau Ervaren (kreeg ${r.status})`, r.status === 200 && o.xp_totaal === 605 && o.niveau?.naam === 'Ervaren');
  check(`  volgend niveau Top (${o.volgend?.xp_nodig} XP en ${o.volgend?.klussen_nodig} klussen te gaan)`, o.volgend?.code === 'top' && o.volgend?.xp_nodig === 395 && o.volgend?.klussen_nodig === 10);
  check('  7 badges, 3 behaald met datum', o.badges?.length === 7 && o.badges.filter((x) => x.behaald_op).length === 3);
  check('  vertrouwen: VOG (geldig 3 jaar) en ID met datum', JSON.stringify(o.vertrouwen?.map((v) => [v.code, v.verlopen])) === JSON.stringify([['vog', false], ['id_gecontroleerd', false]]), JSON.stringify(o.vertrouwen));
  const somMaanden = (o.verdiensten?.maanden || []).reduce((s, x) => s + x.bedrag, 0);
  check(`  verdiensten: 5 klussen x 10 = 50 (maanden ${somMaanden}, totaal ${o.verdiensten?.totaal})`, somMaanden === 50 && o.verdiensten?.totaal === 50 && o.verdiensten?.jaren?.[0]?.klussen === 5);
  check('  recensie zichtbaar met voornaam bewoner', o.recensies?.length === 1 && o.recensies[0].voornaam === 'Anja' && o.recensies[0].sterren === 5);
  check('  nooit achternaam of [b9check] van de bewoner', !JSON.stringify(o.recensies).includes(MERK));
  r = await route(anja.client, '/api/hh/xp/mijn', {}, 'GET');
  check(`bewoner -> 403 (kreeg ${r.status})`, r.status === 403);

  // ---------------------------------------------------------------- J
  kop('J. Recensie verbergen (meldkamer)');
  r = await route(anja.client, `/api/hh/beoordelingen/${o1.id}/verbergen`, { verborgen: true });
  check(`bewoner -> 403 (kreeg ${r.status})`, r.status === 403);
  r = await route(coord.client, `/api/hh/beoordelingen/${o1.id}/verbergen`, { verborgen: true, reden: 'Bevat een telefoonnummer' });
  check(`meldkamer -> 200 verborgen (kreeg ${r.status})`, r.status === 200 && r.body?.verborgen === true);
  p = await profiel(ruud);
  check(`  sterren 0 (enige beoordeling verborgen), XP -30 -> 575 (kreeg ${p.sterren_gemiddeld}, ${p.xp_totaal})`, p.sterren_gemiddeld === 0 && p.xp_totaal === 575);
  r = await route(ruud.client, '/api/hh/xp/mijn', {}, 'GET');
  check('  geen recensie meer in het overzicht', r.body?.recensies?.length === 0);
  const helperZiet = await ruud.client.collection('hh_beoordelingen').getOne(o1.id);
  check('  helper ziet verborgen_reden/verborgen_door niet', helperZiet.verborgen_reden === undefined && helperZiet.verborgen_door === undefined);
  const coordZiet = await coord.client.collection('hh_beoordelingen').getOne(o1.id);
  check('  meldkamer ziet reden + door', coordZiet.verborgen_reden === 'Bevat een telefoonnummer' && coordZiet.verborgen_door === coord.id);
  r = await route(coord.client, `/api/hh/beoordelingen/${o1.id}/verbergen`, { verborgen: false });
  p = await profiel(ruud);
  check(`terugzetten -> sterren 5, XP 605 (kreeg ${p.sterren_gemiddeld}, ${p.xp_totaal})`, r.status === 200 && p.sterren_gemiddeld === 5 && p.xp_totaal === 605);

  // ---------------------------------------------------------------- K
  kop('K. Verklaring van inzet');
  r = await route(ruud.client, '/api/hh/xp/verklaring');
  const v = r.body;
  check(`helper -> 200 met code XXXXX-XXXXX (kreeg ${r.status} ${v?.code})`, r.status === 200 && /^[A-Z2-9]{5}-[A-Z2-9]{5}$/.test(v?.code ?? ''));
  check('  gegevens: voornaam Ruud, 5 klussen, 5 uur, niveau Ervaren', v?.gegevens?.voornaam === 'Ruud' && v.gegevens.klussen === 5 && v.gegevens.uren === 5 && v.gegevens.niveau === 'Ervaren', JSON.stringify(v?.gegevens));
  check('  badges en vertrouwen met datum', v?.gegevens?.badges?.length === 3 && v.gegevens.vertrouwen?.length === 2);
  const v2 = await route(ruud.client, '/api/hh/xp/verklaring');
  check('nog eens -> zelfde code (niets veranderd)', v2.body?.code === v?.code);
  const pub = await route(anonClient(), `/api/hh/verklaring/${encodeURIComponent((v?.code ?? '').toLowerCase())}`, {}, 'GET');
  check(`publiek opzoeken (kleine letters mag) -> 200 Ruud (kreeg ${pub.status})`, pub.status === 200 && pub.body?.gegevens?.voornaam === 'Ruud' && pub.body?.code === v?.code);
  check('  geen achternaam, e-mail of id op de verklaring', !JSON.stringify(pub.body).includes(MERK) && !JSON.stringify(pub.body).includes(MAIL_DOMEIN) && !JSON.stringify(pub.body).includes(ruud.id));
  r = await route(anja.client, '/api/hh/xp/verklaring');
  check(`bewoner -> 403 (kreeg ${r.status})`, r.status === 403);
  await magNiet('helper maakt zelf een verklaring via de API', () => ruud.client.collection('hh_verklaringen').create({ helper: ruud.id, code: 'AAAAA-AAAAA', gegevens: {} }));

  // ---------------------------------------------------------------- L
  kop('L. KiesHelper: echt niveau en "Nieuw in de buurt"');
  const open = await kees.client.collection('hh_klussen').create({
    hulpvrager: kees.id, geplaatst_door: kees.id, bron: 'app', status: 'open', klustype: licht.id,
    omschrijving: `${MERK} Boodschappen halen.`, adres: 'Teststraat 2, 4001 MA Tiel', lat: 51.88, lon: 5.42,
    wanneer_van: new Date(Date.now() + 2 * 24 * 3600 * 1000).toISOString(), nee_lijst_akkoord: true, foto: png(),
  });
  await su.collection('hh_klussen').update(open.id, { klus_goedgekeurd_op: nu() });
  const ra = await route(ruud.client, `/api/hh/klussen/${open.id}/reageren`, {});
  const rb = await route(sanne.client, `/api/hh/klussen/${open.id}/reageren`, {});
  check(`twee helpers reageren (kreeg ${ra.status}/${rb.status})`, ra.status === 200 && rb.status === 200, JSON.stringify([ra.body, rb.body]));
  r = await route(kees.client, `/api/hh/klussen/${open.id}/reacties`, {}, 'GET');
  const kaart = (h) => (r.body?.reacties || []).find((x) => x.helper === h.id);
  check(`Ruud: niveau Ervaren, niet nieuw in de buurt (kreeg ${kaart(ruud)?.niveau})`, kaart(ruud)?.niveau === 'Ervaren' && kaart(ruud)?.nieuw_in_de_buurt === false);
  check(`Sanne: Nieuw + "Nieuw in de buurt" (kreeg ${kaart(sanne)?.niveau}, ${kaart(sanne)?.nieuw_in_de_buurt})`, kaart(sanne)?.niveau === 'Nieuw' && kaart(sanne)?.nieuw_in_de_buurt === true);
  check('  Ruud: laatste recensie zichtbaar', kaart(ruud)?.laatste_recensie === 'Heel fijn geholpen, dank je!');

  // ---------------------------------------------------------------- M
  kop('M. Naberekenen (alleen superuser, hier ALLEEN droog)');
  r = await route(ruud.client, '/api/hh/xp/naberekenen', { droog: true });
  check(`helper -> 401/403 (kreeg ${r.status})`, r.status === 401 || r.status === 403);
  const voor = (await su.collection('hh_xp').getList(1, 1)).totalItems;
  r = await route(su, '/api/hh/xp/naberekenen', { droog: true });
  const na = (await su.collection('hh_xp').getList(1, 1)).totalItems;
  check(`superuser droog -> 200, droog=true, niets geschreven (${voor} -> ${na})`, r.status === 200 && r.body?.droog === true && voor === na);
  check('  Ruud staat er niet in (al bijgewerkt)', !(r.body?.helpers || []).some((x) => x.helper === ruud.id));
  console.log(`  · droog zou ${r.body?.helpers?.length ?? '?'} andere helper(s) bijwerken (script 144 toont wie)`);
}

main().catch(fail);
