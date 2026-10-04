// HeitjeHulp B11 — hh_meldkamer_hulp.js zonder server: partnercode,
// kennismaking (gesproken/geweigerd + wachten bij keuren), VOG-wachtrij,
// partner-tellers en het signaal "zelfde paar". De echte rules en
// PocketBase bewijst 152-b11check.mjs.
// Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { laadHulp, nepApp, NepRecord, pbDatum } from './_nep_app.mjs';

const hulp = laadHulp('hh_meldkamer_hulp.js');

// Zondag 4 oktober 2026, 10:00 UTC.
const NU = Date.parse('2026-10-04T10:00:00Z');
const DAG = 24 * 3600 * 1000;

function wereld(extra = {}) {
  const rijen = {
    hh_users: [
      { id: 'coord', rol: 'coordinator', naam: 'Meldkamer', created: '2026-09-01 10:00:00.000Z' },
      { id: 'b1', rol: 'hulpvrager', naam: 'Anja de Vries' },
      { id: 'b2', rol: 'hulpvrager', naam: 'Kees Bakker', kennismaking_status: 'gesproken' },
      { id: 'h14', rol: 'jongere', naam: 'Daan Mulder', geboortedatum: '2012-03-01 00:00:00.000Z', partner: 'p-tiel' },
      { id: 'h20', rol: 'jongere', naam: 'Sanne Smit', geboortedatum: '2006-01-01 00:00:00.000Z', partner: 'p-tiel' },
      { id: 'h30', rol: 'jongere', naam: 'Ruud Jansen', geboortedatum: '1996-05-05 00:00:00.000Z' },
      { id: 'h18', rol: 'jongere', naam: 'Eva Jong', geboortedatum: '2008-10-05 00:00:00.000Z' },
    ],
    hh_profielen: [
      { id: 'p14', gebruiker: 'h14', verificatiestatus: 'goedgekeurd' },
      { id: 'p20', gebruiker: 'h20', verificatiestatus: 'in_behandeling' },
      { id: 'p30', gebruiker: 'h30', verificatiestatus: 'goedgekeurd', vog_gezien_op: '2023-09-01 10:00:00.000Z' },
      { id: 'p18', gebruiker: 'h18', verificatiestatus: 'goedgekeurd' },
    ],
    hh_partners: [
      { id: 'p-tiel', naam: 'Jongerenwerk Tiel', code: 'TIEL-JW', actief: true },
      { id: 'p-oud', naam: 'Oude partner', code: 'OUD', actief: false },
    ],
    hh_instellingen: [],
    hh_klussen: [],
    hh_klus_status: [],
    hh_incidenten: [],
    hh_auditlog: [],
    ...extra,
  };
  return nepApp(rijen, { klok: () => NU, uniek: {} });
}

const env = (app) => ({ app, Record: NepRecord, nu: () => NU });
const zet = (app, sleutel, waarde) => app.save(new NepRecord('hh_instellingen', { sleutel, waarde }));

// ---- partnercode -----------------------------------------------------------

test('partnercode: leeg = geen partner, hoofdletters/spaties maken niet uit', () => {
  const app = wereld();
  assert.deepEqual(hulp.partnerVoorCode(app, ''), { ok: true, partner: '' });
  assert.deepEqual(hulp.partnerVoorCode(app, '   '), { ok: true, partner: '' });
  assert.deepEqual(hulp.partnerVoorCode(app, ' tiel-jw '), { ok: true, partner: 'p-tiel' });
});

test('partnercode: onbekend, ongeldig of niet actief = weigeren', () => {
  const app = wereld();
  assert.equal(hulp.partnerVoorCode(app, 'BESTAATNIET').ok, false);
  assert.equal(hulp.partnerVoorCode(app, 'a"||1=1').ok, false, 'rare tekens komen nooit in een filter');
  assert.equal(hulp.partnerVoorCode(app, 'OUD').ok, false, 'niet actief telt niet');
  assert.equal(hulp.partnerVoorCode(app, 'X'.repeat(21)).ok, false);
  assert.match(hulp.MELDING_CODE, /code/i);
});

test('normaliseerCode: A-Z, 0-9 en streepje, 3 tot 20 tekens', () => {
  assert.equal(hulp.normaliseerCode('tiel jw'), 'TIELJW');
  assert.equal(hulp.normaliseerCode('ab'), '');
  assert.equal(hulp.normaliseerCode('ok-123'), 'OK-123');
  assert.equal(hulp.normaliseerCode('é-ok'), '');
});

// ---- instellingen ----------------------------------------------------------

test('instellingen: aan/uit en getallen, met standaardwaarde', () => {
  const app = wereld();
  assert.equal(hulp.instellingAan(app, hulp.INSTELLING.KENNISMAKING), false);
  assert.equal(hulp.instellingGetal(app, hulp.INSTELLING.PAAR_AANTAL, 4), 4);
  zet(app, hulp.INSTELLING.KENNISMAKING, true);
  zet(app, hulp.INSTELLING.PAAR_AANTAL, 6);
  zet(app, hulp.INSTELLING.PAAR_DAGEN, 'kapot');
  assert.equal(hulp.instellingAan(app, hulp.INSTELLING.KENNISMAKING), true);
  assert.equal(hulp.instellingGetal(app, hulp.INSTELLING.PAAR_AANTAL, 4), 6);
  assert.equal(hulp.instellingGetal(app, hulp.INSTELLING.PAAR_DAGEN, 30), 30, 'geen getal = standaard');
});

test('instellingen: json als tekst (zoals de JSVM bytes geeft) wordt gelezen', () => {
  const app = wereld();
  const rij = new NepRecord('hh_instellingen', { sleutel: hulp.INSTELLING.PAAR_AANTAL, waarde: [53] });
  rij.getString = () => '5';
  app.save(rij);
  assert.equal(hulp.instellingGetal(app, hulp.INSTELLING.PAAR_AANTAL, 4), 5);
});

// ---- kennismaking ----------------------------------------------------------

test('wachtOpKennismaking: alleen met schakelaar aan en bewoner niet gesproken', () => {
  const app = wereld();
  assert.equal(hulp.wachtOpKennismaking(app, 'b1'), false, 'schakelaar uit');
  zet(app, hulp.INSTELLING.KENNISMAKING, true);
  assert.equal(hulp.wachtOpKennismaking(app, 'b1'), true);
  assert.equal(hulp.wachtOpKennismaking(app, 'b2'), false, 'gesproken');
  assert.equal(hulp.wachtOpKennismaking(app, 'bestaatniet'), false);
});

test('kennismaking gesproken: velden gezet, auditregel, niets geannuleerd', () => {
  const app = wereld();
  const uit = hulp.kennismaking(env(app), { coordinatorId: 'coord', userId: 'b1', besluit: 'gesproken', notitie: ' Aardige dame ' });
  assert.equal(uit.status, 200);
  assert.deepEqual(uit.body, { gebruiker: 'b1', kennismaking_status: 'gesproken', geannuleerd: 0, lopend: 0 });
  const b1 = app.findRecordById('hh_users', 'b1');
  assert.equal(b1.get('kennismaking_status'), 'gesproken');
  assert.equal(b1.get('kennismaking_door'), 'coord');
  assert.equal(b1.get('kennismaking_op'), pbDatum(NU));
  assert.equal(b1.get('kennismaking_notitie'), 'Aardige dame');
  assert.notEqual(b1.get('geblokkeerd'), true);
  const audit = app.db.hh_auditlog;
  assert.equal(audit.length, 1);
  assert.equal(audit[0].get('actie'), 'wijzigen');
  assert.equal(audit[0].get('doel_id'), 'b1');
  assert.deepEqual(audit[0].get('detail').velden, ['kennismaking_status']);
});

test('kennismaking geweigerd: geblokkeerd + open/concept-klussen zonder helper geannuleerd met logregel', () => {
  const app = wereld({
    hh_klussen: [
      { id: 'k-open', hulpvrager: 'b1', status: 'open', toegewezen_jongere: '' },
      { id: 'k-concept', hulpvrager: 'b1', status: 'concept', toegewezen_jongere: '' },
      { id: 'k-bezig', hulpvrager: 'b1', status: 'geaccepteerd', toegewezen_jongere: 'h30' },
      { id: 'k-ander', hulpvrager: 'b2', status: 'open', toegewezen_jongere: '' },
    ],
  });
  const uit = hulp.kennismaking(env(app), { coordinatorId: 'coord', userId: 'b1', besluit: 'geweigerd', notitie: '' });
  assert.equal(uit.status, 200);
  assert.equal(uit.body.geannuleerd, 2);
  assert.equal(uit.body.lopend, 1, 'een klus met helper blijft staan: de meldkamer kijkt zelf');
  assert.equal(app.findRecordById('hh_users', 'b1').get('geblokkeerd'), true);
  assert.equal(app.findRecordById('hh_klussen', 'k-open').get('status'), 'geannuleerd');
  assert.equal(app.findRecordById('hh_klussen', 'k-concept').get('status'), 'geannuleerd');
  assert.equal(app.findRecordById('hh_klussen', 'k-bezig').get('status'), 'geaccepteerd');
  assert.equal(app.findRecordById('hh_klussen', 'k-ander').get('status'), 'open');
  const logs = app.db.hh_klus_status;
  assert.equal(logs.length, 2);
  assert.deepEqual(logs.map((l) => l.get('van')).sort(), ['concept', 'open']);
  assert.ok(logs.every((l) => l.get('naar') === 'geannuleerd' && l.get('door') === 'coord'));
  assert.match(logs[0].get('toelichting'), /kennismaking/);
  assert.equal(app.log.transacties, 1);
});

test('kennismaking: fout besluit, te lange notitie, geen bewoner, niet gevonden', () => {
  const app = wereld();
  assert.equal(hulp.kennismaking(env(app), { coordinatorId: 'coord', userId: 'b1', besluit: 'misschien' }).status, 400);
  assert.equal(hulp.kennismaking(env(app), { coordinatorId: 'coord', userId: 'b1', besluit: 'gesproken', notitie: 'x'.repeat(501) }).status, 400);
  const helper = hulp.kennismaking(env(app), { coordinatorId: 'coord', userId: 'h30', besluit: 'gesproken' });
  assert.equal(helper.status, 409);
  assert.equal(helper.body.reden, 'rol');
  assert.equal(hulp.kennismaking(env(app), { coordinatorId: 'coord', userId: 'weg', besluit: 'gesproken' }).status, 404);
  assert.equal(app.db.hh_auditlog.length, 0);
});

test('kennismaking: geweigerde bewoner later toch gesproken = deblokkeren is aan de meldkamer (blijft geblokkeerd)', () => {
  const app = wereld();
  hulp.kennismaking(env(app), { coordinatorId: 'coord', userId: 'b1', besluit: 'geweigerd' });
  hulp.kennismaking(env(app), { coordinatorId: 'coord', userId: 'b1', besluit: 'gesproken' });
  const b1 = app.findRecordById('hh_users', 'b1');
  assert.equal(b1.get('kennismaking_status'), 'gesproken');
  assert.equal(b1.get('geblokkeerd'), true, 'deblokkeren gaat bewust apart (Gebruikers)');
});

// ---- VOG-wachtrij ----------------------------------------------------------

test('leeftijd op een dag: verjaardag telt pas op de dag zelf', () => {
  assert.equal(hulp.leeftijd('2008-10-05 00:00:00.000Z', NU), 17);
  assert.equal(hulp.leeftijd('2008-10-04 00:00:00.000Z', NU), 18);
  assert.equal(hulp.leeftijd('', NU), null);
});

test('VOG-wachtrij: 18+ helpers zonder VOG of met verlopen VOG (3 jaar), geen <18, geen afgewezen', () => {
  const app = wereld({
    hh_users: [
      ...wereld().db.hh_users.map((r) => ({ id: r.id, ...r.data })),
      { id: 'h40', rol: 'jongere', naam: 'Afgewezen', geboortedatum: '1986-01-01 00:00:00.000Z' },
      { id: 'h25', rol: 'jongere', naam: 'Met VOG', geboortedatum: '2001-01-01 00:00:00.000Z' },
    ],
    hh_profielen: [
      ...wereld().db.hh_profielen.map((r) => ({ id: r.id, ...r.data })),
      { id: 'p40', gebruiker: 'h40', verificatiestatus: 'afgewezen' },
      { id: 'p25', gebruiker: 'h25', verificatiestatus: 'goedgekeurd', vog_gezien_op: '2026-01-01 10:00:00.000Z' },
    ],
  });
  const lijst = hulp.vogWachtrij(app, NU);
  const op = Object.fromEntries(lijst.map((r) => [r.gebruiker, r]));
  assert.deepEqual(Object.keys(op).sort(), ['h20', 'h30']);
  assert.equal(op.h20.reden, 'geen');
  assert.equal(op.h20.leeftijd, 20);
  assert.equal(op.h20.naam, 'Sanne Smit');
  assert.equal(op.h20.verificatiestatus, 'in_behandeling');
  assert.equal(op.h30.reden, 'verlopen');
  assert.equal(op.h30.verloopt_op, '2026-09-01');
  assert.equal(lijst[0].reden, 'geen', 'eerst wie nog niets heeft');
});

// ---- partner-tellers -------------------------------------------------------

test('partnerTellers: aangemeld en goedgekeurd per partner, ook niet-actieve', () => {
  const app = wereld();
  const lijst = hulp.partnerTellers(app);
  const tiel = lijst.find((p) => p.id === 'p-tiel');
  assert.deepEqual(tiel, { id: 'p-tiel', naam: 'Jongerenwerk Tiel', code: 'TIEL-JW', actief: true, aangemeld: 2, goedgekeurd: 1 });
  assert.deepEqual(lijst.find((p) => p.id === 'p-oud'), { id: 'p-oud', naam: 'Oude partner', code: 'OUD', actief: false, aangemeld: 0, goedgekeurd: 0 });
});

// ---- zelfde paar -----------------------------------------------------------

function paarWereld(helper, aantalEerder, opties = {}) {
  const klussen = [];
  const logs = [];
  for (let i = 0; i <= aantalEerder; i++) {
    klussen.push({ id: `k${i}`, hulpvrager: 'b2', toegewezen_jongere: helper, status: 'afgerond' });
    logs.push({ id: `s${i}`, klus: `k${i}`, van: 'bezig', naar: 'afgerond', created: pbDatum(NU - (opties.dagenTerug ? opties.dagenTerug(i) : i) * DAG) });
  }
  const app = wereld({ hh_klussen: klussen, hh_klus_status: logs });
  if (opties.aan !== false) zet(app, hulp.INSTELLING.PAAR_AAN, true);
  return { app, laatste: app.findRecordById('hh_klus_status', 's0') };
}

test('zelfde paar: helper <18, 4e afgeronde klus met dezelfde bewoner binnen 30 dagen = één signaal', () => {
  const { app, laatste } = paarWereld('h14', 3);
  const id = hulp.zelfdePaar(env(app), laatste);
  assert.ok(id);
  const inc = app.db.hh_incidenten;
  assert.equal(inc.length, 1);
  assert.equal(inc[0].get('soort'), 'signaal');
  assert.equal(inc[0].get('klus'), 'k0');
  assert.equal(inc[0].get('melder'), 'coord', 'nooit de helper of bewoner: die zouden het signaal zelf lezen');
  assert.match(inc[0].get('omschrijving'), /^\[zelfde paar\] /);
  assert.match(inc[0].get('omschrijving'), /Daan \(14\)/);
  assert.match(inc[0].get('omschrijving'), /Kees/);
  assert.match(inc[0].get('omschrijving'), /4 klussen/);
  assert.doesNotMatch(inc[0].get('omschrijving'), /Mulder|Bakker/, 'alleen voornamen');
  // Tweede keer (5e klus) binnen dezelfde periode: geen nieuw signaal.
  assert.equal(hulp.zelfdePaar(env(app), laatste), '');
  assert.equal(app.db.hh_incidenten.length, 1);
});

test('zelfde paar: 3e klus geen signaal; volwassen helper nooit; schakelaar uit nooit', () => {
  assert.equal(hulp.zelfdePaar(env(paarWereld('h14', 2).app), paarWereld('h14', 2).laatste), '');
  const v = paarWereld('h20', 5);
  assert.equal(hulp.zelfdePaar(env(v.app), v.laatste), '');
  const uit = paarWereld('h14', 5, { aan: false });
  assert.equal(hulp.zelfdePaar(env(uit.app), uit.laatste), '');
});

test('zelfde paar: klussen buiten de periode tellen niet; drempel en periode uit de instellingen', () => {
  const oud = paarWereld('h14', 3, { dagenTerug: (i) => (i === 0 ? 0 : 40 + i) });
  assert.equal(hulp.zelfdePaar(env(oud.app), oud.laatste), '');
  const laag = paarWereld('h14', 1);
  zet(laag.app, hulp.INSTELLING.PAAR_AANTAL, 2);
  assert.ok(hulp.zelfdePaar(env(laag.app), laag.laatste));
});

test('zelfde paar: alleen bij naar = afgerond; zelfde klus twee keer afgerond telt één keer', () => {
  const { app, laatste } = paarWereld('h14', 2);
  app.save(new NepRecord('hh_klus_status', { klus: 'k1', van: 'probleem', naar: 'afgerond', created: pbDatum(NU) }));
  assert.equal(hulp.zelfdePaar(env(app), laatste), '', '3 verschillende klussen, niet 4');
  const ander = new NepRecord('hh_klus_status', { klus: 'k0', van: 'open', naar: 'geaccepteerd' });
  assert.equal(hulp.zelfdePaar(env(app), ander), '');
});

test('zelfde paar: zonder coordinator-account geen signaal (en geen fout)', () => {
  const { app, laatste } = paarWereld('h14', 3);
  app.db.hh_users = app.db.hh_users.filter((r) => r.id !== 'coord');
  assert.equal(hulp.zelfdePaar(env(app), laatste), '');
});
