// HeitjeHulp B2 — bewijst de B2-rules (80) en -hooks (83) op de ECHTE
// server. Werkt alleen met EIGEN tijdelijke accounts (e-mail
// "b2check-...@heitjehulp.invalid") en eigen klussen, en ruimt alles op.
// Er doen GEEN seed-accounts mee.
//
//   A. opruimen van een eerdere (gecrashte) run
//   B. voorwaarden (ook in dry-run, alleen lezen): de B2-aanvullingen staan
//      in de rules, werkgebied_status en de wijk "Tiel en omstreken" (81)
//      bestaan, Tiel-West en Passewaaij staan er nog
//   C. registreren: helper < 10 geweigerd (anoniem en superuser), 10 jaar
//      mag; adres -> wijk (ADRES: een adres dat niet bestaat -> geweigerd); de eigenaar
//      wijzigt zijn geboortedatum niet meer, de coordinator wel; een andere
//      postcode -> andere wijk
//   D. klussen: < 18 zonder ouder-toestemming ziet geen open klus en kan niet
//      accepteren (403 ouder); 18+ zonder vog_gezien_op idem (403 vog);
//      < 18 met toestemming (zonder VOG) ziet en accepteert (200); 18+ met
//      vog_gezien_op ziet en accepteert (200); de eigen klus blijft zichtbaar
//   E. ID-foto: voor goedkeuring mag de helper uploaden; de coordinator keurt
//      goed (document weg, id_gecontroleerd_op/_door gezet, B1); daarna kan
//      de helper GEEN nieuwe ID-foto meer uploaden
//   F. goedkeuren via de SUPERUSER wist het document ook (B1-gat 2)
//   G. verrijken: een bewoner ziet bij zijn helper alleen voornaam en het
//      vinkje id_gecontroleerd, geen geboortedatum/adres/ouder-gegevens; de
//      helper zelf en de coordinator zien alles
//   H. opruimen en nameten
//
// DRAAIEN (na 81 --apply, 80 --apply en 83-hook-deploy.sh):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/82-b2check.mjs            (dry-run: alleen leescontroles)
//   node scripts/82-b2check.mjs --apply
//   node scripts/82-b2check.mjs --apply --alleen-opruimen

import { randomBytes } from 'node:crypto';
import { superuserClient, userClient, anonClient, assertHh, APPLY, fail, PB_URL } from './_lib.mjs';
import { B2_WIJZIGINGEN, ID_SLOT, GEBOORTEDATUM_SLOT, KLUS_VOORWAARDE, WERKGEBIED_SLOT, WIJK_RUIM } from './80-b2-rules.mjs';
import { REGIO_WIJK } from './81-b2-werkgebied.mjs';
import { TIEL, OCHTEN, AMSTERDAM, NIET_BESTAAND, invoer } from './_adressen.mjs';

const MAIL_PREFIX = 'b2check-';
const MAIL_DOMEIN = '@heitjehulp.invalid';
const MERK = '[b2check]';
const ALLEEN_OPRUIMEN = process.argv.includes('--alleen-opruimen');
const WEIGER = [400, 403, 404];

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
async function magNiet(label, fn, codes = WEIGER) {
  try {
    await fn();
    check(label, false, 'verzoek is onterecht gelukt');
    return null;
  } catch (e) {
    check(`${label} (${e?.status})`, codes.includes(e?.status), `status=${e?.status} ${e?.response?.message ?? ''}`);
    return e;
  }
}
async function route(client, pad) {
  try {
    return { status: 200, body: await client.send(pad, { method: 'POST' }) };
  } catch (e) {
    return { status: e?.status ?? 0, body: e?.response ?? {} };
  }
}

/// Geboortedatum van iemand die vandaag [jaren] jaar oud is ([dagen] later
/// geboren = net nog jonger).
function geboren(jaren, dagen = 0) {
  const d = new Date();
  d.setUTCFullYear(d.getUTCFullYear() - jaren);
  d.setUTCDate(d.getUTCDate() + dagen);
  return `${d.toISOString().slice(0, 10)} 00:00:00.000Z`;
}
const nu = () => new Date().toISOString().replace('T', ' ');

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
    const profielen = await su.collection('hh_profielen').getFullList({
      filter: su.filter('gebruiker = {:id}', { id: u.id }),
    });
    for (const id of [u.id, ...profielen.map((p) => p.id)]) {
      aantal += await weg('hh_auditlog', 'door = {:id} || doel_id = {:id}', { id });
    }
  }
  for (const u of tijdelijk) await su.collection(assertHh('hh_users')).delete(u.id);
  aantal += tijdelijk.length;
  if (aantal) console.log(`  ↻ ${aantal} record(s) verwijderd (waarvan ${tijdelijk.length} tijdelijk(e) account(s))`);
  return tijdelijk.length;
}

/// Welke stukken 80 in deze rule zet.
function stukkenVoor(w) {
  if (w.collectie === 'hh_klussen') return [KLUS_VOORWAARDE, WIJK_RUIM];
  if (w.collectie === 'hh_profielen') return [ID_SLOT];
  return w.rule === 'updateRule' ? [GEBOORTEDATUM_SLOT, WERKGEBIED_SLOT] : [WERKGEBIED_SLOT];
}

async function voorwaarden(su) {
  kop('B. Voorwaarden op de server (alleen lezen)');
  for (const w of B2_WIJZIGINGEN) {
    const col = await su.collections.getOne(w.collectie);
    const regel = String(col[w.rule] ?? '');
    check(`${w.collectie}.${w.rule} heeft de B2-aanvulling`, stukkenVoor(w).every((x) => regel.includes(x)), 'draai 80 --apply');
  }
  const users = await su.collections.getOne('hh_users');
  check('hh_users.werkgebied_status bestaat', users.fields.some((f) => f.name === 'werkgebied_status'), 'draai 81 --apply');
  const wijken = await su.collection('hh_wijken').getFullList({ filter: 'actief = true' });
  const regio = wijken.find((w) => w.gemeente === REGIO_WIJK.gemeente && w.wijk === REGIO_WIJK.wijk && w.regio === true);
  check(`wijk "${REGIO_WIJK.wijk}" bestaat (actief, regio)`, !!regio, 'draai 81 --apply');
  const west = wijken.find((w) => w.wijk === 'Tiel-West');
  const pass = wijken.find((w) => w.wijk === 'Passewaaij');
  check('de oude wijken Tiel-West en Passewaaij staan er nog', !!west && !!pass);
  return { regio, west, pass };
}

async function main() {
  for (const c of ['hh_users', 'hh_profielen', 'hh_klussen', 'hh_meldingen', 'hh_auditlog']) assertHh(c);
  const su = await superuserClient();
  console.log('Verbonden met', PB_URL, APPLY ? '(APPLY)' : '(DRY-RUN)', '\n');

  if (!APPLY) {
    console.log('DRY-RUN: er wordt NIETS geschreven.');
    await voorwaarden(su);
    console.log('\nWat --apply ZOU doen:');
    console.log(`  · tijdelijke accounts maken (${MAIL_PREFIX}...${MAIL_DOMEIN}): coordinator, 3 bewoners, 8 helpers, 5 registraties;`);
    console.log('  · ADRES: 3 PDOK-verzoeken (Tiel, Ochten, Amsterdam; 10 min onthouden) + 1 Nominatim-verzoek (superuser met alleen een postcode);');
    console.log('  · vijf eigen open klussen (ook in Tiel-West en Passewaaij); per helper nameten wie ze ziet en wie mag accepteren;');
    console.log('  · een testfoto als ID uploaden, goedkeuren (coordinator en superuser), opnieuw uploaden geweigerd;');
    console.log('  · bekijken wat een bewoner van zijn helper ziet;');
    console.log('  · alles opruimen en nameten.');
    console.log(`\n${groen} groen, ${rood} rood (leescontroles).`);
    if (rood > 0) console.log('Rood is verwacht zolang 81 en 80 nog niet uitgerold zijn.');
    return;
  }

  kop('A. Opruimen van een eerdere run');
  await opruimen(su);
  if (ALLEEN_OPRUIMEN) {
    console.log('\nAlleen opgeruimd.');
    return;
  }

  const { regio, west, pass } = await voorwaarden(su);
  if (!regio || !west || !pass) {
    console.log('\nZonder de regio-wijk en de oude wijken kan de check niet verder.');
    process.exitCode = 1;
    return;
  }

  const wachtwoord = randomBytes(18).toString('base64url');
  const nieuwMail = (label) => `${MAIL_PREFIX}${label}-${randomBytes(4).toString('hex')}${MAIL_DOMEIN}`;
  const anon = anonClient();
  async function account(label, rol, extra = {}) {
    const email = nieuwMail(label);
    const record = await su.collection(assertHh('hh_users')).create({
      email,
      password: wachtwoord,
      passwordConfirm: wachtwoord,
      verified: true,
      rol,
      naam: `${MERK} ${label}`,
      taal: 'nl',
      ...extra,
    });
    return { id: record.id, record, email, client: await userClient(email, wachtwoord) };
  }
  const registreer = (label, extra) =>
    anon.collection('hh_users').create({
      email: nieuwMail(label),
      password: wachtwoord,
      passwordConfirm: wachtwoord,
      taal: 'nl',
      naam: `${MERK} ${label}`,
      ...extra,
    });

  // ---------------------------------------------------------------- C
  // ADRES (4 okt): aanmelden en verhuizen gaan via PDOK (postcode +
  // huisnummer moeten bestaan); het werkgebied komt uit het PDOK-punt.
  // Echte adressen (scripts/_adressen.mjs): Kerkstraat 1 Tiel, Kerkstraat 2
  // Ochten (~9 km), Dam 1 Amsterdam (buiten 20 km). Een adres dat niet
  // bestaat wordt nu GEWEIGERD (vroeger: aanmelden + status onbekend; dat
  // gebeurt nu alleen nog als PDOK onbereikbaar is, zie 122 sectie H).
  kop('C. Registreren: leeftijd, werkgebied uit het adres, geboortedatum vast');
  const teJong = await magNiet('helper van 9 registreert NIET', () =>
    registreer('negen', { rol: 'jongere', geboortedatum: geboren(10, 1), ...invoer(TIEL) }), [400]);
  check('  melding noemt 10 jaar', /10 jaar/.test(teJong?.response?.message ?? ''), teJong?.response?.message);
  await magNiet('ook de superuser maakt geen helper van 9', () =>
    su.collection(assertHh('hh_users')).create({
      email: nieuwMail('negen-su'), password: wachtwoord, passwordConfirm: wachtwoord,
      rol: 'jongere', naam: `${MERK} negen-su`, taal: 'nl', geboortedatum: geboren(9),
    }), [400]);
  const tien = await mag('helper van precies 10 registreert (Tiel, Kerkstraat 1)', () =>
    registreer('tien', { rol: 'jongere', geboortedatum: geboren(10), ...invoer(TIEL), ouder_email: 'ouder@heitjehulp.invalid' }));
  check('  binnen 20 km -> wijk "Tiel en omstreken", status binnen', tien?.wijk === regio.id && tien?.werkgebied_status === 'binnen', `wijk="${tien?.wijk}" status="${tien?.werkgebied_status}"`);
  const dorp = await mag('bewoner registreert in Ochten (Kerkstraat 2, 4051 AB)', () =>
    registreer('ochten', { rol: 'hulpvrager', adres: 'Dorpsstraat 1', plaats: 'Ochten', ...invoer(OCHTEN) }));
  check('  dorp binnen 20 km -> ook "Tiel en omstreken"', dorp?.wijk === regio.id && dorp?.werkgebied_status === 'binnen', `wijk="${dorp?.wijk}"`);
  const ver = await mag('bewoner registreert in Amsterdam (Dam 1, 1012 JS)', () =>
    registreer('amsterdam', { rol: 'hulpvrager', adres: 'Damstraat 1', plaats: 'Amsterdam', ...invoer(AMSTERDAM) }));
  check('  buiten 20 km -> geen wijk, status buiten', ver && !ver.wijk && ver.werkgebied_status === 'buiten', `wijk="${ver?.wijk}" status="${ver?.werkgebied_status}"`);
  await magNiet('ADRES: helper met een adres dat niet bestaat wordt geweigerd', () =>
    registreer('onbekend', { rol: 'jongere', geboortedatum: geboren(20), ...invoer(NIET_BESTAAND) }), [400]);
  await magNiet('registreren met zelfgekozen wijk wordt geweigerd', () =>
    registreer('zelfwijk', { rol: 'jongere', geboortedatum: geboren(20), wijk: regio.id, ...invoer(TIEL) }));
  await magNiet('registreren met zelfgekozen werkgebied_status wordt geweigerd', () =>
    registreer('zelfstatus', { rol: 'jongere', geboortedatum: geboren(20), werkgebied_status: 'binnen', ...invoer(TIEL) }));

  const eigen = await account('eigenaar', 'jongere', { geboortedatum: geboren(15), postcode: '4003 AB' });
  check('superuser-aanmaak met postcode krijgt ook de regio-wijk', eigen.record.wijk === regio.id, `wijk="${eigen.record.wijk}"`);
  const coord = await account('coordinator', 'coordinator');
  await magNiet('eigenaar wijzigt zijn geboortedatum NIET', () =>
    eigen.client.collection('hh_users').update(eigen.id, { geboortedatum: geboren(20) }));
  await magNiet('eigenaar kiest zelf geen wijk', () =>
    eigen.client.collection('hh_users').update(eigen.id, { wijk: west.id }));
  await mag('coordinator wijzigt de geboortedatum wel', () =>
    coord.client.collection('hh_users').update(eigen.id, { geboortedatum: geboren(16) }));
  await magNiet('ook de coordinator maakt geen helper van 9', () =>
    coord.client.collection('hh_users').update(eigen.id, { geboortedatum: geboren(9) }), [400]);
  const weg = await mag('eigenaar verhuist naar Amsterdam (Dam 1)', () =>
    eigen.client.collection('hh_users').update(eigen.id, invoer(AMSTERDAM)));
  check('  wijk gewist, status buiten', weg && !weg.wijk && weg.werkgebied_status === 'buiten', `wijk="${weg?.wijk}"`);
  const terug = await mag('eigenaar verhuist terug naar Tiel (Kerkstraat 1)', () =>
    eigen.client.collection('hh_users').update(eigen.id, invoer(TIEL)));
  check('  weer "Tiel en omstreken"', terug?.wijk === regio.id && terug?.werkgebied_status === 'binnen');
  await magNiet('ADRES: eigenaar verhuist naar een adres dat niet bestaat: geweigerd', () =>
    eigen.client.collection('hh_users').update(eigen.id, invoer(NIET_BESTAAND)), [400]);
  const kwijt = await su.collection('hh_users').getOne(eigen.id);
  check('  er verandert niets: wijk en status blijven', kwijt?.wijk === regio.id && kwijt?.werkgebied_status === 'binnen', `wijk="${kwijt?.wijk}"`);

  // ---------------------------------------------------------------- D
  kop('D. Klussen zien en accepteren');
  // Zonder postcode: geen geocoding, de wijk zoals de superuser hem zet.
  const bewoner = await account('bewoner', 'hulpvrager', { wijk: regio.id, adres: 'Teststraat 1', plaats: 'Tiel' });
  const helpers = {
    jongZonder: await account('jong-zonder', 'jongere', { geboortedatum: geboren(15), wijk: regio.id }),
    jongMet: await account('jong-met', 'jongere', { geboortedatum: geboren(15), wijk: regio.id, ouder_toestemming_op: nu() }),
    oudZonder: await account('oud-zonder', 'jongere', { geboortedatum: geboren(25), wijk: regio.id }),
    oudMet: await account('oud-met', 'jongere', { geboortedatum: geboren(25), wijk: regio.id }),
    // Oude wijken (bestaande data): Tiel-West en Passewaaij, met VOG.
    oudWest: await account('oud-west', 'jongere', { geboortedatum: geboren(25), wijk: west.id }),
    oudPass: await account('oud-pass', 'jongere', { geboortedatum: geboren(25), wijk: pass.id }),
  };
  for (const [label, h] of Object.entries(helpers)) {
    await su.collection(assertHh('hh_profielen')).create({
      gebruiker: h.id,
      verificatiestatus: 'goedgekeurd',
      ...(['oudMet', 'oudWest', 'oudPass'].includes(label) ? { vog_gezien_op: nu() } : {}),
    });
  }
  const klustype = (await su.collection('hh_klustypes').getList(1, 1)).items[0];
  const maakKlus = (van = bewoner) =>
    su.collection(assertHh('hh_klussen')).create({
      hulpvrager: van.id,
      geplaatst_door: van.id,
      klustype: klustype.id,
      omschrijving: `${MERK} testklus`,
      adres: 'Teststraat 1',
      lat: 51.88,
      lon: 5.42,
      status: 'open',
      bron: 'app',
      bedrag_bruto: 1000,
      vergoeding_jongere: 800,
      commissie: 200,
    });
  const k1 = await maakKlus();
  const k2 = await maakKlus();
  const ziet = async (h, k) => (await h.client.collection('hh_klussen').getList(1, 5, { filter: `id = "${k.id}"` })).totalItems === 1;

  check('onder 18 zonder toestemming ziet de open klus NIET', !(await ziet(helpers.jongZonder, k1)));
  check('18+ zonder VOG ziet de open klus NIET', !(await ziet(helpers.oudZonder, k1)));
  check('onder 18 met toestemming ziet de open klus', await ziet(helpers.jongMet, k1));
  check('18+ met VOG gezien ziet de open klus', await ziet(helpers.oudMet, k1));
  await magNiet('18+ zonder VOG haalt de klus ook niet los op (view)', () => helpers.oudZonder.client.collection('hh_klussen').getOne(k1.id), [404]);

  let r = await route(helpers.jongZonder.client, `/api/hh/klussen/${k1.id}/accepteren`);
  check(`onder 18 zonder toestemming accepteert NIET (403 ouder, kreeg ${r.status} ${r.body?.reden})`, r.status === 403 && r.body?.reden === 'ouder');
  r = await route(helpers.oudZonder.client, `/api/hh/klussen/${k1.id}/accepteren`);
  check(`18+ zonder VOG accepteert NIET (403 vog, kreeg ${r.status} ${r.body?.reden})`, r.status === 403 && r.body?.reden === 'vog');
  r = await route(helpers.jongMet.client, `/api/hh/klussen/${k1.id}/accepteren`);
  check(`onder 18 met toestemming, zonder VOG, accepteert (kreeg ${r.status})`, r.status === 200, JSON.stringify(r.body));
  r = await route(helpers.oudMet.client, `/api/hh/klussen/${k2.id}/accepteren`);
  check(`18+ met VOG gezien accepteert (kreeg ${r.status})`, r.status === 200, JSON.stringify(r.body));
  check('de eigen (toegewezen) klus blijft zichtbaar', await ziet(helpers.jongMet, k1));

  kop('D2. Regio-wijk naast de oude wijken (geen datamigratie)');
  const bewonerWest = await account('bewoner-west', 'hulpvrager', { wijk: west.id });
  const bewonerPass = await account('bewoner-pass', 'hulpvrager', { wijk: pass.id });
  const k3 = await maakKlus();
  const kWest = await maakKlus(bewonerWest);
  const kPass = await maakKlus(bewonerPass);
  check('helper in Tiel-West ziet de klus van een bewoner in "Tiel en omstreken"', await ziet(helpers.oudWest, k3));
  check('helper in Passewaaij ziet die ook', await ziet(helpers.oudPass, k3));
  check('helper in "Tiel en omstreken" ziet klussen in Tiel-West en Passewaaij', (await ziet(helpers.oudMet, kWest)) && (await ziet(helpers.oudMet, kPass)));
  // B3 (91-b3-wijken): zijn Tiel-West en Passewaaij allebei regio, dan
  // passen ze bij elkaar (iedereen in Tiel ziet alle klussen).
  if (west.regio === true && pass.regio === true) {
    check('B3: helper in Tiel-West ziet Tiel-West en Passewaaij (beide regio)', (await ziet(helpers.oudWest, kWest)) && (await ziet(helpers.oudWest, kPass)));
    r = await route(helpers.oudWest.client, `/api/hh/klussen/${kPass.id}/accepteren`);
    check(`B3: Tiel-West accepteert een Passewaaij-klus (kreeg ${r.status})`, r.status === 200, JSON.stringify(r.body));
  } else {
    check('oud gedrag: helper in Tiel-West ziet Tiel-West wel, Passewaaij niet', (await ziet(helpers.oudWest, kWest)) && !(await ziet(helpers.oudWest, kPass)));
    r = await route(helpers.oudWest.client, `/api/hh/klussen/${kPass.id}/accepteren`);
    check(`oud gedrag: Tiel-West accepteert geen Passewaaij-klus (409 wijk, kreeg ${r.status} ${r.body?.reden})`, r.status === 409 && r.body?.reden === 'wijk');
  }
  r = await route(helpers.oudMet.client, `/api/hh/klussen/${kWest.id}/accepteren`);
  check(`regio-helper accepteert een Tiel-West-klus (kreeg ${r.status})`, r.status === 200, JSON.stringify(r.body));
  r = await route(helpers.oudPass.client, `/api/hh/klussen/${k3.id}/accepteren`);
  check(`Passewaaij-helper accepteert een regio-klus (kreeg ${r.status})`, r.status === 200, JSON.stringify(r.body));

  // ---------------------------------------------------------------- E
  kop('E. ID-foto: na goedkeuring geen nieuwe upload');
  const nieuw = await account('nieuw', 'jongere', { geboortedatum: geboren(14), wijk: regio.id });
  const profiel = await mag('helper maakt zijn profiel aan', () =>
    nieuw.client.collection('hh_profielen').create({ gebruiker: nieuw.id }));
  await mag('helper uploadt een ID-foto (nog niet goedgekeurd)', () =>
    nieuw.client.collection('hh_profielen').update(profiel.id, { document_foto: png('id.png') }));
  await mag('helper biedt ter controle aan', () =>
    nieuw.client.collection('hh_profielen').update(profiel.id, { verificatiestatus: 'in_behandeling' }));
  await mag('coordinator keurt goed', () =>
    coord.client.collection('hh_profielen').update(profiel.id, { verificatiestatus: 'goedgekeurd' }));
  let p = await su.collection('hh_profielen').getOne(profiel.id);
  check('document_foto is leeg', !p.document_foto, p.document_foto);
  check('id_gecontroleerd_op gezet', !!p.id_gecontroleerd_op);
  check('id_gecontroleerd_door = de coordinator', p.id_gecontroleerd_door === coord.id, p.id_gecontroleerd_door);
  await magNiet('helper uploadt NA goedkeuring geen nieuwe ID-foto', () =>
    nieuw.client.collection('hh_profielen').update(profiel.id, { document_foto: png('id2.png') }));
  await magNiet('ook niet met document_foto+', () =>
    nieuw.client.collection('hh_profielen').update(profiel.id, { 'document_foto+': png('id3.png') }));
  p = await su.collection('hh_profielen').getOne(profiel.id);
  check('  er staat nog steeds geen document', !p.document_foto, p.document_foto);
  await mag('helper werkt over_mij nog wel bij', () =>
    nieuw.client.collection('hh_profielen').update(profiel.id, { over_mij: 'Ik help graag.' }));

  // ---------------------------------------------------------------- F
  kop('F. Goedkeuren via de superuser wist het document ook');
  const tweede = await account('tweede', 'jongere', { geboortedatum: geboren(30), wijk: regio.id });
  const p2 = await tweede.client.collection('hh_profielen').create({ gebruiker: tweede.id });
  const metFoto = await mag('tweede helper uploadt een ID-foto', () =>
    tweede.client.collection('hh_profielen').update(p2.id, { document_foto: png('id.png'), verificatiestatus: 'in_behandeling' }));
  const bestand = metFoto?.document_foto;
  await mag('superuser keurt goed', () => su.collection(assertHh('hh_profielen')).update(p2.id, { verificatiestatus: 'goedgekeurd' }));
  const p2na = await su.collection('hh_profielen').getOne(p2.id);
  check('document_foto is leeg', !p2na.document_foto, p2na.document_foto);
  check('id_gecontroleerd_op gezet', !!p2na.id_gecontroleerd_op);
  check('id_gecontroleerd_door blijft leeg (geen coordinator)', !p2na.id_gecontroleerd_door, p2na.id_gecontroleerd_door);
  if (bestand) {
    const token = await su.files.getToken();
    const res = await fetch(su.files.getURL({ ...p2na, document_foto: bestand }, bestand, { token }));
    check(`het bestand is weg op de server (superuser krijgt ${res.status})`, res.status === 404);
  }

  // ---------------------------------------------------------------- G
  kop('G. Wat een bewoner van zijn helper ziet');
  // jongMet heeft k1; keur hem langs de superuser opnieuw goed zodat hij een id_gecontroleerd_op heeft.
  const pj = (await su.collection('hh_profielen').getFullList({ filter: su.filter('gebruiker = {:id}', { id: helpers.jongMet.id }) }))[0];
  await su.collection(assertHh('hh_profielen')).update(pj.id, { verificatiestatus: 'in_behandeling' });
  await su.collection(assertHh('hh_profielen')).update(pj.id, { verificatiestatus: 'goedgekeurd' });
  const klus = await mag('bewoner haalt zijn klus op met de helper erbij', () =>
    bewoner.client.collection('hh_klussen').getOne(k1.id, { expand: 'toegewezen_jongere' }));
  const h = klus?.expand?.toegewezen_jongere;
  check('helper staat erbij', !!h);
  if (h) {
    check('  alleen de voornaam', h.naam === MERK, JSON.stringify(h.naam));
    check('  vinkje id_gecontroleerd = ja', h.id_gecontroleerd === true, JSON.stringify(h.id_gecontroleerd));
    for (const v of ['geboortedatum', 'postcode', 'huisnummer', 'adres', 'ouder_toestemming_op', 'ouder_email']) {
      check(`  geen ${v}`, !(v in h), JSON.stringify(h[v]));
    }
  }
  const zelf = await helpers.jongMet.client.collection('hh_users').getOne(helpers.jongMet.id);
  check('de helper ziet zijn eigen geboortedatum en ouder_toestemming_op', !!zelf.geboortedatum && !!zelf.ouder_toestemming_op);
  const viaCoord = await coord.client.collection('hh_users').getOne(helpers.jongMet.id);
  check('de coordinator ziet geboortedatum en de hele naam', !!viaCoord.geboortedatum && viaCoord.naam === `${MERK} jong-met`);
  check('helper zonder ID-controle: vinkje nee', (await coord.client.collection('hh_users').getOne(helpers.oudZonder.id)).id_gecontroleerd === false);

  // ---------------------------------------------------------------- H
  kop('H. Opruimen en nameten');
  await opruimen(su);
  const over = await su.collection('hh_users').getFullList({ filter: su.filter('email ~ {:p}', { p: MAIL_PREFIX }) });
  check('geen tijdelijke accounts meer', over.length === 0, `${over.length} over`);

  console.log(`\n${groen} groen, ${rood} rood.`);
  if (rood > 0) process.exitCode = 1;
}

main().catch(fail);
