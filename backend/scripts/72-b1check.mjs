// HeitjeHulp B1 — bewijst de B1-velden, -rules en de wis-hook op de ECHTE
// server. Werkt alleen met EIGEN tijdelijke accounts (e-mail
// "b1check-...@heitjehulp.invalid") en wordt aan het eind opgeruimd. Er doen
// GEEN seed-accounts mee.
//
//   A. opruimen van een eerdere (gecrashte) run
//   B. voorwaarden (ook in dry-run, alleen lezen): de 8 velden bestaan, het
//      B1-slot staat in create/updateRule van hh_users en hh_profielen
//   C. eigenaar mag ouder_email, ouder_telefoon en huisnummer zelf zetten
//      (bij registreren en bijwerken)
//   D. eigenaar kan de server-velden NIET zetten: ouder_toestemming_op,
//      ouder_iban_ok (hh_users, ook niet bij registreren), id_gecontroleerd_op,
//      id_gecontroleerd_door, vog_gezien_op (hh_profielen, aanmaken en
//      bijwerken); de coordinator wel
//   E. bewoner (rol hulpvrager) kan het profiel van een jongere niet lezen
//      (view, list) en dus document_foto niet ophalen, ook niet met een
//      eigen bestandstoken
//   F. goedkeuren door de coordinator wist document_foto (bestand weg op de
//      server), zet id_gecontroleerd_op = nu en id_gecontroleerd_door = de
//      coordinator; nogmaals goedgekeurd opslaan verandert niets; de
//      auditregel noemt document_foto zonder bestandsnaam; afwijzen wist niet
//   G. opruimen en nameten
//
// DRAAIEN (na 70 --apply, 71 --apply en 73-hook-deploy.sh):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/72-b1check.mjs            (dry-run: alleen leescontroles)
//   node scripts/72-b1check.mjs --apply
//   node scripts/72-b1check.mjs --apply --alleen-opruimen

import { randomBytes } from 'node:crypto';
import { superuserClient, userClient, anonClient, assertHh, APPLY, fail, PB_URL } from './_lib.mjs';
import { B1_VELDNAMEN } from './70-b1-velden.mjs';
import { B1_SLOT_VELDEN, slot } from './71-b1-rules.mjs';
import { TIEL } from './_adressen.mjs';

const MAIL_PREFIX = 'b1check-';
const MAIL_DOMEIN = '@heitjehulp.invalid';
const MERK = '[b1check]';
const ALLEEN_OPRUIMEN = process.argv.includes('--alleen-opruimen');
const WEIGER = [400, 403, 404];

// Kleinste geldige PNG (1x1). PocketBase controleert het mimetype op inhoud.
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
    check(label, false, `status=${e?.status} ${e?.response?.message ?? e?.message ?? ''}`);
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

/// Status van een bestand ophalen, met of zonder bestandstoken van [client].
async function bestandStatus(client, record, naam, metToken) {
  const token = metToken ? await client.files.getToken() : undefined;
  const url = client.files.getURL(record, naam, token ? { token } : {});
  const res = await fetch(url);
  return res.status;
}

async function opruimen(su) {
  const tijdelijk = await su.collection('hh_users').getFullList({
    filter: su.filter('email ~ {:prefix}', { prefix: MAIL_PREFIX }),
  });
  let aantal = 0;
  for (const u of tijdelijk) {
    const profielen = await su.collection('hh_profielen').getFullList({
      filter: su.filter('gebruiker = {:id}', { id: u.id }),
    });
    const ids = [u.id, ...profielen.map((p) => p.id)];
    for (const id of ids) {
      const regels = await su.collection('hh_auditlog').getFullList({
        filter: su.filter('door = {:id} || doel_id = {:id}', { id }),
      });
      for (const r of regels) await su.collection(assertHh('hh_auditlog')).delete(r.id);
      aantal += regels.length;
    }
  }
  // Profielen gaan mee met de gebruiker (cascade).
  for (const u of tijdelijk) await su.collection(assertHh('hh_users')).delete(u.id);
  aantal += tijdelijk.length;
  if (aantal) console.log(`  ↻ ${aantal} record(s) verwijderd (waarvan ${tijdelijk.length} tijdelijk(e) account(s))`);
  return tijdelijk.length;
}

async function voorwaarden(su) {
  kop('B. Voorwaarden op de server (alleen lezen)');
  for (const [naam, velden] of Object.entries(B1_VELDNAMEN)) {
    const col = await su.collections.getOne(naam);
    for (const v of velden) check(`${naam}.${v} bestaat`, col.fields.some((f) => f.name === v), 'draai 70 --apply');
  }
  for (const [naam, velden] of Object.entries(B1_SLOT_VELDEN)) {
    const col = await su.collections.getOne(naam);
    for (const k of ['createRule', 'updateRule']) {
      check(`${naam}.${k} heeft het B1-slot`, String(col[k] ?? '').includes(slot(velden)), 'draai 71 --apply');
    }
  }
}

async function main() {
  for (const c of ['hh_users', 'hh_profielen', 'hh_auditlog']) assertHh(c);
  const su = await superuserClient();
  console.log('Verbonden met', PB_URL, APPLY ? '(APPLY)' : '(DRY-RUN)', '\n');

  if (!APPLY) {
    console.log('DRY-RUN: er wordt NIETS geschreven.');
    await voorwaarden(su);
    console.log('\nWat --apply ZOU doen:');
    console.log(`  · tijdelijke accounts maken (${MAIL_PREFIX}...${MAIL_DOMEIN}): coordinator, bewoner, 2 jongeren, 1 registratie;`);
    console.log('  · per veld nameten wie het mag zetten (eigenaar / coordinator);');
    console.log('  · een testfoto als document_foto uploaden, bewoner kan er niet bij;');
    console.log('  · goedkeuren: document_foto weg (ook het bestand), id_gecontroleerd_op/_door gezet;');
    console.log('  · alles opruimen en nameten.');
    console.log(`\n${groen} groen, ${rood} rood (leescontroles).`);
    if (rood > 0) console.log('Rood is verwacht zolang 70 en 71 nog niet uitgerold zijn.');
    return;
  }

  kop('A. Opruimen van een eerdere run');
  await opruimen(su);
  if (ALLEEN_OPRUIMEN) {
    console.log('\nAlleen opgeruimd.');
    return;
  }

  await voorwaarden(su);

  const wachtwoord = randomBytes(18).toString('base64url');
  const nieuwMail = (label) => `${MAIL_PREFIX}${label}-${randomBytes(4).toString('hex')}${MAIL_DOMEIN}`;
  async function tijdelijkAccount(label, rol) {
    const email = nieuwMail(label);
    const record = await su.collection(assertHh('hh_users')).create({
      email,
      password: wachtwoord,
      passwordConfirm: wachtwoord,
      verified: true,
      rol,
      naam: `${MERK} ${label}`,
      taal: 'nl',
    });
    return { id: record.id, email, client: await userClient(email, wachtwoord) };
  }

  const coord = await tijdelijkAccount('coordinator', 'coordinator');
  const bewoner = await tijdelijkAccount('bewoner', 'hulpvrager');
  const helper = await tijdelijkAccount('helper', 'jongere');
  const helper2 = await tijdelijkAccount('helper2', 'jongere');
  const anon = anonClient();
  const nu = new Date().toISOString().replace('T', ' ');

  kop('C. Eigenaar zet ouder_email, ouder_telefoon en huisnummer zelf');
  const regMail = nieuwMail('registratie');
  const reg = await mag('registreren (anoniem) met ouder_email, ouder_telefoon, huisnummer', () =>
    anon.collection('hh_users').create({
      email: regMail,
      password: wachtwoord,
      passwordConfirm: wachtwoord,
      rol: 'jongere',
      naam: `${MERK} registratie`,
      taal: 'nl',
      ouder_email: 'ouder@heitjehulp.invalid',
      ouder_telefoon: '0612345678',
      // ADRES (4 okt): een helper meldt zich alleen aan met een bestaand
      // adres (PDOK): postcode + huisnummer van Kerkstraat 1, 4001 MA Tiel.
      postcode: TIEL.postcode,
      huisnummer: TIEL.huisnummer,
    }));
  if (reg) {
    const terug = await su.collection('hh_users').getOne(reg.id);
    check('waarden staan zoals gestuurd', terug.ouder_email === 'ouder@heitjehulp.invalid' && terug.ouder_telefoon === '0612345678' && terug.huisnummer === TIEL.huisnummer);
  }
  // ADRES: een huisnummer los wijzigen zonder geldig adres kan niet meer
  // (122 bewijst dat); hier alleen de ouder-velden.
  const bijgewerkt = await mag('helper werkt ouder_email/ouder_telefoon bij', () =>
    helper.client.collection('hh_users').update(helper.id, {
      ouder_email: 'ouder2@heitjehulp.invalid',
      ouder_telefoon: '0687654321',
    }));
  check('bijgewerkte waarden staan', bijgewerkt?.ouder_telefoon === '0687654321' && bijgewerkt?.ouder_email === 'ouder2@heitjehulp.invalid');

  kop('D. Server-velden: eigenaar NIET, coordinator wel');
  await magNiet('registreren met ouder_toestemming_op geweigerd', () =>
    anon.collection('hh_users').create({
      email: nieuwMail('reg-toestemming'),
      password: wachtwoord,
      passwordConfirm: wachtwoord,
      rol: 'jongere',
      naam: `${MERK} reg`,
      ouder_toestemming_op: nu,
      // ADRES: met een bestaand adres, zodat de RULE weigert.
      postcode: TIEL.postcode,
      huisnummer: TIEL.huisnummer,
    }));
  await magNiet('registreren met ouder_iban_ok geweigerd', () =>
    anon.collection('hh_users').create({
      email: nieuwMail('reg-iban'),
      password: wachtwoord,
      passwordConfirm: wachtwoord,
      rol: 'jongere',
      naam: `${MERK} reg`,
      ouder_iban_ok: true,
      // ADRES: met een bestaand adres, zodat de RULE weigert.
      postcode: TIEL.postcode,
      huisnummer: TIEL.huisnummer,
    }));
  await magNiet('helper zet eigen ouder_toestemming_op', () =>
    helper.client.collection('hh_users').update(helper.id, { ouder_toestemming_op: nu }));
  await magNiet('helper zet eigen ouder_iban_ok', () =>
    helper.client.collection('hh_users').update(helper.id, { ouder_iban_ok: true }));
  await magNiet('helper zet ouder_iban_ok samen met een vrij veld', () =>
    helper.client.collection('hh_users').update(helper.id, { ouder_telefoon: '0611111111', ouder_iban_ok: true }));

  // helper2 heeft nog geen profiel: aanmaken met een server-veld moet falen.
  for (const veld of B1_SLOT_VELDEN.hh_profielen) {
    const waarde = veld === 'id_gecontroleerd_door' ? helper2.id : nu;
    await magNiet(`helper2 maakt profiel aan met ${veld}`, () =>
      helper2.client.collection('hh_profielen').create({ gebruiker: helper2.id, [veld]: waarde }));
  }
  const profiel2 = await mag('helper2 maakt profiel aan zonder server-velden', () =>
    helper2.client.collection('hh_profielen').create({ gebruiker: helper2.id }));

  const profiel = await su.collection(assertHh('hh_profielen')).create({ gebruiker: helper.id });
  for (const veld of B1_SLOT_VELDEN.hh_profielen) {
    const waarde = veld === 'id_gecontroleerd_door' ? helper.id : nu;
    await magNiet(`helper zet eigen ${veld}`, () =>
      helper.client.collection('hh_profielen').update(profiel.id, { [veld]: waarde }));
  }
  const doorCoord = await mag('coordinator zet ouder_toestemming_op en ouder_iban_ok', () =>
    coord.client.collection('hh_users').update(helper.id, { ouder_toestemming_op: nu, ouder_iban_ok: true }));
  check('waarden staan', !!doorCoord?.ouder_toestemming_op && doorCoord?.ouder_iban_ok === true);
  const vogDoorCoord = await mag('coordinator zet vog_gezien_op', () =>
    coord.client.collection('hh_profielen').update(profiel.id, { vog_gezien_op: nu }));
  check('vog_gezien_op staat', !!vogDoorCoord?.vog_gezien_op);
  if (profiel2) {
    await mag('coordinator zet id_gecontroleerd_op/_door met de hand', () =>
      coord.client.collection('hh_profielen').update(profiel2.id, { id_gecontroleerd_op: nu, id_gecontroleerd_door: coord.id }));
  }

  kop('E. Bewoner kan niet bij het profiel of de ID-foto van een helper');
  const metDoc = await mag('helper uploadt document_foto en biedt aan ter controle', () =>
    helper.client.collection('hh_profielen').update(profiel.id, {
      document_foto: png('document.png'),
      verificatiestatus: 'in_behandeling',
    }));
  const bestandsnaam = metDoc?.document_foto || '';
  check('document_foto staat op het record', !!bestandsnaam);
  const suRecord = await su.collection('hh_profielen').getOne(profiel.id);
  check('superuser haalt het bestand op (200, controle van de test zelf)', (await bestandStatus(su, suRecord, bestandsnaam, true)) === 200);
  await magNiet('bewoner leest het profiel van de helper (view)', () => bewoner.client.collection('hh_profielen').getOne(profiel.id));
  const lijst = await bewoner.client.collection('hh_profielen').getList(1, 50, {
    filter: bewoner.client.filter('gebruiker = {:id}', { id: helper.id }),
  });
  check('bewoner ziet het profiel niet in de lijst', lijst.totalItems === 0, `${lijst.totalItems} rij(en)`);
  const bewonerMet = await bestandStatus(bewoner.client, suRecord, bestandsnaam, true);
  check(`bewoner haalt document_foto niet op met eigen bestandstoken (${bewonerMet})`, bewonerMet >= 400 && bewonerMet < 500);
  const bewonerZonder = await bestandStatus(bewoner.client, suRecord, bestandsnaam, false);
  check(`bewoner haalt document_foto niet op zonder token (${bewonerZonder})`, bewonerZonder >= 400 && bewonerZonder < 500);
  const helper2Met = await bestandStatus(helper2.client, suRecord, bestandsnaam, true);
  check(`andere helper haalt document_foto niet op (${helper2Met})`, helper2Met >= 400 && helper2Met < 500);

  kop('F. Goedkeuren wist het ID-document');
  const voor = Date.now();
  const goed = await mag('coordinator keurt goed', () =>
    coord.client.collection('hh_profielen').update(profiel.id, { verificatiestatus: 'goedgekeurd' }));
  check('document_foto is leeg', goed && !goed.document_foto, JSON.stringify(goed?.document_foto));
  check('id_gecontroleerd_door = de coordinator', goed?.id_gecontroleerd_door === coord.id, goed?.id_gecontroleerd_door);
  const op = goed?.id_gecontroleerd_op ? Date.parse(goed.id_gecontroleerd_op.replace(' ', 'T')) : NaN;
  check('id_gecontroleerd_op = nu (binnen 2 minuten)', Math.abs(op - voor) < 120000, goed?.id_gecontroleerd_op);
  const naStatus = await bestandStatus(su, suRecord, bestandsnaam, true);
  check(`het bestand is weg op de server (superuser krijgt ${naStatus})`, naStatus === 404);

  const nogmaals = await mag('coordinator slaat nogmaals goedgekeurd op', () =>
    coord.client.collection('hh_profielen').update(profiel.id, { verificatiestatus: 'goedgekeurd' }));
  check('id_gecontroleerd_op blijft gelijk', nogmaals?.id_gecontroleerd_op === goed?.id_gecontroleerd_op);

  const regels = await su.collection('hh_auditlog').getFullList({
    filter: su.filter('door = {:door} && doel_id = {:id} && actie = "wijzigen"', { door: coord.id, id: profiel.id }),
  });
  const goedRegel = regels.find((r) => (r.detail?.velden || []).includes('document_foto'));
  check('auditregel noemt document_foto', !!goedRegel, `${regels.length} regel(s)`);
  if (goedRegel) {
    const tekst = JSON.stringify(goedRegel.detail);
    check('auditregel bevat geen bestandsnaam', !tekst.includes(bestandsnaam) && !('document_foto' in (goedRegel.detail.van || {})));
  }

  if (profiel2) {
    const metDoc2 = await mag('helper2 uploadt document_foto', () =>
      helper2.client.collection('hh_profielen').update(profiel2.id, { document_foto: png('document2.png') }));
    const af = await mag('coordinator wijst af', () =>
      coord.client.collection('hh_profielen').update(profiel2.id, { verificatiestatus: 'afgewezen' }));
    check('afwijzen wist document_foto NIET (alleen goedkeuren)', !!metDoc2?.document_foto && af?.document_foto === metDoc2.document_foto);
  }

  kop('G. Opruimen en nameten');
  await opruimen(su);
  const rest = await su.collection('hh_users').getList(1, 1, {
    filter: su.filter('email ~ {:prefix}', { prefix: MAIL_PREFIX }),
  });
  check('geen tijdelijke accounts meer', rest.totalItems === 0, `${rest.totalItems} over`);

  console.log(`\n${groen} groen, ${rood} rood.`);
  if (rood > 0) process.exit(1);
}

main().catch(fail);
