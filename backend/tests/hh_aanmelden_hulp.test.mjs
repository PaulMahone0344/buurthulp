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

// ---------------------------------------------------------------- werkgebied

test('afstandKm: Tiel-centrum tot Ochten is ongeveer 9,5 km', () => {
  const tiel = hulp.WERKGEBIEDEN[0];
  const d = hulp.afstandKm({ lat: tiel.lat, lon: tiel.lon }, { lat: 51.9082582, lon: 5.5643061 });
  assert.ok(d > 8.5 && d < 10.5, String(d));
  assert.equal(hulp.afstandKm({ lat: 1, lon: 1 }, { lat: 1, lon: 1 }), 0);
});

test('werkgebiedVoorPunt: binnen 20 km van Tiel wel, Amsterdam niet', () => {
  assert.equal(hulp.werkgebiedVoorPunt({ lat: 51.8975573, lon: 5.4283281 }).wijk, 'Tiel en omstreken');
  assert.equal(hulp.werkgebiedVoorPunt({ lat: 51.9082582, lon: 5.5643061 }).wijk, 'Tiel en omstreken'); // Ochten
  assert.equal(hulp.werkgebiedVoorPunt({ lat: 52.3787832, lon: 4.9 }), null); // Amsterdam
  // Net over de rand: ~25 km oost.
  assert.equal(hulp.werkgebiedVoorPunt({ lat: 51.8861, lon: 5.79 }), null);
});

test('WERKGEBIEDEN: middelpunt Tiel, straal 20 km, een tweede stad kan erbij', () => {
  assert.ok(Array.isArray(hulp.WERKGEBIEDEN));
  const [tiel] = hulp.WERKGEBIEDEN;
  assert.equal(tiel.straalKm, 20);
  assert.equal(tiel.gemeente, 'Tiel');
});

test('nominatimUrl: gestructureerd op postcode, alleen NL', () => {
  const url = hulp.nominatimUrl('https://n.test/search', '4003 AB');
  assert.equal(url, 'https://n.test/search?format=json&limit=1&countrycodes=nl&postalcode=4003%20AB');
});

/// Nep-omgeving: geen echte Nominatim-verzoeken in tests.
function nepOmgeving(antwoord, { start = 10_000 } = {}) {
  const verzoeken = [];
  const slaap = [];
  const winkel = new Map();
  let klok = start;
  return {
    verzoeken,
    slaap,
    env: {
      url: 'https://n.test/search',
      http: (req) => {
        verzoeken.push(req);
        if (antwoord instanceof Error) throw antwoord;
        return antwoord;
      },
      nu: () => klok,
      sleep: (ms) => {
        slaap.push(ms);
        klok += ms;
      },
      store: { get: (k) => winkel.get(k), set: (k, v) => winkel.set(k, v) },
      log: () => {},
    },
    verzetKlok: (ms) => {
      klok += ms;
    },
  };
}

const OK_TIEL = { statusCode: 200, json: [{ lat: '51.8975573', lon: '5.4283281' }] };
const OK_AMS = { statusCode: 200, json: [{ lat: '52.3787832', lon: '4.9' }] };

test('bepaalWerkgebied: binnen de straal', () => {
  const n = nepOmgeving(OK_TIEL);
  const uit = hulp.bepaalWerkgebied(n.env, '4003ab');
  assert.equal(uit.status, 'binnen');
  assert.equal(uit.werkgebied.wijk, 'Tiel en omstreken');
  assert.equal(n.verzoeken.length, 1);
  assert.match(n.verzoeken[0].url, /postalcode=4003%20AB/);
  assert.equal(n.verzoeken[0].headers['User-Agent'], 'HeitjeHulp/0.1 (info@heitjehulp.nl)');
  assert.equal(n.verzoeken[0].timeout, 5);
});

test('bepaalWerkgebied: buiten de straal', () => {
  const uit = hulp.bepaalWerkgebied(nepOmgeving(OK_AMS).env, '1012 AB');
  assert.equal(uit.status, 'buiten');
  assert.equal(uit.werkgebied, null);
});

test('bepaalWerkgebied: geen resultaat, fout van de server of geen internet = onbekend', () => {
  for (const antwoord of [
    { statusCode: 200, json: [] },
    { statusCode: 500, json: null },
    { statusCode: 200, json: [{ lat: 'x', lon: 'y' }] },
    { statusCode: 200, json: null, raw: 'geen json' },
    new Error('geen verbinding'),
  ]) {
    assert.equal(hulp.bepaalWerkgebied(nepOmgeving(antwoord).env, '4003 AB').status, 'onbekend');
  }
});

test('bepaalWerkgebied: leest ook raw als json leeg is', () => {
  const uit = hulp.bepaalWerkgebied(
    nepOmgeving({ statusCode: 200, json: null, raw: JSON.stringify(OK_TIEL.json) }).env,
    '4003 AB',
  );
  assert.equal(uit.status, 'binnen');
});

test('bepaalWerkgebied: een ongeldige postcode vraagt niets en is onbekend', () => {
  const n = nepOmgeving(OK_TIEL);
  assert.equal(hulp.bepaalWerkgebied(n.env, 'abc').status, 'onbekend');
  assert.equal(n.verzoeken.length, 0);
});

test('bepaalWerkgebied: hooguit 1 verzoek per seconde (Nominatim-regel)', () => {
  const n = nepOmgeving(OK_TIEL);
  hulp.bepaalWerkgebied(n.env, '4003 AB');
  n.verzetKlok(300);
  hulp.bepaalWerkgebied(n.env, '4003 AB');
  assert.deepEqual(n.slaap, [700]);
  n.verzetKlok(5000);
  hulp.bepaalWerkgebied(n.env, '4003 AB');
  assert.deepEqual(n.slaap, [700]);
  assert.equal(n.verzoeken.length, 3);
});

test('wijkIdVoor: zoekt de actieve wijk van het werkgebied, anders leeg', () => {
  const gebied = hulp.WERKGEBIEDEN[0];
  let filter = '';
  let params = null;
  const app = {
    findRecordsByFilter: (col, f, _s, _l, _o, p) => {
      assert.equal(col, 'hh_wijken');
      filter = f;
      params = p;
      return [{ id: 'w-omstreken' }];
    },
  };
  assert.equal(hulp.wijkIdVoor(app, gebied), 'w-omstreken');
  assert.match(filter, /actief = true/);
  assert.deepEqual(params, { gemeente: 'Tiel', wijk: 'Tiel en omstreken' });
  assert.equal(hulp.wijkIdVoor({ findRecordsByFilter: () => [] }, gebied), '');
  const log = console.log;
  console.log = () => {};
  try {
    assert.equal(hulp.wijkIdVoor({ findRecordsByFilter: () => { throw new Error('x'); } }, gebied), '');
  } finally {
    console.log = log;
  }
});

test('wijkenPassen: zelfde wijk, of een regio-wijk in dezelfde gemeente', () => {
  const west = { id: 'west', gemeente: 'Tiel', regio: false };
  const pass = { id: 'pass', gemeente: 'Tiel', regio: false };
  const regio = { id: 'reg', gemeente: 'Tiel', regio: true };
  const ander = { id: 'ede', gemeente: 'Ede', regio: true };
  assert.equal(hulp.wijkenPassen(west, west), true);
  assert.equal(hulp.wijkenPassen(west, pass), false); // oud gedrag blijft
  assert.equal(hulp.wijkenPassen(regio, west), true);
  assert.equal(hulp.wijkenPassen(pass, regio), true);
  assert.equal(hulp.wijkenPassen(regio, ander), false);
  assert.equal(hulp.wijkenPassen(null, west), false);
  assert.equal(hulp.wijkenPassen(west, null), false);
});

// ADRES (4 okt): het werkgebied uit het exacte PDOK-punt, zonder verzoek.
test('werkgebiedUitPunt: binnen of buiten de straal, geen punt = onbekend', () => {
  const tiel = hulp.werkgebiedUitPunt({ lat: 51.88761538, lon: 5.43597055 });
  assert.equal(tiel.status, 'binnen');
  assert.equal(tiel.werkgebied.wijk, 'Tiel en omstreken');
  assert.deepEqual(hulp.werkgebiedUitPunt({ lat: 52.3731, lon: 4.8926 }), { status: 'buiten', werkgebied: null });
  assert.deepEqual(hulp.werkgebiedUitPunt(null), { status: 'onbekend', werkgebied: null });
  assert.deepEqual(hulp.werkgebiedUitPunt({ lat: NaN, lon: 5 }), { status: 'onbekend', werkgebied: null });
});

test('VERBORGEN_VOOR_ANDEREN: ook het punt, de toevoeging en de adresbron van een helper', () => {
  for (const veld of ['lat', 'lon', 'toevoeging', 'adres_bron']) {
    assert.ok(hulp.VERBORGEN_VOOR_ANDEREN.includes(veld), veld);
  }
});
