// HeitjeHulp B2 — test van backend/pb_hooks/hh_aanmelden_hulp.js zonder server.
// Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const hier = path.dirname(fileURLToPath(import.meta.url));
const bron = readFileSync(path.join(hier, '..', 'pb_hooks', 'hh_aanmelden_hulp.js'), 'utf8');
const module_ = { exports: {} };
new Function('module', 'exports', bron)(module_, module_.exports);
const hulp = module_.exports;

test('leeftijd: verjaardag telt pas op de dag zelf', () => {
  assert.equal(hulp.leeftijd('2008-10-03 00:00:00.000Z', '2026-10-03'), 18);
  assert.equal(hulp.leeftijd('2008-10-04 00:00:00.000Z', '2026-10-03'), 17);
  assert.equal(hulp.leeftijd('2016-10-03', '2026-10-03'), 10);
  assert.equal(hulp.leeftijd('2016-10-04', '2026-10-03'), 9);
  assert.equal(hulp.leeftijd('2008-02-29', '2026-02-28'), 17);
  assert.equal(hulp.leeftijd('2008-02-29', '2026-03-01'), 18);
});

test('leeftijd: leeg of onzin geeft null', () => {
  assert.equal(hulp.leeftijd('', '2026-10-03'), null);
  assert.equal(hulp.leeftijd(null, '2026-10-03'), null);
  assert.equal(hulp.leeftijd('gisteren', '2026-10-03'), null);
});

test('isTeJong: alleen een helper (rol jongere) onder de 10', () => {
  assert.equal(hulp.isTeJong('jongere', '2017-01-01', '2026-10-03'), true);
  assert.equal(hulp.isTeJong('jongere', '2016-10-03', '2026-10-03'), false);
  assert.equal(hulp.isTeJong('hulpvrager', '2020-01-01', '2026-10-03'), false);
  // Leeg = onbekend: daar beslist de klus-check (geen geboortedatum = geen klussen).
  assert.equal(hulp.isTeJong('jongere', '', '2026-10-03'), false);
});

test('isTeJong: een datum in de toekomst is ook te jong', () => {
  assert.equal(hulp.isTeJong('jongere', '2027-01-01', '2026-10-03'), true);
});

const basis = {
  geboortedatum: '2000-01-01',
  ouderToestemmingOp: '',
  vogGezienOp: '2026-09-01 10:00:00.000Z',
  vogGeldigTot: '',
  vandaag: '2026-10-03',
};

test('klusBlokkade: 18+ met VOG gezien mag', () => {
  assert.equal(hulp.klusBlokkade(basis), null);
});

test('klusBlokkade: 18+ zonder vog_gezien_op mag niet (reden vog)', () => {
  const b = hulp.klusBlokkade({ ...basis, vogGezienOp: '' });
  assert.equal(b.reden, 'vog');
  assert.match(b.melding, /VOG/);
});

test('klusBlokkade: onder 18 zonder toestemming mag niet (reden ouder)', () => {
  const b = hulp.klusBlokkade({ ...basis, geboortedatum: '2012-01-01', vogGezienOp: '' });
  assert.equal(b.reden, 'ouder');
  assert.match(b.melding, /ouder/);
});

test('klusBlokkade: onder 18 met toestemming mag, ook zonder VOG', () => {
  const b = hulp.klusBlokkade({
    ...basis,
    geboortedatum: '2012-01-01',
    vogGezienOp: '',
    ouderToestemmingOp: '2026-10-01 10:00:00.000Z',
  });
  assert.equal(b, null);
});

test('klusBlokkade: geen geboortedatum mag niet (reden geboortedatum)', () => {
  assert.equal(hulp.klusBlokkade({ ...basis, geboortedatum: '' }).reden, 'geboortedatum');
});

test('klusBlokkade: verlopen VOG (oude data, vog_geldig_tot) blijft geweigerd', () => {
  const b = hulp.klusBlokkade({ ...basis, vogGeldigTot: '2026-10-02 00:00:00.000Z' });
  assert.equal(b.reden, 'vogverlopen');
  // De dag zelf telt nog mee.
  assert.equal(hulp.klusBlokkade({ ...basis, vogGeldigTot: '2026-10-03' }), null);
});

test('postcodeCijfers: alleen een Nederlandse postcode', () => {
  assert.equal(hulp.postcodeCijfers('4003 AB'), '4003');
  assert.equal(hulp.postcodeCijfers('4003ab'), '4003');
  assert.equal(hulp.postcodeCijfers(' 4007  XZ '), '4007');
  assert.equal(hulp.postcodeCijfers('4003'), '4003');
  assert.equal(hulp.postcodeCijfers('0123 AB'), '');
  assert.equal(hulp.postcodeCijfers('AB 4003'), '');
  assert.equal(hulp.postcodeCijfers(''), '');
});

const wijken = [
  { id: 'west', postcodes: ['4003', '4004'], actief: true },
  { id: 'pass', postcodes: ['4007'], actief: true },
  { id: 'oud', postcodes: ['4008'], actief: false },
];

test('wijkVoorPostcode: de actieve wijk met deze cijfers, anders leeg', () => {
  assert.equal(hulp.wijkVoorPostcode('4004 KL', wijken), 'west');
  assert.equal(hulp.wijkVoorPostcode('4007AA', wijken), 'pass');
  assert.equal(hulp.wijkVoorPostcode('4008 AA', wijken), '');
  assert.equal(hulp.wijkVoorPostcode('1234 AB', wijken), '');
  assert.equal(hulp.wijkVoorPostcode('', wijken), '');
});

test('voornaam: alleen het eerste woord', () => {
  assert.equal(hulp.voornaam('Daan de Vries'), 'Daan');
  assert.equal(hulp.voornaam('  Sara  '), 'Sara');
  assert.equal(hulp.voornaam(''), '');
});

test('magAllesZien: alleen de helper zelf of de coordinator', () => {
  assert.equal(hulp.magAllesZien('a', 'jongere', 'a'), true);
  assert.equal(hulp.magAllesZien('c', 'coordinator', 'a'), true);
  assert.equal(hulp.magAllesZien('b', 'hulpvrager', 'a'), false);
  assert.equal(hulp.magAllesZien('', '', 'a'), false);
});

test('VERBORGEN: geboortedatum, adres en ouder-gegevens van een helper', () => {
  for (const v of ['geboortedatum', 'adres', 'huisnummer', 'postcode', 'plaats', 'telefoon', 'ouder_email', 'ouder_telefoon', 'ouder_toestemming_op', 'ouder_iban_ok', 'email']) {
    assert.ok(hulp.VERBORGEN_VOOR_ANDEREN.includes(v), v);
  }
  assert.ok(!hulp.VERBORGEN_VOOR_ANDEREN.includes('naam'));
});

function fakeRij(id, postcodes, actief = true) {
  return { id, get: () => JSON.stringify(postcodes), getBool: () => actief };
}

test('wijkUitDatabase: leest de wijken via $app en decodeert het json-veld', () => {
  let filter = '';
  const app = {
    findRecordsByFilter: (col, f) => {
      assert.equal(col, 'hh_wijken');
      filter = f;
      return [fakeRij('west', ['4003', '4004']), fakeRij('pass', ['4007'])];
    },
  };
  assert.equal(hulp.wijkUitDatabase(app, (x) => x, '4007 AB'), 'pass');
  assert.equal(filter, 'actief = true');
});

test('wijkUitDatabase: een fout bij lezen geeft geen wijk (aanmelden gaat door)', () => {
  const app = { findRecordsByFilter: () => { throw new Error('weg'); } };
  const log = console.log;
  console.log = () => {};
  try {
    assert.equal(hulp.wijkUitDatabase(app, (x) => x, '4003 AB'), '');
  } finally {
    console.log = log;
  }
});
