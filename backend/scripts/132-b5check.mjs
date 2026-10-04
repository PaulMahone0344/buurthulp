// HeitjeHulp B5 — bewijst reageren en kiezen (130 velden, 131 rules, 133
// hooks) op de ECHTE server. Werkt alleen met EIGEN tijdelijke accounts
// ("b5check-...@heitjehulp.invalid": nooit mail) en eigen klussen, en ruimt
// alles op (ook bij een eerdere, gecrashte run). Seed-accounts doen niet mee.
//
//   A. opruimen van een eerdere run
//   B. voorwaarden (ook in dry-run, alleen lezen): collectie, velden, index,
//      rules letterlijk gelijk aan 131, soort "reactie", routes bestaan
//   C. reageren 18+: klus blijft open, bewoner krijgt één gebundelde melding,
//      berichtje gefilterd, nog eens 409; wie ziet welke reactie (rules)
//   D. reageren: dezelfde weigeringen als accepteren
//   E. helper < 18: wacht op de ouder; ouder-pagina (wat/waar zonder
//      huisnummer/wanneer/voornaam); "Goed" -> bewoner ziet hem; "Liever
//      niet" -> afgewezen; verloopt als de klus begint
//   F. eerste klus bij een nieuwe bewoner: 10-12 jaar vinkje verplicht
//   G. KiesHelper: voornaam, leeftijd, niveau, sterren, ID, nooit achternaam/
//      geboortedatum/adres; vreemden 403
//   H. kiezen = match: klus geaccepteerd + helper, logregel, meldingen
//      ("Het is een match!" / "koos iemand anders"), adres exact, chat open
//   I. RACE: 2 klikken van dezelfde bewoner tegelijk (20 ronden)
//   J. RACE: dezelfde helper voor 2 klussen op hetzelfde moment (20 ronden)
//   K. intrekken, teruggeven, koppelen door de meldkamer, annuleren
//   L. beoordelen van twee kanten + geheime vraag (nee -> signaal, geen alarm)
//   M. "Ik kan nu helpen": schakelaar, aantal voor de bewoner, veld dicht
//   N. de schakelaars in hh_instellingen. Wat op de server al staat, blijft
//      leidend; wat de check tijdelijk aanzet (ook onder 18 in E t/m K), zet
//      hij aan het eind precies terug (sectie O meet het na)
//   O. opruimen en nameten
//
// LET OP OP PROD: sectie L maakt KORT een signaal (incident soort signaal;
// geen melding aan de coordinatoren, wel even in de lijst van het paneel). Sectie N keurt een eigen klus:
// helpers in de wijk met "Ik kan nu helpen" aan krijgen even een "nieuwe
// klus" (opgeruimd). De publieke ouder-route telt 30 per IP per uur: niet
// twee keer binnen een uur draaien.
//
// DRAAIEN (na 130 --apply, 131 --apply, 133-hook-deploy.sh):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/132-b5check.mjs            (dry-run: alleen leescontroles)
//   node scripts/132-b5check.mjs --apply
//   node scripts/132-b5check.mjs --apply --alleen-opruimen

import { randomBytes, createHash } from 'node:crypto';
import { superuserClient, userClient, anonClient, assertHh, APPLY, fail, PB_URL } from './_lib.mjs';
import { COLLECTIE, REACTIE_STATUSSEN, EXTRA_VELDEN, MELDING_SOORT_REACTIE, REACTIE_INDEXEN, INCIDENT_SOORT_SIGNAAL } from './130-b5-reacties.mjs';
import { REACTIE_RULES } from './131-b5-rules.mjs';
import { plaatsHulp } from './100-b4-velden.mjs';
import { REGIO_WIJK } from './81-b2-werkgebied.mjs';

const MAIL_PREFIX = 'b5check-';
const MAIL_DOMEIN = '@heitjehulp.invalid';
const MERK = '[b5check]';
const ALLEEN_OPRUIMEN = process.argv.includes('--alleen-opruimen');
const RONDEN = 20;
const SCHAKELAARS = ['b5_accepteren_dicht', 'b5_nieuwe_klus_alleen_beschikbaar', 'b5_onder18_reageren_open'];

// Schakelaars die de check tijdelijk aanzet (en daarna precies terugzet):
// { sleutel, id, oud } met oud = undefined (rij bestond niet) of de oude waarde.
const tijdelijk = [];
async function zetTijdelijk(su, sleutel) {
  const rij = (await su.collection('hh_instellingen').getFullList({ filter: su.filter('sleutel = {:s}', { s: sleutel }) }))[0];
  if (rij) {
    tijdelijk.push({ sleutel, id: rij.id, oud: rij.waarde });
    await su.collection(assertHh('hh_instellingen')).update(rij.id, { waarde: true });
  } else {
    const nieuw = await su.collection(assertHh('hh_instellingen')).create({ sleutel, waarde: true });
    tijdelijk.push({ sleutel, id: nieuw.id, oud: undefined });
  }
}
async function herstelTijdelijk(su, sleutel) {
  for (let i = tijdelijk.length - 1; i >= 0; i--) {
    const t = tijdelijk[i];
    if (sleutel && t.sleutel !== sleutel) continue;
    if (t.oud === undefined) await su.collection(assertHh('hh_instellingen')).delete(t.id).catch(() => {});
    else await su.collection(assertHh('hh_instellingen')).update(t.id, { waarde: t.oud }).catch(() => {});
    tijdelijk.splice(i, 1);
  }
}

const PNG_1X1 = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
  'base64',
);
const png = () => new File([PNG_1X1], 'klus.png', { type: 'image/png' });

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
const sla = (label) => {
  overgeslagen++;
  console.log(`  - overgeslagen: ${label}`);
};
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
async function route(client, pad, body = {}, method = 'POST') {
  try {
    return { status: 200, body: await client.send(pad, method === 'GET' ? { method } : { method, body }) };
  } catch (e) {
    return { status: e?.status ?? 0, body: e?.response ?? {} };
  }
}
const sha256 = (t) => createHash('sha256').update(t).digest('hex');
const nu = () => new Date().toISOString().replace('T', ' ');

/// Geboortedatum van iemand die op [opDag] ("YYYY-MM-DD") [jaren] oud is.
function geboren(jaren, opDag) {
  const [j, m, d] = opDag.split('-').map(Number);
  return `${j - jaren}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')} 00:00:00.000Z`;
}

/// Over [dagen] dagen in Nederland: { datum, om(uur, minuut) -> ISO in UTC }.
function dagOver(dagen) {
  const dag = plaatsHulp.nlTijd(new Date(Date.now() + dagen * 24 * 3600 * 1000).toISOString()).datum;
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
      aantal += await weg('hh_beoordelingen', 'klus = {:id}', { id: k.id });
      aantal += await weg('hh_incidenten', 'klus = {:id}', { id: k.id });
      await su.collection(assertHh('hh_klussen')).delete(k.id); // logregels, reacties en berichten gaan mee
      aantal++;
    }
  }
  for (const u of tijdelijk) {
    aantal += await weg('hh_meldingen', 'ontvanger = {:id}', { id: u.id });
    aantal += await weg('hh_incidenten', 'melder = {:id}', { id: u.id });
    aantal += await weg('hh_beoordelingen', 'van_gebruiker = {:id} || naar_gebruiker = {:id}', { id: u.id });
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
  let col = null;
  try {
    col = await su.collections.getOne(COLLECTIE);
  } catch (_) {
    col = null;
  }
  check(`${COLLECTIE} bestaat`, !!col, 'draai 130 --apply');
  if (col) {
    const veld = (n) => col.fields.find((f) => f.name === n);
    check('  status kent de 6 statussen', JSON.stringify(veld('status')?.values) === JSON.stringify(REACTIE_STATUSSEN));
    check('  bericht max 200', veld('bericht')?.max === 200);
    check('  token_hash is hidden', veld('token_hash')?.hidden === true);
    const norm = (s) => s.replace(/[`"]/g, '').replace(/\s+/g, ' ').trim();
    check('  unieke index (klus, helper)', (col.indexes || []).some((i) => norm(i) === norm(REACTIE_INDEXEN[0])), JSON.stringify(col.indexes));
    for (const k of ['listRule', 'viewRule', 'createRule', 'updateRule', 'deleteRule']) {
      check(`  ${k} gelijk aan 131`, (col[k] ?? null) === (REACTIE_RULES[k] ?? null), 'draai 131 --apply');
    }
  }
  for (const [naam, velden] of Object.entries(EXTRA_VELDEN)) {
    const c = await su.collections.getOne(naam);
    const mist = velden.filter((v) => !c.fields.some((f) => f.name === v.name)).map((v) => v.name);
    check(`${naam}: B5-velden bestaan`, !mist.length, `ontbreekt: ${mist.join(', ')} — draai 130 --apply`);
  }
  const soort = (await su.collections.getOne('hh_meldingen')).fields.find((f) => f.name === 'soort');
  check(`hh_meldingen.soort kent "${MELDING_SOORT_REACTIE}"`, !!soort?.values?.includes(MELDING_SOORT_REACTIE), 'draai 130 --apply');
  const incSoort = (await su.collections.getOne('hh_incidenten')).fields.find((f) => f.name === 'soort');
  check(`hh_incidenten.soort kent "${INCIDENT_SOORT_SIGNAAL}"`, !!incSoort?.values?.includes(INCIDENT_SOORT_SIGNAAL), 'draai 130 --apply');
  const r = await route(anonClient(), '/api/hh/klussen/bestaatniet/reageren');
  check(`route reageren bestaat (anoniem 401, kreeg ${r.status})`, r.status === 401, 'draai 133-hook-deploy.sh');
  const k = await route(anonClient(), '/api/hh/klussen/bestaatniet/kiezen');
  check(`route kiezen bestaat (anoniem 401, kreeg ${k.status})`, k.status === 401, 'draai 133-hook-deploy.sh');
  const instellingen = await su.collection('hh_instellingen').getFullList({ filter: su.filter('sleutel ~ {:p}', { p: 'b5_' }) });
  console.log(`  · schakelaars in hh_instellingen: ${instellingen.map((i) => `${i.sleutel}=${JSON.stringify(i.waarde)}`).join(', ') || 'geen (alles uit)'}`);
  const regio = (await su.collection('hh_wijken').getFullList({ filter: su.filter('wijk = {:w}', { w: REGIO_WIJK.wijk }) }))[0];
  check(`wijk "${REGIO_WIJK.wijk}" bestaat`, !!regio);
  return { regio, instellingen };
}

async function main() {
  for (const c of ['hh_users', 'hh_profielen', 'hh_klussen', 'hh_meldingen', 'hh_reacties', 'hh_instellingen']) assertHh(c);
  const su = await superuserClient();
  console.log('Verbonden met', PB_URL, APPLY ? '(APPLY)' : '(DRY-RUN)', '\n');

  if (!APPLY) {
    console.log('DRY-RUN: er wordt NIETS geschreven.');
    await voorwaarden(su);
    console.log('\nWat --apply ZOU doen:');
    console.log(`  · tijdelijke accounts (${MAIL_PREFIX}...${MAIL_DOMEIN}, nooit mail): coordinator, 2 bewoners, helpers van 11, 14, 17, 25 en 30;`);
    console.log('  · ±10 eigen klussen met een testfoto, als superuser goedgekeurd (geen "nieuwe klus"-meldingen, behalve sectie N);');
    console.log(`  · reageren, ouder (token als superuser gezet), kiezen, 2x ${RONDEN} race-ronden, beoordelen, "Ik kan nu helpen";`);
    console.log('  · sectie L: kort één signaal (geen melding, wel even in de lijst van het paneel);');
    console.log('  · schakelaars: onder 18 tijdelijk aan in E t/m K, accepteren dicht kort in N (alleen');
    console.log('    als hij nog niet bestaat); alles precies terug zoals het stond;');
    console.log('  · alles opruimen en nameten.');
    console.log(`\n${groen} groen, ${rood} rood (leescontroles).`);
    if (rood > 0) console.log('Rood is verwacht zolang 130, 131 en 133 nog niet uitgerold zijn.');
    return;
  }

  kop('A. Opruimen van een eerdere run');
  await opruimen(su);
  if (ALLEEN_OPRUIMEN) {
    console.log('\nAlleen opgeruimd.');
    return;
  }

  const { regio, instellingen } = await voorwaarden(su);
  const types = await su.collection('hh_klustypes').getFullList();
  const tuin = types.find((t) => t.naam === 'Tuin');
  const licht = types.find((t) => t.naam === 'Boodschappen');
  if (!regio || !tuin || !licht) {
    console.log('\nZonder regio-wijk en categorieën kan de check niet verder.');
    process.exitCode = 1;
    return;
  }
  try {
    await secties(su, regio, tuin, licht, instellingen);
  } finally {
    kop('O. Opruimen en nameten');
    await herstelTijdelijk(su);
    const naSchakelaars = await su.collection('hh_instellingen').getFullList({ filter: su.filter('sleutel ~ {:p}', { p: 'b5_' }) });
    const tekstVan = (lijst) => JSON.stringify(lijst.map((i) => [i.sleutel, i.waarde]).sort());
    check('schakelaars precies zoals vóór de check', tekstVan(naSchakelaars) === tekstVan(instellingen), `${tekstVan(instellingen)} -> ${tekstVan(naSchakelaars)}`);
    await opruimen(su);
    const rest = await su.collection('hh_users').getFullList({ filter: su.filter('email ~ {:p}', { p: MAIL_PREFIX }) });
    check('geen tijdelijke accounts meer', rest.length === 0, `${rest.length} over`);
    const klussen = await su.collection('hh_klussen').getFullList({ filter: su.filter('omschrijving ~ {:m}', { m: MERK }) });
    check('geen [b5check]-klussen meer', klussen.length === 0, `${klussen.length} over`);
    console.log(`\n${groen} groen, ${rood} rood${overgeslagen ? `, ${overgeslagen} overgeslagen` : ''}.`);
    if (rood > 0) process.exitCode = 1;
  }
}

async function secties(su, regio, tuin, licht, instellingen) {
  const dag = dagOver(2);
  const wachtwoord = randomBytes(18).toString('base64url');
  async function account(label, rol, extra = {}) {
    const email = `${MAIL_PREFIX}${label.toLowerCase()}-${randomBytes(4).toString('hex')}${MAIL_DOMEIN}`;
    const record = await su.collection(assertHh('hh_users')).create({
      email, password: wachtwoord, passwordConfirm: wachtwoord, verified: true,
      rol, naam: `${label} ${MERK}`, taal: 'nl', ...extra,
    });
    return { id: record.id, record, email, client: await userClient(email, wachtwoord) };
  }
  const tweedeClient = (a) => userClient(a.email, wachtwoord);
  async function helper(label, jaren, extra = {}) {
    const volwassen = jaren >= 18;
    const h = await account(label, 'jongere', {
      geboortedatum: geboren(jaren, dag.datum),
      wijk: regio.id,
      ...(volwassen ? {} : { ouder_toestemming_op: nu(), ouder_email: `ouder-${label.toLowerCase()}${MAIL_DOMEIN}` }),
      ...extra,
    });
    const profiel = await su.collection(assertHh('hh_profielen')).create({
      gebruiker: h.id, verificatiestatus: 'goedgekeurd', ...(volwassen ? { vog_gezien_op: nu() } : {}),
    });
    await su.collection('hh_profielen').update(profiel.id, { id_gecontroleerd_op: nu() });
    return { ...h, profiel: profiel.id };
  }

  const coord = await account('Meldkamer', 'coordinator');
  const bewoner = await account('Anja', 'hulpvrager', { wijk: regio.id, adres: 'Teststraat 1', plaats: 'Tiel' });
  const bewoner2 = await account('Kees', 'hulpvrager', { wijk: regio.id, adres: 'Teststraat 2', plaats: 'Tiel' });
  const h11 = await helper('Lisa', 11);
  const h14 = await helper('Daan', 14);
  const h17 = await helper('Mila', 17);
  const h25 = await helper('Ruud', 25);
  const h30 = await helper('Sanne', 30);
  const h14z = await account('Tom', 'jongere', { geboortedatum: geboren(14, dag.datum), wijk: regio.id });
  await su.collection(assertHh('hh_profielen')).create({ gebruiker: h14z.id, verificatiestatus: 'goedgekeurd' });

  const plaats = async (wie, extra = {}) => {
    const k = await wie.client.collection('hh_klussen').create({
      hulpvrager: wie.id, geplaatst_door: wie.id, bron: 'app', status: 'open', klustype: licht.id,
      omschrijving: `${MERK} Boodschappen bij de supermarkt halen.`, adres: 'Teststraat 1, 4001 MA Tiel',
      lat: 51.88, lon: 5.42, wanneer_van: dag.om(14), wanneer_tot: dag.om(15), nee_lijst_akkoord: true, foto: png(),
      ...extra,
    });
    // Als superuser goedkeuren: geen logregel, dus geen "nieuwe klus" voor
    // echte helpers in de wijk (de keur-route zelf bewijst 102).
    return su.collection('hh_klussen').update(k.id, { klus_goedgekeurd_op: nu() });
  };
  const reageer = (h, k, body = {}) => route(h.client, `/api/hh/klussen/${k.id}/reageren`, body);
  const kies = (wie, k, reactie) => route(wie.client, `/api/hh/klussen/${k.id}/kiezen`, { reactie });
  const reactieVan = async (h, k) =>
    (await su.collection(COLLECTIE).getFullList({ filter: su.filter('klus = {:k} && helper = {:h}', { k: k.id, h: h.id }) }))[0];
  const meldingen = (ontvanger, extra = '') =>
    su.collection('hh_meldingen').getFullList({ filter: su.filter(`ontvanger = {:o}${extra}`, { o: ontvanger.id }), sort: 'created' });
  const logs = (k) => su.collection('hh_klus_status').getFullList({ filter: su.filter('klus = {:k}', { k: k.id }), sort: 'created' });

  // ---------------------------------------------------------------- C
  kop('C. Reageren door een helper van 25 (klus blijft open)');
  const k1 = await mag('bewoner plaatst een klus (Boodschappen, overmorgen 14:00-15:00)', () => plaats(bewoner));
  if (!k1) return;
  let r = await reageer(h25, k1, { bericht: 'Ik heb een fiets met tassen. Bel 06-12345678' });
  check(`reageren -> 200 open (kreeg ${r.status} ${r.body?.status})`, r.status === 200 && r.body?.status === 'open', JSON.stringify(r.body));
  check('  melding "De bewoner kiest zelf een helper"', /bewoner kiest zelf/.test(r.body?.melding ?? ''));
  let kNa = await su.collection('hh_klussen').getOne(k1.id);
  check('  de klus blijft OPEN, zonder helper', kNa.status === 'open' && !kNa.toegewezen_jongere);
  const r25 = await reactieVan(h25, k1);
  check('  reactie open, berichtje gefilterd (nummer -> •••)', r25?.status === 'open' && r25?.bericht === 'Ik heb een fiets met tassen. Bel •••' && r25?.bericht_gefilterd === true, JSON.stringify(r25));
  check('  token_hash niet te lezen (hidden) voor de helper zelf en de coordinator',
    (await h25.client.collection(COLLECTIE).getOne(r25.id)).token_hash === undefined &&
    (await coord.client.collection(COLLECTIE).getOne(r25.id)).token_hash === undefined);
  r = await reageer(h25, k1);
  check(`nog eens reageren -> 409 algereageerd (kreeg ${r.status} ${r.body?.reden})`, r.status === 409 && r.body?.reden === 'algereageerd');
  let mb = await meldingen(bewoner, ' && soort = "reactie"');
  check('bewoner krijgt één melding "Ruud wil je helpen"', mb.length === 1 && mb[0].titel === 'Ruud wil je helpen', JSON.stringify(mb.map((m) => m.titel)));
  r = await reageer(h30, k1, { bericht: 'Ik kan zaterdag.' });
  check(`tweede helper reageert -> 200 (kreeg ${r.status})`, r.status === 200);
  mb = await meldingen(bewoner, ' && soort = "reactie"');
  check('  gebundeld: nog steeds één melding, nu "Sanne en Ruud willen je helpen"', mb.length === 1 && mb[0].titel === 'Sanne en Ruud willen je helpen', JSON.stringify(mb.map((m) => m.titel)));
  const lijst = async (wie, k) => (await wie.client.collection(COLLECTIE).getFullList({ filter: `klus = "${k.id}"` })).map((x) => x.helper).sort();
  check('bewoner ziet (rule) de 2 open reacties', JSON.stringify(await lijst(bewoner, k1)) === JSON.stringify([h25.id, h30.id].sort()));
  check('helper ziet alleen zijn eigen reactie', JSON.stringify(await lijst(h25, k1)) === JSON.stringify([h25.id]));
  check('andere bewoner ziet niets', (await lijst(bewoner2, k1)).length === 0);
  check('anoniem ziet niets', (await anonClient().collection(COLLECTIE).getFullList().catch(() => [])).length === 0);
  check('coordinator ziet ze allebei', (await lijst(coord, k1)).length === 2);
  await magNiet('helper maakt zelf een reactie via de API: geweigerd', () => h17.client.collection(COLLECTIE).create({ klus: k1.id, helper: h17.id, status: 'open' }), [400, 403]);
  await magNiet('bewoner zet zelf een reactie op gekozen: geweigerd', () => bewoner.client.collection(COLLECTIE).update(r25.id, { status: 'gekozen' }), [400, 403, 404]);
  await magNiet('helper filtert zijn reacties op de locatie van de klus: 400', () => h25.client.collection(COLLECTIE).getFullList({ filter: 'klus.lat > 0' }), [400]);
  const helperZiet = await h30.client.collection('hh_klussen').getOne(k1.id);
  check(`helper ziet het aantal reacties op de klus (reacties_aantal ${helperZiet.reacties_aantal}, mijn_reactie ${helperZiet.mijn_reactie})`, helperZiet.reacties_aantal === 2 && helperZiet.mijn_reactie === 'open');
  const bewonerZiet = await bewoner.client.collection('hh_klussen').getOne(k1.id);
  check(`bewoner ziet reacties_aantal 2 op zijn klus (kreeg ${bewonerZiet.reacties_aantal})`, bewonerZiet.reacties_aantal === 2);

  // ---------------------------------------------------------------- D
  kop('D. Reageren: dezelfde voorwaarden als accepteren');
  const reden = async (wie, k, body) => {
    const u = await reageer(wie, k, body);
    return `${u.status} ${u.body?.reden}`;
  };
  check('bewoner reageert niet (403 rol)', (await reden(bewoner, k1)) === '403 rol');
  check('helper < 18 zonder ouder-toestemming (403 ouder)', (await reden(h14z, k1)) === '403 ouder');
  const kOngekeurd = await bewoner.client.collection('hh_klussen').create({
    hulpvrager: bewoner.id, geplaatst_door: bewoner.id, bron: 'app', status: 'open', klustype: licht.id,
    omschrijving: `${MERK} nog niet gekeurd`, adres: 'Teststraat 1, 4001 MA Tiel', lat: 51.88, lon: 5.42,
    wanneer_van: dag.om(14), nee_lijst_akkoord: true, foto: png(),
  });
  check('ongekeurde klus (409 nietgekeurd; voor de helper bestaat hij nog niet: 404 mag ook)', ['409 nietgekeurd'].includes(await reden(h25, kOngekeurd)));
  const kTuin = await plaats(bewoner, { klustype: tuin.id, omschrijving: `${MERK} Heg knippen.`, wanneer_van: dag.om(10), wanneer_tot: dag.om(11) });
  const leeftijd = await reageer(h11, kTuin);
  check(`helper van 11 op een tuinklus (403 leeftijd "13 jaar", kreeg ${leeftijd.status} ${leeftijd.body?.reden})`, leeftijd.status === 403 && leeftijd.body?.reden === 'leeftijd' && /13 jaar/.test(leeftijd.body?.melding ?? ''));
  check('berichtje van 201 tekens (400 bericht)', (await reden(h17, k1, { bericht: 'x'.repeat(201) })) === '400 bericht');
  check('onbekende klus (404)', (await reden(h25, { id: 'bestaatniet0000' })) === '404 nietgevonden');

  // ---------------------------------------------------------------- E
  kop('E. Helper onder 18: eerst de ouder');
  // Antwoord Ibrahim 5: onder 18 pas als de site online is (schakelaar
  // b5_onder18_reageren_open, bij de uitrol UIT). Eerst "dicht" bewijzen,
  // dan tijdelijk aan voor E t/m K (de ouder-stroom), daarna weer terug.
  const o18 = instellingen.find((i) => i.sleutel === 'b5_onder18_reageren_open');
  if (o18?.waarde === true) {
    sla('onder 18 dicht: de schakelaar staat op deze server al aan');
  } else {
    r = await reageer(h14, k1);
    check(`onder 18 dicht (schakelaar uit): 409 onder18 (kreeg ${r.status} ${r.body?.reden})`, r.status === 409 && r.body?.reden === 'onder18' && /onder de 18/.test(r.body?.melding ?? ''), r.body?.melding);
    check('  er is geen reactie gemaakt en geen ouder gemaild', !(await reactieVan(h14, k1)));
    await zetTijdelijk(su, 'b5_onder18_reageren_open');
  }
  r = await reageer(h14, k1, { bericht: 'Ik help graag!' });
  check(`helper van 14 reageert -> 200 wacht_op_ouder (kreeg ${r.status} ${r.body?.status})`, r.status === 200 && r.body?.status === 'wacht_op_ouder', JSON.stringify(r.body));
  check('  melding "Eerst kijkt je ouder"', /ouder/.test(r.body?.melding ?? ''));
  const r14 = await reactieVan(h14, k1);
  check('  ouder_gemaild_op gezet (adres op .invalid: geen echte mail)', !!r14?.ouder_gemaild_op);
  check('  bewoner ziet hem NIET (rule)', !(await lijst(bewoner, k1)).includes(h14.id));
  const route14 = await route(bewoner.client, `/api/hh/klussen/${k1.id}/reacties`, {}, 'GET');
  check('  en ook niet in KiesHelper', route14.status === 200 && !route14.body.reacties.some((x) => x.helper === h14.id));
  // De echte token staat alleen in de mail; de check zet als superuser een bekende.
  const token = randomBytes(24).toString('hex');
  await su.collection(COLLECTIE).update(r14.id, { token_hash: sha256(`hh-ouder-klus:${token}`) });
  const ouder = anonClient();
  let o = await route(ouder, '/api/hh/ouder/klus', { token });
  check(`ouder opent de link -> 200 wacht (kreeg ${o.status} ${o.body?.status})`, o.status === 200 && o.body?.status === 'wacht', JSON.stringify(o.body));
  check('  wat/wanneer/voornaam bewoner', o.body?.klus?.wat === 'Boodschappen' && /om 14:00/.test(o.body?.klus?.wanneer ?? '') && o.body?.klus?.bewoner_voornaam === 'Anja', JSON.stringify(o.body?.klus));
  check(`  waar zonder huisnummer of postcode ("${o.body?.klus?.waar}")`, o.body?.klus?.waar === 'Teststraat, Tiel');
  check('  geen achternaam van de bewoner of de helper', !JSON.stringify(o.body).includes(`Anja ${MERK}`) && !JSON.stringify(o.body).includes(`Daan ${MERK}`));
  o = await route(ouder, '/api/hh/ouder/klus', { token: 'fout'.repeat(10) });
  check(`foute token -> 404 link (kreeg ${o.status})`, o.status === 404 && o.body?.reden === 'link');
  o = await route(ouder, '/api/hh/ouder/klus/besluit', { token, besluit: 'misschien' });
  check(`onbekend besluit -> 400 (kreeg ${o.status})`, o.status === 400);
  o = await route(ouder, '/api/hh/ouder/klus/besluit', { token, besluit: 'goed' });
  check(`ouder kiest "Goed" -> 200 goed (kreeg ${o.status} ${o.body?.status})`, o.status === 200 && o.body?.status === 'goed');
  const r14na = await su.collection(COLLECTIE).getOne(r14.id);
  check('  reactie open, ouder_besluit goed, ouder_akkoord_op gezet', r14na.status === 'open' && r14na.ouder_besluit === 'goed' && !!r14na.ouder_akkoord_op);
  check('  nu ziet de bewoner hem wel', (await lijst(bewoner, k1)).includes(h14.id));
  const m14 = await meldingen(h14, ' && soort = "reactie"');
  check('  helper krijgt "Je ouder vindt het goed"', m14.some((m) => m.titel === 'Je ouder vindt het goed'));
  o = await route(ouder, '/api/hh/ouder/klus/besluit', { token, besluit: 'lieverniet' });
  check('  nog eens (andersom): de stand blijft "goed"', o.status === 200 && o.body?.status === 'goed' && (await su.collection(COLLECTIE).getOne(r14.id)).status === 'open');

  r = await reageer(h17, k1);
  const r17 = await reactieVan(h17, k1);
  const token17 = randomBytes(24).toString('hex');
  await su.collection(COLLECTIE).update(r17.id, { token_hash: sha256(`hh-ouder-klus:${token17}`) });
  o = await route(ouder, '/api/hh/ouder/klus/besluit', { token: token17, besluit: 'lieverniet' });
  check(`ouder kiest "Liever niet" -> lieverniet (kreeg ${o.body?.status})`, o.status === 200 && o.body?.status === 'lieverniet');
  check('  reactie afgewezen (ouder_besluit liever_niet), bewoner ziet hem niet', (await su.collection(COLLECTIE).getOne(r17.id)).status === 'afgewezen' && !(await lijst(bewoner, k1)).includes(h17.id));

  const kStart = await plaats(bewoner2, { wanneer_van: dag.om(16), wanneer_tot: dag.om(17) });
  await reageer(h17, kStart);
  const rStart = await reactieVan(h17, kStart);
  const tokenStart = randomBytes(24).toString('hex');
  await su.collection(COLLECTIE).update(rStart.id, { token_hash: sha256(`hh-ouder-klus:${tokenStart}`) });
  await su.collection('hh_klussen').update(kStart.id, { wanneer_van: new Date(Date.now() - 60e3).toISOString(), wanneer_tot: '' });
  o = await route(ouder, '/api/hh/ouder/klus', { token: tokenStart });
  check(`de klus is begonnen -> de vraag is verlopen (kreeg ${o.body?.status})`, o.body?.status === 'verlopen');
  check('  reactie vervallen', (await su.collection(COLLECTIE).getOne(rStart.id)).status === 'vervallen');
  check('  besluit daarna: nog steeds verlopen', (await route(ouder, '/api/hh/ouder/klus/besluit', { token: tokenStart, besluit: 'goed' })).body?.status === 'verlopen');

  // ---------------------------------------------------------------- F
  kop('F. Eerste klus bij een nieuwe bewoner (10-12 jaar: ouder gaat mee)');
  r = await reageer(h11, k1);
  check(`helper van 11 zonder vinkje -> 400 oudermee (kreeg ${r.status} ${r.body?.reden})`, r.status === 400 && r.body?.reden === 'oudermee');
  r = await reageer(h11, k1, { ouder_gaat_mee: true });
  check(`met vinkje -> 200 wacht_op_ouder (kreeg ${r.status} ${r.body?.status})`, r.status === 200 && r.body?.status === 'wacht_op_ouder');
  check('  ouder_gaat_mee bewaard', (await reactieVan(h11, k1))?.ouder_gaat_mee === true);
  await su.collection('hh_klussen').create({
    hulpvrager: bewoner2.id, geplaatst_door: bewoner2.id, bron: 'telefoon', status: 'afgerond', klustype: licht.id,
    toegewezen_jongere: h11.id, omschrijving: `${MERK} eerdere klus`, lat: 51.88, lon: 5.42,
  });
  const kB2 = await plaats(bewoner2, { wanneer_van: dag.om(11), wanneer_tot: dag.om(12) });
  r = await reageer(h11, kB2);
  check(`al eens bij deze bewoner geweest -> geen vinkje nodig (kreeg ${r.status} ${r.body?.reden ?? r.body?.status})`, r.status === 200);
  r = await reageer(h14, kB2);
  check(`13+ (helper van 14): de server eist niets (kreeg ${r.status})`, r.status === 200);

  // ---------------------------------------------------------------- G
  kop('G. KiesHelper: wat de bewoner van de helpers ziet');
  const kaarten = await route(bewoner.client, `/api/hh/klussen/${k1.id}/reacties`, {}, 'GET');
  check(`route -> 200 met 3 open reacties (Ruud, Sanne, Daan; kreeg ${kaarten.body?.reacties?.length})`, kaarten.status === 200 && kaarten.body?.reacties?.length === 3, JSON.stringify(kaarten.body));
  const ruud = kaarten.body?.reacties?.find((x) => x.helper === h25.id);
  check('  voornaam, leeftijd, niveau "Nieuw", ID gecontroleerd, berichtje', ruud?.voornaam === 'Ruud' && ruud?.leeftijd >= 24 && ruud?.niveau === 'Nieuw' && ruud?.id_gecontroleerd === true && ruud?.bericht?.startsWith('Ik heb een fiets'), JSON.stringify(ruud));
  const tekst = JSON.stringify(kaarten.body);
  check('  geen achternaam, geboortedatum, adres of e-mail', !tekst.includes(MERK) && !/geboortedatum|"adres"|email|@heitjehulp/.test(tekst) && !tekst.includes(geboren(25, dag.datum).slice(0, 10)));
  check('vreemde bewoner -> 403', (await route(bewoner2.client, `/api/hh/klussen/${k1.id}/reacties`, {}, 'GET')).status === 403);
  check('helper -> 403', (await route(h25.client, `/api/hh/klussen/${k1.id}/reacties`, {}, 'GET')).status === 403);
  check('anoniem -> 401', (await route(anonClient(), `/api/hh/klussen/${k1.id}/reacties`, {}, 'GET')).status === 401);

  // ---------------------------------------------------------------- H
  kop('H. Kiezen: het is een match');
  const voor = await h25.client.collection('hh_klussen').getOne(k1.id);
  check('vóór de match ziet de helper geen adres (vaag)', !voor.adres && voor.locatie_vaag === true);
  const zelf = await kies(h25, k1, r25.id);
  check(`helper kan niet zelf kiezen (403, kreeg ${zelf.status})`, zelf.status === 403);
  check('zonder reactie -> 400', (await kies(bewoner, k1, '')).status === 400);
  const logsVoor = (await logs(k1)).length;
  const match = await kies(bewoner, k1, r25.id);
  check(`bewoner kiest Ruud -> 200 "Het is een match!" (kreeg ${match.status})`, match.status === 200 && match.body?.melding === 'Het is een match!' && match.body?.helper_voornaam === 'Ruud', JSON.stringify(match.body));
  kNa = await su.collection('hh_klussen').getOne(k1.id);
  check('  klus geaccepteerd met Ruud als helper', kNa.status === 'geaccepteerd' && kNa.toegewezen_jongere === h25.id);
  const st = Object.fromEntries((await su.collection(COLLECTIE).getFullList({ filter: su.filter('klus = {:k}', { k: k1.id }) })).map((x) => [x.helper, x.status]));
  check('  Ruud gekozen, Sanne en Daan afgewezen, Lisa (wachtte op ouder) vervallen, Mila blijft afgewezen',
    st[h25.id] === 'gekozen' && st[h30.id] === 'afgewezen' && st[h14.id] === 'afgewezen' && st[h11.id] === 'vervallen' && st[h17.id] === 'afgewezen', JSON.stringify(st));
  const nieuwLog = (await logs(k1)).slice(logsVoor);
  check('  precies één logregel open -> geaccepteerd, door de bewoner, "gekozen door de bewoner"',
    nieuwLog.length === 1 && nieuwLog[0].van === 'open' && nieuwLog[0].naar === 'geaccepteerd' && nieuwLog[0].door === bewoner.id && nieuwLog[0].toelichting === 'gekozen door de bewoner', JSON.stringify(nieuwLog));
  const m25 = await meldingen(h25, ' && soort = "toegewezen"');
  check('  Ruud krijgt "Het is een match!"', m25.length === 1 && m25[0].titel === 'Het is een match!' && /^Anja koos jou/.test(m25[0].tekst), JSON.stringify(m25.map((m) => [m.titel, m.tekst])));
  const mBewoner = await meldingen(bewoner, ' && soort = "toegewezen"');
  check('  de bewoner krijgt geen dubbele "Er komt iemand helpen" (koos zelf)', mBewoner.length === 0, JSON.stringify(mBewoner.map((m) => m.titel)));
  const m30 = await meldingen(h30, ' && soort = "reactie"');
  check('  Sanne krijgt "De bewoner koos iemand anders"', m30.some((m) => m.titel === 'De bewoner koos iemand anders'));
  check('  Lisa (wachtte op ouder) krijgt niets', (await meldingen(h11, ' && soort = "reactie"')).every((m) => !m.sleutel.startsWith('afgewezen:')));
  check('  de reactie-melding van de bewoner staat op gelezen', (await meldingen(bewoner, ' && soort = "reactie"')).every((m) => !!m.gelezen_op));
  const tweede = await kies(bewoner, k1, (await reactieVan(h30, k1)).id);
  check(`  tweede keuze -> 409 klusbezet (kreeg ${tweede.status} ${tweede.body?.reden})`, tweede.status === 409 && tweede.body?.reden === 'klusbezet');
  const na = await h25.client.collection('hh_klussen').getOne(k1.id);
  check('na de match ziet Ruud het exacte adres', na.adres === 'Teststraat 1, 4001 MA Tiel' && !na.locatie_vaag);
  await mag('en de chat staat open: de bewoner stuurt "Hoi Ruud"', () => bewoner.client.collection('hh_berichten').create({ klus: k1.id, afzender: bewoner.id, tekst: 'Hoi Ruud', soort: 'tekst' }));
  await mag('  Ruud antwoordt', () => h25.client.collection('hh_berichten').create({ klus: k1.id, afzender: h25.id, tekst: 'Hoi Anja, tot zaterdag!', soort: 'tekst' }));
  await magNiet('  Sanne (niet gekozen) kan niet in die chat', () => h30.client.collection('hh_berichten').create({ klus: k1.id, afzender: h30.id, tekst: 'Hoi', soort: 'tekst' }), [400, 403]);

  // ---------------------------------------------------------------- I
  kop(`I. RACE: dezelfde bewoner klikt ${RONDEN} keer tegelijk op twee helpers`);
  const kRace = await plaats(bewoner2, { wanneer_van: dag.om(9), wanneer_tot: dag.om(10) });
  await reageer(h25, kRace);
  await reageer(h30, kRace);
  const ra = await reactieVan(h25, kRace);
  const rb = await reactieVan(h30, kRace);
  const b2a = await tweedeClient(bewoner2);
  let winst = 0;
  const per = { [h25.id]: 0, [h30.id]: 0 };
  for (let ronde = 1; ronde <= RONDEN; ronde++) {
    const voorLogs = (await logs(kRace)).length;
    const [x, y] = await Promise.all([kies(bewoner2, kRace, ra.id), kies({ client: b2a }, kRace, rb.id)]);
    const k = await su.collection('hh_klussen').getOne(kRace.id);
    const nieuw = (await logs(kRace)).length - voorLogs;
    const codes = [x.status, y.status].sort().join(',');
    if (codes === '200,409' && nieuw === 1 && k.status === 'geaccepteerd' && [h25.id, h30.id].includes(k.toegewezen_jongere)) {
      winst++;
      per[k.toegewezen_jongere]++;
    } else {
      console.log(`  ✗ ronde ${ronde}: ${codes}, ${nieuw} logregel(s), klus ${k.status} ${k.toegewezen_jongere}`);
    }
    // Terug naar de beginstand (superuser): klus open, beide reacties open.
    await su.collection('hh_klussen').update(kRace.id, { status: 'open', toegewezen_jongere: '' });
    for (const rr of [ra, rb]) await su.collection(COLLECTIE).update(rr.id, { status: 'open', gekozen_op: '' });
  }
  check(`${winst}/${RONDEN} ronden precies één winnaar, één 409 en één logregel (Ruud ${per[h25.id]}, Sanne ${per[h30.id]})`, winst === RONDEN);

  kop(`J. RACE: twee bewoners kiezen ${RONDEN} keer tegelijk dezelfde helper voor hetzelfde moment`);
  const kX = await plaats(bewoner, { wanneer_van: dag.om(12), wanneer_tot: dag.om(13), omschrijving: `${MERK} race X` });
  const kY = await plaats(bewoner2, { wanneer_van: dag.om(12, 30), wanneer_tot: dag.om(13, 30), omschrijving: `${MERK} race Y` });
  await reageer(h30, kX);
  await reageer(h30, kY);
  const rx = await reactieVan(h30, kX);
  const ry = await reactieVan(h30, kY);
  winst = 0;
  let bezet = 0;
  for (let ronde = 1; ronde <= RONDEN; ronde++) {
    const [x, y] = await Promise.all([kies(bewoner, kX, rx.id), kies(bewoner2, kY, ry.id)]);
    const [ax, ay] = await Promise.all([su.collection('hh_klussen').getOne(kX.id), su.collection('hh_klussen').getOne(kY.id)]);
    const toegewezen = [ax, ay].filter((k) => k.toegewezen_jongere === h30.id).length;
    const codes = [x.status, y.status].sort().join(',');
    const weiger = [x, y].find((u) => u.status === 409);
    if (codes === '200,409' && toegewezen === 1 && weiger?.body?.reden === 'helperbezet') {
      winst++;
      bezet++;
    } else {
      console.log(`  ✗ ronde ${ronde}: ${codes}, ${toegewezen} toegewezen, reden ${weiger?.body?.reden}`);
    }
    for (const k of [kX, kY]) await su.collection('hh_klussen').update(k.id, { status: 'open', toegewezen_jongere: '' });
    for (const rr of [rx, ry]) await su.collection(COLLECTIE).update(rr.id, { status: 'open', gekozen_op: '' });
  }
  check(`${winst}/${RONDEN} ronden precies één match; de ander 409 helperbezet (${bezet}x)`, winst === RONDEN);
  const kLater = await plaats(bewoner2, { wanneer_van: dag.om(16), wanneer_tot: dag.om(17), omschrijving: `${MERK} later` });
  await reageer(h30, kLater);
  check(`  dezelfde helper voor een klus op een ANDER moment kan wel (kreeg ${(await kies(bewoner, kX, rx.id)).status} / ${(await kies(bewoner2, kLater, (await reactieVan(h30, kLater)).id)).status})`,
    (await su.collection('hh_klussen').getOne(kLater.id)).toegewezen_jongere === h30.id);

  // ---------------------------------------------------------------- K
  kop('K. Intrekken, teruggeven, koppelen, annuleren');
  const kK = await plaats(bewoner, { wanneer_van: dag.om(8), wanneer_tot: dag.om(9), omschrijving: `${MERK} intrekken` });
  await reageer(h17, kK);
  await reageer(h25, kK);
  const rk17 = await reactieVan(h17, kK);
  const rk25 = await reactieVan(h25, kK);
  check('reactie van een ander intrekken -> 404', (await route(h25.client, `/api/hh/reacties/${rk17.id}/intrekken`)).status === 404);
  r = await route(h17.client, `/api/hh/reacties/${rk17.id}/intrekken`);
  check(`eigen (wachtende) reactie intrekken -> 200 (kreeg ${r.status})`, r.status === 200 && (await su.collection(COLLECTIE).getOne(rk17.id)).status === 'ingetrokken');
  r = await reageer(h17, kK);
  check(`daarna opnieuw reageren mag (zelfde rij, kreeg ${r.status})`, r.status === 200 && (await su.collection(COLLECTIE).getFullList({ filter: su.filter('klus = {:k} && helper = {:h}', { k: kK.id, h: h17.id }) })).length === 1);
  check('kiezen van Ruud', (await kies(bewoner, kK, rk25.id)).status === 200);
  check('na de keuze intrekken -> 409 status', (await route(h25.client, `/api/hh/reacties/${rk25.id}/intrekken`)).body?.reden === 'status');
  r = await route(h25.client, `/api/hh/klussen/${kK.id}/annuleren`, { reden: 'Ik ben ziek geworden.' });
  check(`Ruud geeft de klus terug (M6 annuleren -> open, kreeg ${r.status} ${r.body?.status})`, r.status === 200 && r.body?.status === 'open');
  check('  zijn gekozen reactie is nu ingetrokken', (await su.collection(COLLECTIE).getOne(rk25.id)).status === 'ingetrokken');
  r = await reageer(h30, kK);
  const rk30 = await reactieVan(h30, kK);
  r = await route(coord.client, `/api/hh/klussen/${kK.id}/koppelen`, { jongere: h25.id });
  check(`meldkamer koppelt Ruud (koppelen blijft werken, kreeg ${r.status})`, r.status === 200);
  check('  open reactie van Sanne -> afgewezen, met melding', (await su.collection(COLLECTIE).getOne(rk30.id)).status === 'afgewezen' &&
    (await meldingen(h30, ' && soort = "reactie"')).some((m) => m.sleutel === `afgewezen:${rk30.id}`));
  const kAnn = await plaats(bewoner, { wanneer_van: dag.om(17), wanneer_tot: dag.om(18), omschrijving: `${MERK} annuleren` });
  await reageer(h30, kAnn);
  r = await route(bewoner.client, `/api/hh/klussen/${kAnn.id}/annuleren`, { reden: 'Mijn zoon komt toch.' });
  check(`bewoner annuleert een klus met een open reactie (kreeg ${r.status})`, r.status === 200);
  const rAnn = await reactieVan(h30, kAnn);
  check('  reactie vervallen, Sanne krijgt "Klus gaat niet door"', rAnn.status === 'vervallen' && (await meldingen(h30, ' && soort = "reactie"')).some((m) => m.sleutel === `vervallen:${rAnn.id}`));

  if (o18?.waarde !== true) {
    await herstelTijdelijk(su, 'b5_onder18_reageren_open');
    r = await reageer(h14, kRace);
    check(`schakelaar onder 18 weer zoals hij stond: 409 onder18 (kreeg ${r.status} ${r.body?.reden})`, r.status === 409 && r.body?.reden === 'onder18');
  }

  // ---------------------------------------------------------------- L
  kop('L. Beoordelen van twee kanten + geheime vraag');
  for (const naar of ['onderweg', 'bezig', 'afgerond']) {
    r = await route(h25.client, `/api/hh/klussen/${k1.id}/status`, { naar });
    check(`Ruud zet k1 op ${naar} (kreeg ${r.status})`, r.status === 200);
  }
  const beBewoner = await mag('bewoner beoordeelt Ruud: 5 sterren + tekst + "Was alles in orde?" ja', () =>
    bewoner.client.collection('hh_beoordelingen').create({ klus: k1.id, van_gebruiker: bewoner.id, naar_gebruiker: h25.id, sterren: 5, tekst: 'Snel en vriendelijk.', alles_in_orde: 'ja' }));
  const beHelper = await mag('Ruud beoordeelt de bewoner: 4 sterren + "Voelde je je veilig?" nee', () =>
    h25.client.collection('hh_beoordelingen').create({ klus: k1.id, van_gebruiker: h25.id, naar_gebruiker: bewoner.id, sterren: 4, tekst: 'Aardige mevrouw.', alles_in_orde: 'nee', geheim_toelichting: 'De hond blafte erg.' }));
  const inc = await su.collection('hh_incidenten').getFullList({ filter: su.filter('klus = {:k}', { k: k1.id }) });
  check('  "nee" -> één signaal voor de meldkamer (melder Ruud, soort signaal, geen probleem)', inc.length === 1 && inc[0].melder === h25.id && inc[0].soort === INCIDENT_SOORT_SIGNAAL && /Voelde je je veilig\?/.test(inc[0].omschrijving) && /hond/.test(inc[0].omschrijving), JSON.stringify(inc));
  await new Promise((klaar) => setTimeout(klaar, 500));
  check('  GEEN "Probleem gemeld"-alarm: de coordinator krijgt geen melding', !(await meldingen(coord, ' && soort = "incident"')).some((m) => m.incident === inc[0]?.id));
  check('  de meldkamer ziet het signaal wel in de lijst', (await coord.client.collection('hh_incidenten').getFullList({ filter: `id = "${inc[0]?.id}"` })).length === 1);
  check('  en mag (zoals bij elk incident, B6) de chat van die klus lezen', (await coord.client.collection('hh_berichten').getFullList({ filter: `klus = "${k1.id}"` })).length >= 2);
  if (beHelper) {
    const zietBewoner = await bewoner.client.collection('hh_beoordelingen').getOne(beHelper.id);
    check('  de bewoner leest de beoordeling van Ruud, maar NIET het antwoord op de geheime vraag', zietBewoner.sterren === 4 && zietBewoner.alles_in_orde === undefined && zietBewoner.geheim_toelichting === undefined, JSON.stringify(zietBewoner));
    const zietZelf = await h25.client.collection('hh_beoordelingen').getOne(beHelper.id);
    check('  Ruud ziet zijn eigen antwoord', zietZelf.alles_in_orde === 'nee');
    check('  de coordinator ziet het', (await coord.client.collection('hh_beoordelingen').getOne(beHelper.id)).alles_in_orde === 'nee');
    await magNiet('  de bewoner filtert op de geheime vraag: 400', () => bewoner.client.collection('hh_beoordelingen').getFullList({ filter: 'alles_in_orde = "nee"' }), [400]);
  }
  const ruudNa = await su.collection('hh_users').getOne(h25.id);
  check(`  reputatie Ruud: 5 sterren (kreeg ${ruudNa.sterren_gemiddeld})`, ruudNa.sterren_gemiddeld === 5);
  if (beBewoner) {
    await mag('  bewoner past zijn antwoord aan naar "nee" (wijzigen)', () => bewoner.client.collection('hh_beoordelingen').update(beBewoner.id, { alles_in_orde: 'nee' }));
    const inc2 = await su.collection('hh_incidenten').getFullList({ filter: su.filter('klus = {:k}', { k: k1.id }) });
    check('  ook dan een incident, per gever hooguit één', inc2.length === 2 && inc2.filter((i) => i.melder === bewoner.id).length === 1);
  }
  const kNieuw = await plaats(bewoner2, { wanneer_van: dag.om(19), wanneer_tot: '', klustype: licht.id, omschrijving: `${MERK} na beoordeling` }).catch(() => null);
  if (kNieuw) {
    await reageer(h25, kNieuw);
    const kaart = (await route(bewoner2.client, `/api/hh/klussen/${kNieuw.id}/reacties`, {}, 'GET')).body?.reacties?.find((x) => x.helper === h25.id);
    check('  KiesHelper toont nu sterren 5 (1 beoordeling) en de laatste recensie', kaart?.sterren === 5 && kaart?.beoordelingen === 1 && kaart?.laatste_recensie === 'Snel en vriendelijk.', JSON.stringify(kaart));
  } else sla('klus na beoordeling plaatsen');

  // ---------------------------------------------------------------- M
  kop('M. "Ik kan nu helpen"');
  const tel = async (type, van = dag.om(14), tot = dag.om(15)) =>
    (await route(bewoner.client, `/api/hh/beschikbaar?klustype=${type.id}&van=${encodeURIComponent(van)}&tot=${encodeURIComponent(tot)}`, {}, 'GET')).body?.aantal;
  // De leeftijdsgrens meten met de helper van 11: daarvoor moet onder 18
  // (tijdelijk) open staan; daarna bewijzen dat hij bij "dicht" niet telt.
  const o18Open = o18?.waarde === true;
  if (!o18Open) await zetTijdelijk(su, 'b5_onder18_reageren_open');
  const voorLicht = await tel(licht);
  const voorTuin = await tel(tuin);
  r = await route(h11.client, '/api/hh/beschikbaar', { aan: true });
  const tot = Date.parse(String(r.body?.beschikbaar_tot).replace(' ', 'T'));
  check(`helper zet "Ik kan nu helpen" aan -> ~3 uur (kreeg ${r.body?.beschikbaar_tot})`, r.status === 200 && Math.abs(tot - Date.now() - 3 * 3600e3) < 120e3);
  await magNiet('  het veld zelf zetten via het profiel: 400', () => h25.client.collection('hh_profielen').update(h25.profiel, { beschikbaar_tot: '2099-01-01 00:00:00.000Z' }), [400]);
  const naLicht = await tel(licht);
  const naTuin = await tel(tuin);
  check(`bewoner ziet "${naLicht} helpers kunnen nu" voor Boodschappen: één meer dan zonder de helper van 11 (${voorLicht})`, naLicht === voorLicht + 1);
  check(`  voor Tuin (13+) telt de helper van 11 niet mee (${voorTuin} -> ${naTuin})`, naTuin === voorTuin);
  const antwoord = await route(bewoner.client, `/api/hh/beschikbaar?klustype=${licht.id}`, {}, 'GET');
  check('  het antwoord is alleen een aantal', JSON.stringify(Object.keys(antwoord.body ?? {})) === '["aantal"]');
  check('  een helper mag niet tellen (403)', (await route(h25.client, `/api/hh/beschikbaar?klustype=${licht.id}`, {}, 'GET')).status === 403);
  if (!o18Open) {
    await herstelTijdelijk(su, 'b5_onder18_reageren_open');
    const dicht = await tel(licht);
    check(`  onder 18 nog dicht: de helper van 11 telt niet mee (${dicht} = ${voorLicht})`, dicht === voorLicht);
    await zetTijdelijk(su, 'b5_onder18_reageren_open');
  }
  r = await route(h11.client, '/api/hh/beschikbaar', { aan: false });
  check('  weer uit', r.status === 200 && r.body?.beschikbaar_tot === '' && (await tel(licht)) === voorLicht);
  check('  een bewoner kan het niet aanzetten (403)', (await route(bewoner.client, '/api/hh/beschikbaar', { aan: true })).status === 403);
  if (!o18Open) await herstelTijdelijk(su, 'b5_onder18_reageren_open');

  // ---------------------------------------------------------------- N
  kop('N. De schakelaars (hh_instellingen)');
  const stand = new Map(instellingen.map((i) => [i.sleutel, i.waarde]));
  // 1. accepteren dicht (bij de uitrol: UIT; antwoord Ibrahim 1).
  if (stand.has('b5_accepteren_dicht')) {
    sla(`b5_accepteren_dicht bestaat al (${JSON.stringify(stand.get('b5_accepteren_dicht'))}): niet aangeraakt`);
  } else {
    await zetTijdelijk(su, 'b5_accepteren_dicht');
    const kAcc = await plaats(bewoner, { wanneer_van: dag.om(7), wanneer_tot: dag.om(8), omschrijving: `${MERK} accepteren dicht` });
    r = await route(h30.client, `/api/hh/klussen/${kAcc.id}/accepteren`);
    check(`b5_accepteren_dicht aan: accepteren -> 409 reageren (kreeg ${r.status} ${r.body?.reden})`, r.status === 409 && r.body?.reden === 'reageren');
    await herstelTijdelijk(su, 'b5_accepteren_dicht');
    r = await route(h30.client, `/api/hh/klussen/${kAcc.id}/accepteren`);
    check(`  schakelaar weg: accepteren werkt weer zoals in M5 (kreeg ${r.status})`, r.status === 200);
  }
  // 2. "nieuwe klus" alleen aan wie nu kan helpen (bij de uitrol: AAN; antwoord 2).
  const nieuweKlusSchakelaar = stand.get('b5_nieuwe_klus_alleen_beschikbaar');
  if (stand.has('b5_nieuwe_klus_alleen_beschikbaar') && nieuweKlusSchakelaar !== true) {
    sla('b5_nieuwe_klus_alleen_beschikbaar staat op uit: niet aangeraakt');
  } else {
    if (nieuweKlusSchakelaar !== true) await zetTijdelijk(su, 'b5_nieuwe_klus_alleen_beschikbaar');
    await route(h25.client, '/api/hh/beschikbaar', { aan: true });
    await route(h30.client, '/api/hh/beschikbaar', { aan: false });
    const kMeld = await bewoner.client.collection('hh_klussen').create({
      hulpvrager: bewoner.id, geplaatst_door: bewoner.id, bron: 'app', status: 'open', klustype: licht.id,
      omschrijving: `${MERK} melding nieuwe klus`, adres: 'Teststraat 1, 4001 MA Tiel', lat: 51.88, lon: 5.42,
      wanneer_van: dag.om(15), wanneer_tot: dag.om(16), nee_lijst_akkoord: true, foto: png(),
    });
    r = await route(coord.client, `/api/hh/klussen/${kMeld.id}/keuren`, { besluit: 'goedkeuren' });
    check(`meldkamer keurt een klus goed (kreeg ${r.status})`, r.status === 200);
    const nieuw = await su.collection('hh_meldingen').getFullList({ filter: su.filter('klus = {:k} && soort = "nieuwe_klus"', { k: kMeld.id }) });
    const aan = new Set(nieuw.map((m) => m.ontvanger));
    check('  "nieuwe klus" voor Ruud (kan nu helpen)', aan.has(h25.id), [...aan].join(','));
    check('  GEEN "nieuwe klus" voor Sanne (niet beschikbaar: alleen de lijst)', !aan.has(h30.id));
    check('  Sanne ziet de klus wel in de lijst', (await h30.client.collection('hh_klussen').getList(1, 5, { filter: `id = "${kMeld.id}"` })).totalItems === 1);
    await herstelTijdelijk(su, 'b5_nieuwe_klus_alleen_beschikbaar');
  }
}

main().catch(fail);
