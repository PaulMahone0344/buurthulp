// HeitjeHulp ADRES — test van backend/pb_hooks/hh_adres_hulp.js zonder server
// en zonder echte PDOK (alles via een nep-http).
// Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const hier = path.dirname(fileURLToPath(import.meta.url));
function laad(naam) {
  const bron = readFileSync(path.join(hier, '..', 'pb_hooks', naam), 'utf8');
  const m = { exports: {} };
  new Function('module', 'exports', bron)(m, m.exports);
  return m.exports;
}
const hulp = laad('hh_adres_hulp.js');

// ------------------------------------------------------------ nep-PDOK
const doc = (o) => ({
  straatnaam: 'Kerkstraat',
  huisnummer: 1,
  postcode: '4001MA',
  woonplaatsnaam: 'Tiel',
  gemeentenaam: 'Tiel',
  centroide_ll: 'POINT(5.43597055 51.88761538)',
  ...o,
});
const KERKSTRAAT_1 = { statusCode: 200, json: { response: { numFound: 1, docs: [doc({})] } } };
const MEERDERE = {
  statusCode: 200,
  json: {
    response: {
      numFound: 4,
      docs: [
        doc({ straatnaam: 'Nieuwe Tielseweg', postcode: '4001JS', huisletter: 'a', huisnummertoevoeging: '02' }),
        doc({ straatnaam: 'Nieuwe Tielseweg', postcode: '4001JS', huisletter: 'a', huisnummertoevoeging: '01' }),
        doc({ straatnaam: 'Nieuwe Tielseweg', postcode: '4001JS', huisnummertoevoeging: '2' }),
        doc({ straatnaam: 'Nieuwe Tielseweg', postcode: '4001JS', huisletter: 'a' }),
      ],
    },
  },
};
const MET_KAAL = {
  statusCode: 200,
  json: {
    response: {
      numFound: 2,
      docs: [doc({ huisletter: 'A' }), doc({})],
    },
  },
};
const LEEG = { statusCode: 200, json: { response: { numFound: 0, docs: [] } } };

function nep(antwoord, { url = '' } = {}) {
  const verzoeken = [];
  const opslag = new Map();
  let klok = 1_000_000;
  const env = {
    url,
    http: (req) => {
      verzoeken.push(req);
      const a = typeof antwoord === 'function' ? antwoord(req) : antwoord;
      if (a instanceof Error) throw a;
      return a;
    },
    nu: () => klok,
    store: { get: (k) => opslag.get(k), set: (k, v) => opslag.set(k, v), remove: (k) => opslag.delete(k) },
    log: () => {},
    binnen: (punt) => Math.abs(punt.lat - 51.8865) < 0.2 && Math.abs(punt.lon - 5.43) < 0.3,
  };
  return { env, verzoeken, opslag, verzetKlok: (ms) => (klok += ms) };
}

// ------------------------------------------------------------ invoer
test('normaliseerPostcode: 4 cijfers (niet 0 vooraan) + 2 letters, als "4001 MA"', () => {
  assert.equal(hulp.normaliseerPostcode('4001ma'), '4001 MA');
  assert.equal(hulp.normaliseerPostcode(' 4001 MA '), '4001 MA');
  assert.equal(hulp.normaliseerPostcode('4001  ma'), '4001 MA');
  for (const fout of ['4001', '0401 MA', '401 MA', '40011 MA', '4001 M', '4001 M1', 'MA 4001', '', null, undefined]) {
    assert.equal(hulp.normaliseerPostcode(fout), null, String(fout));
  }
});

test('normaliseerHuisnummer: alleen cijfers, niet 0, voorloopnullen weg', () => {
  assert.equal(hulp.normaliseerHuisnummer('1'), '1');
  assert.equal(hulp.normaliseerHuisnummer(' 012 '), '12');
  assert.equal(hulp.normaliseerHuisnummer('99999'), '99999');
  for (const fout of ['', '0', '12a', 'a', '1-2', '123456', null]) {
    assert.equal(hulp.normaliseerHuisnummer(fout), null, String(fout));
  }
});

test('splitsHuisnummer: oude app stuurt "12a" of "12-2" in het huisnummer', () => {
  assert.deepEqual(hulp.splitsHuisnummer('12'), { huisnummer: '12', toevoeging: '' });
  assert.deepEqual(hulp.splitsHuisnummer('12a'), { huisnummer: '12', toevoeging: 'a' });
  assert.deepEqual(hulp.splitsHuisnummer('12 A'), { huisnummer: '12', toevoeging: 'A' });
  assert.deepEqual(hulp.splitsHuisnummer('12-2'), { huisnummer: '12', toevoeging: '2' });
  assert.deepEqual(hulp.splitsHuisnummer('1a-01'), { huisnummer: '1', toevoeging: 'a-01' });
  assert.equal(hulp.splitsHuisnummer('a12'), null);
  assert.equal(hulp.splitsHuisnummer(''), null);
});

test('normaliseerToevoeging: leeg mag, max 6 tekens letters/cijfers', () => {
  assert.equal(hulp.normaliseerToevoeging(''), '');
  assert.equal(hulp.normaliseerToevoeging(null), '');
  assert.equal(hulp.normaliseerToevoeging(' a '), 'a');
  assert.equal(hulp.normaliseerToevoeging('-2'), '2');
  assert.equal(hulp.normaliseerToevoeging('a-01'), 'a-01');
  assert.equal(hulp.normaliseerToevoeging('bis'), 'bis');
  assert.equal(hulp.normaliseerToevoeging('abcdefg'), null);
  assert.equal(hulp.normaliseerToevoeging('a/b'), null);
  assert.equal(hulp.normaliseerToevoeging('<b>'), null);
});

// ------------------------------------------------------------ PDOK lezen
test('pdokUrl: postcode zonder spatie, huisnummer, type adres, alleen de velden die we gebruiken', () => {
  const url = hulp.pdokUrl('', '4001 MA', '1');
  assert.ok(url.startsWith('https://api.pdok.nl/bzk/locatieserver/search/v3_1/free?'));
  assert.match(url, /q=postcode%3A4001MA%20and%20huisnummer%3A1/);
  assert.match(url, /fq=type%3Aadres/);
  assert.match(url, /rows=50/);
  assert.match(url, /fl=[^&]*centroide_ll/);
  assert.ok(hulp.pdokUrl('http://127.0.0.1:8192/free', '4001 MA', '1').startsWith('http://127.0.0.1:8192/free?'));
});

test('leesAdres: straat, nummer, toevoeging, postcode met spatie, punt (lon lat -> lat/lon)', () => {
  const a = hulp.leesAdres(doc({}));
  assert.deepEqual(a, {
    straat: 'Kerkstraat',
    huisnummer: '1',
    toevoeging: '',
    postcode: '4001 MA',
    plaats: 'Tiel',
    gemeente: 'Tiel',
    lat: 51.88761538,
    lon: 5.43597055,
    adres: 'Kerkstraat 1',
    weergave: 'Kerkstraat 1, 4001 MA Tiel',
  });
  assert.equal(hulp.leesAdres(doc({ huisletter: 'a', huisnummertoevoeging: '01' })).adres, 'Kerkstraat 1a-01');
  assert.equal(hulp.leesAdres(doc({ huisletter: 'a', huisnummertoevoeging: '01' })).toevoeging, 'a-01');
  assert.equal(hulp.leesAdres(doc({ huisnummertoevoeging: '2' })).adres, 'Kerkstraat 1-2');
  assert.equal(hulp.leesAdres(doc({ huisnummertoevoeging: '2' })).toevoeging, '2');
  assert.equal(hulp.leesAdres(doc({ huisletter: 'B' })).adres, 'Kerkstraat 1B');
});

test('leesAdres: zonder punt of straat geen adres', () => {
  assert.equal(hulp.leesAdres(doc({ centroide_ll: '' })), null);
  assert.equal(hulp.leesAdres(doc({ centroide_ll: 'POINT(x y)' })), null);
  assert.equal(hulp.leesAdres(doc({ straatnaam: '' })), null);
  assert.equal(hulp.leesAdres(null), null);
});

// ------------------------------------------------------------ zoeken
test('zoekAdres: één adres, met binnen_werkgebied', () => {
  const n = nep(KERKSTRAAT_1);
  const uit = hulp.zoekAdres(n.env, { postcode: '4001ma', huisnummer: '1' });
  assert.equal(uit.status, 200);
  assert.equal(uit.body.gevonden, true);
  assert.equal(uit.body.adressen.length, 1);
  assert.equal(uit.body.adressen[0].postcode, '4001 MA');
  assert.equal(uit.body.adressen[0].binnen_werkgebied, true);
  assert.equal(n.verzoeken.length, 1);
  assert.equal(n.verzoeken[0].timeout, 5);
  assert.equal(n.verzoeken[0].method, 'GET');
});

test('zoekAdres: meerdere toevoegingen -> keuzelijst, gesorteerd (zonder toevoeging eerst)', () => {
  const uit = hulp.zoekAdres(nep(MEERDERE).env, { postcode: '4001 JS', huisnummer: '1' });
  assert.equal(uit.body.gevonden, true);
  assert.deepEqual(uit.body.adressen.map((a) => a.adres), [
    'Nieuwe Tielseweg 1-2',
    'Nieuwe Tielseweg 1a',
    'Nieuwe Tielseweg 1a-01',
    'Nieuwe Tielseweg 1a-02',
  ]);
});

test('zoekAdres: met toevoeging alleen dat adres (hoofdletters, streepjes en spaties tellen niet)', () => {
  for (const t of ['A-01', 'a01', 'a 01']) {
    const uit = hulp.zoekAdres(nep(MEERDERE).env, { postcode: '4001JS', huisnummer: '1', toevoeging: t });
    assert.equal(uit.body.gevonden, true, t);
    assert.deepEqual(uit.body.adressen.map((a) => a.adres), ['Nieuwe Tielseweg 1a-01'], t);
  }
});

test('zoekAdres: onbekende toevoeging -> niet gevonden, met de keuzes erbij', () => {
  const uit = hulp.zoekAdres(nep(MEERDERE).env, { postcode: '4001JS', huisnummer: '1', toevoeging: 'z' });
  assert.equal(uit.status, 200);
  assert.equal(uit.body.gevonden, false);
  assert.equal(uit.body.reden, 'toevoeging');
  assert.equal(uit.body.adressen.length, 4);
});

test('zoekAdres: niets gevonden -> rustige melding', () => {
  const uit = hulp.zoekAdres(nep(LEEG).env, { postcode: '4001 MA', huisnummer: '999' });
  assert.equal(uit.status, 200);
  assert.deepEqual(
    { gevonden: uit.body.gevonden, reden: uit.body.reden },
    { gevonden: false, reden: 'nietgevonden' },
  );
  assert.equal(uit.body.melding, 'We vinden dit adres niet. Klopt de postcode en het huisnummer?');
});

test('zoekAdres: ongeldige invoer vraagt PDOK niets (400 met reden)', () => {
  const n = nep(KERKSTRAAT_1);
  assert.equal(hulp.zoekAdres(n.env, { postcode: '4001', huisnummer: '1' }).body.reden, 'postcode');
  assert.equal(hulp.zoekAdres(n.env, { postcode: '0401 MA', huisnummer: '1' }).body.reden, 'postcode');
  assert.equal(hulp.zoekAdres(n.env, { postcode: '4001 MA', huisnummer: '' }).body.reden, 'huisnummer');
  assert.equal(hulp.zoekAdres(n.env, { postcode: '4001 MA', huisnummer: '1a' }).body.reden, 'huisnummer');
  const t = hulp.zoekAdres(n.env, { postcode: '4001 MA', huisnummer: '1', toevoeging: 'abcdefgh' });
  assert.equal(t.status, 400);
  assert.equal(t.body.reden, 'toevoeging');
  assert.equal(n.verzoeken.length, 0);
});

test('zoekAdres: PDOK onbereikbaar of rare respons -> reden dienst (niet gecachet)', () => {
  for (const antwoord of [
    new Error('time-out'),
    { statusCode: 503, json: null },
    { statusCode: 200, json: null, raw: 'geen json' },
    { statusCode: 200, json: { iets: 'anders' } },
  ]) {
    const n = nep(antwoord);
    const uit = hulp.zoekAdres(n.env, { postcode: '4001 MA', huisnummer: '1' });
    assert.equal(uit.status, 200);
    assert.equal(uit.body.gevonden, false);
    assert.equal(uit.body.reden, 'dienst');
    hulp.zoekAdres(n.env, { postcode: '4001 MA', huisnummer: '1' });
    assert.equal(n.verzoeken.length, 2, 'een storing wordt niet onthouden');
  }
});

test('zoekAdres: leest ook raw als json leeg is', () => {
  const uit = hulp.zoekAdres(nep({ statusCode: 200, json: null, raw: JSON.stringify(KERKSTRAAT_1.json) }).env, {
    postcode: '4001 MA',
    huisnummer: '1',
  });
  assert.equal(uit.body.gevonden, true);
});

test('cache: dezelfde postcode + huisnummer binnen 10 minuten = geen tweede verzoek', () => {
  const n = nep(KERKSTRAAT_1);
  hulp.zoekAdres(n.env, { postcode: '4001 MA', huisnummer: '1' });
  n.verzetKlok(9 * 60 * 1000);
  hulp.zoekAdres(n.env, { postcode: '4001ma', huisnummer: '01', toevoeging: '' });
  assert.equal(n.verzoeken.length, 1);
  n.verzetKlok(2 * 60 * 1000);
  hulp.zoekAdres(n.env, { postcode: '4001 MA', huisnummer: '1' });
  assert.equal(n.verzoeken.length, 2);
});

test('cache: ook "niet gevonden" wordt onthouden', () => {
  const n = nep(LEEG);
  hulp.zoekAdres(n.env, { postcode: '4001 MA', huisnummer: '999' });
  hulp.zoekAdres(n.env, { postcode: '4001 MA', huisnummer: '999' });
  assert.equal(n.verzoeken.length, 1);
});

// ------------------------------------------------------------ rate-limit
test('magZoeken: per IP per uur, daarna geweigerd; volgend uur weer', () => {
  const n = nep(KERKSTRAAT_1);
  for (let i = 0; i < 3; i++) assert.equal(hulp.magZoeken(n.env, '1.2.3.4', 3), true);
  assert.equal(hulp.magZoeken(n.env, '1.2.3.4', 3), false);
  assert.equal(hulp.magZoeken(n.env, '5.6.7.8', 3), true, 'ander IP telt apart');
  n.verzetKlok(3600 * 1000);
  assert.equal(hulp.magZoeken(n.env, '1.2.3.4', 3), true);
});

test('limietVoor: anoniem 60, ingelogd 120, coordinator en superuser geen grens', () => {
  assert.equal(hulp.limietVoor('anoniem'), 60);
  assert.equal(hulp.limietVoor('gebruiker'), 120);
  assert.equal(hulp.limietVoor('coordinator'), 0);
  assert.equal(hulp.limietVoor('superuser'), 0);
});

// ------------------------------------------------------------ beoordelen (hh_users-hook)
const basis = { wie: 'anoniem', rol: 'hulpvrager', nieuw: true, aangeraakt: true, servervelden: false, adresBron: '' };

test('beoordeel: nieuw account met bestaand adres -> pdok, straat en plaats van PDOK', () => {
  const uit = hulp.beoordeel(nep(KERKSTRAAT_1).env, { ...basis, postcode: '4001ma', huisnummer: '1', toevoeging: '' });
  assert.equal(uit.actie, 'pdok');
  assert.equal(uit.adres.adres, 'Kerkstraat 1');
  assert.equal(uit.adres.plaats, 'Tiel');
  assert.equal(uit.adres.postcode, '4001 MA');
});

test('beoordeel: bewoner en helper moeten een postcode + huisnummer hebben', () => {
  for (const rol of ['hulpvrager', 'jongere']) {
    for (const [pc, nr, reden] of [
      ['', '', 'verplicht'],
      ['4001', '1', 'postcode'],
      ['4001 MA', '', 'huisnummer'],
      ['4001 MA', 'x', 'huisnummer'],
    ]) {
      const n = nep(KERKSTRAAT_1);
      const uit = hulp.beoordeel(n.env, { ...basis, rol, postcode: pc, huisnummer: nr, toevoeging: '' });
      assert.equal(uit.actie, 'weiger', `${rol} ${pc}/${nr}`);
      assert.equal(uit.reden, reden, `${rol} ${pc}/${nr}`);
      assert.equal(n.verzoeken.length, 0);
    }
  }
});

test('beoordeel: oude app stuurt "12a" als huisnummer -> 12 + toevoeging a', () => {
  const n = nep(MET_KAAL);
  const uit = hulp.beoordeel(n.env, { ...basis, rol: 'jongere', postcode: '4001 MA', huisnummer: '1a', toevoeging: '' });
  assert.equal(uit.actie, 'pdok');
  assert.equal(uit.adres.toevoeging, 'A');
  assert.match(n.verzoeken[0].url, /huisnummer%3A1(&|$)/);
});

test('beoordeel: adres bestaat niet -> weiger nietgevonden', () => {
  const uit = hulp.beoordeel(nep(LEEG).env, { ...basis, postcode: '9999 ZZ', huisnummer: '1', toevoeging: '' });
  assert.equal(uit.actie, 'weiger');
  assert.equal(uit.reden, 'nietgevonden');
});

test('beoordeel: meerdere adressen en geen toevoeging -> kale nummer als dat bestaat, anders kiezen', () => {
  const kaal = hulp.beoordeel(nep(MET_KAAL).env, { ...basis, postcode: '4001 MA', huisnummer: '1', toevoeging: '' });
  assert.equal(kaal.actie, 'pdok');
  assert.equal(kaal.adres.toevoeging, '');
  const kies = hulp.beoordeel(nep(MEERDERE).env, { ...basis, postcode: '4001 JS', huisnummer: '1', toevoeging: '' });
  assert.equal(kies.actie, 'weiger');
  assert.equal(kies.reden, 'kiestoevoeging');
  const fout = hulp.beoordeel(nep(MEERDERE).env, { ...basis, postcode: '4001 JS', huisnummer: '1', toevoeging: 'q' });
  assert.equal(fout.actie, 'weiger');
  assert.equal(fout.reden, 'toevoeging');
});

test('beoordeel: PDOK onbereikbaar -> terugval (aanmelden gaat door, ongecontroleerd)', () => {
  const uit = hulp.beoordeel(nep(new Error('weg')).env, { ...basis, postcode: '4001ma', huisnummer: '1', toevoeging: 'b' });
  assert.equal(uit.actie, 'terugval');
  assert.deepEqual(
    { postcode: uit.postcode, huisnummer: uit.huisnummer, toevoeging: uit.toevoeging },
    { postcode: '4001 MA', huisnummer: '1', toevoeging: 'b' },
  );
});

test('beoordeel: servervelden (lat, lon, adres_bron) zelf meesturen mag alleen coordinator/superuser', () => {
  for (const wie of ['anoniem', 'gebruiker']) {
    const uit = hulp.beoordeel(nep(KERKSTRAAT_1).env, { ...basis, wie, servervelden: true, postcode: '4001 MA', huisnummer: '1' });
    assert.equal(uit.actie, 'weiger', wie);
    assert.equal(uit.reden, 'servervelden', wie);
  }
  const coord = hulp.beoordeel(nep(KERKSTRAAT_1).env, { ...basis, wie: 'coordinator', servervelden: true, postcode: '4001 MA', huisnummer: '1' });
  assert.equal(coord.actie, 'pdok');
});

test('beoordeel: coordinator met adres_bron handmatig slaat PDOK over (uitzondering)', () => {
  const n = nep(KERKSTRAAT_1);
  const uit = hulp.beoordeel(n.env, { ...basis, wie: 'coordinator', adresBron: 'handmatig', postcode: '', huisnummer: '' });
  assert.equal(uit.actie, 'handmatig');
  assert.equal(n.verzoeken.length, 0);
  const su = hulp.beoordeel(n.env, { ...basis, wie: 'superuser', adresBron: 'handmatig', postcode: '4001 MA', huisnummer: '1' });
  assert.equal(su.actie, 'handmatig');
});

test('beoordeel: coordinator zonder handmatig is net zo streng', () => {
  const uit = hulp.beoordeel(nep(KERKSTRAAT_1).env, { ...basis, wie: 'coordinator', postcode: '', huisnummer: '' });
  assert.equal(uit.actie, 'weiger');
});

test('beoordeel: bijwerken zonder adreswijziging doet niets (bestaande accounts blijven werken)', () => {
  const n = nep(KERKSTRAAT_1);
  const uit = hulp.beoordeel(n.env, { ...basis, wie: 'gebruiker', nieuw: false, aangeraakt: false, postcode: '4001', huisnummer: '' });
  assert.equal(uit.actie, 'niets');
  assert.equal(n.verzoeken.length, 0);
});

test('beoordeel: bijwerken met een ander adres -> weer streng', () => {
  const uit = hulp.beoordeel(nep(KERKSTRAAT_1).env, { ...basis, wie: 'gebruiker', nieuw: false, aangeraakt: true, postcode: '4001', huisnummer: '1' });
  assert.equal(uit.actie, 'weiger');
  assert.equal(uit.reden, 'postcode');
});

test('beoordeel: familie en coordinator-accounts hoeven geen adres', () => {
  for (const rol of ['familie', 'coordinator']) {
    const uit = hulp.beoordeel(nep(KERKSTRAAT_1).env, { ...basis, wie: 'coordinator', rol, postcode: '', huisnummer: '' });
    assert.equal(uit.actie, 'niets', rol);
  }
});

test('beoordeel: superuser (seed, scripts) is niet streng: alleen postcode -> oude weg (Nominatim)', () => {
  const n = nep(LEEG);
  assert.equal(hulp.beoordeel(n.env, { ...basis, wie: 'superuser', postcode: '', huisnummer: '' }).actie, 'niets');
  assert.equal(hulp.beoordeel(n.env, { ...basis, wie: 'superuser', postcode: '4003 AB', huisnummer: '' }).actie, 'oud');
  assert.equal(hulp.beoordeel(n.env, { ...basis, wie: 'superuser', postcode: '9999 ZZ', huisnummer: '1' }).actie, 'oud');
  assert.equal(hulp.beoordeel(nep(KERKSTRAAT_1).env, { ...basis, wie: 'superuser', postcode: '4001 MA', huisnummer: '1' }).actie, 'pdok');
});

// ------------------------------------------------------------ klus-punt
test('puntVoorKlus: klus op het (PDOK-)adres van de bewoner -> zijn punt, geen verzoek nodig', () => {
  const bewoner = { adres: 'Kerkstraat 1', postcode: '4001 MA', plaats: 'Tiel', lat: 51.8876, lon: 5.4359, adres_bron: 'pdok' };
  assert.deepEqual(hulp.puntVoorKlus('Kerkstraat 1, 4001 MA Tiel', bewoner), { lat: 51.8876, lon: 5.4359 });
  assert.deepEqual(hulp.puntVoorKlus('  kerkstraat 1,4001MA  tiel', bewoner), { lat: 51.8876, lon: 5.4359 });
  assert.deepEqual(hulp.puntVoorKlus('Kerkstraat 1', bewoner), { lat: 51.8876, lon: 5.4359 });
  assert.deepEqual(hulp.puntVoorKlus('Kerkstraat 1, Tiel', bewoner), { lat: 51.8876, lon: 5.4359 });
});

test('puntVoorKlus: ander adres, geen PDOK-bron of geen punt -> null (dan Nominatim)', () => {
  const bewoner = { adres: 'Kerkstraat 1', postcode: '4001 MA', plaats: 'Tiel', lat: 51.8876, lon: 5.4359, adres_bron: 'pdok' };
  assert.equal(hulp.puntVoorKlus('Kerkstraat 3, 4001 MA Tiel', bewoner), null);
  assert.equal(hulp.puntVoorKlus('Kerkstraat 1, 4001 MA Tiel', { ...bewoner, adres_bron: 'handmatig' }), null);
  assert.equal(hulp.puntVoorKlus('Kerkstraat 1, 4001 MA Tiel', { ...bewoner, lat: 0, lon: 0 }), null);
  assert.equal(hulp.puntVoorKlus('', bewoner), null);
  assert.equal(hulp.puntVoorKlus('Kerkstraat 1', null), null);
});

test('zoekAdres: natuurlijke volgorde (2 voor 10, letters op volgorde)', () => {
  const docs = ['10', '2', 'b', '1'].map((t) => doc({ huisnummertoevoeging: t }));
  const uit = hulp.zoekAdres(nep({ statusCode: 200, json: { response: { docs } } }).env, { postcode: '4001 MA', huisnummer: '1' });
  assert.deepEqual(uit.body.adressen.map((a) => a.toevoeging), ['1', '2', '10', 'b']);
});

// ------------------------------------------------------------ hook-hulpjes
function nepRecord(velden = {}) {
  const v = { ...velden };
  return { get: (k) => v[k], set: (k, w) => { v[k] = w; }, velden: v };
}
const nepAuth = (collectie, rol) => ({ collection: () => ({ name: collectie }), get: (k) => (k === 'rol' ? rol : '') });

test('wieIs: anoniem, gebruiker, coordinator, superuser', () => {
  assert.equal(hulp.wieIs(null), 'anoniem');
  assert.equal(hulp.wieIs(nepAuth('_superusers')), 'superuser');
  assert.equal(hulp.wieIs(nepAuth('hh_users', 'coordinator')), 'coordinator');
  assert.equal(hulp.wieIs(nepAuth('hh_users', 'jongere')), 'gebruiker');
  assert.equal(hulp.wieIs(nepAuth('andere_app_users', 'coordinator')), 'gebruiker');
});

test('zetPdokAdres: straat, nummer, toevoeging, postcode, plaats, punt en bron van PDOK', () => {
  const r = nepRecord({ adres: 'Verzonnen 99', plaats: 'Nergens', postcode: '4001ma', huisnummer: '1a' });
  const adres = hulp.leesAdres(doc({ huisletter: 'A' }));
  hulp.zetPdokAdres(r, adres);
  assert.deepEqual(r.velden, {
    adres: 'Kerkstraat 1A',
    plaats: 'Tiel',
    postcode: '4001 MA',
    huisnummer: '1',
    toevoeging: 'A',
    lat: 51.88761538,
    lon: 5.43597055,
    adres_bron: 'pdok',
  });
});

test('zetOngecontroleerd: nette postcode/nummer/toevoeging, geen punt, bron ongecontroleerd', () => {
  const r = nepRecord({ adres: 'Kerkstraat 1', lat: 5, lon: 5 });
  hulp.zetOngecontroleerd(r, { postcode: '4001 MA', huisnummer: '1', toevoeging: '' });
  assert.deepEqual(r.velden, { adres: 'Kerkstraat 1', postcode: '4001 MA', huisnummer: '1', toevoeging: '', lat: 0, lon: 0, adres_bron: 'ongecontroleerd' });
});

test('isAdresAangeraakt: alleen als een adresveld echt anders is', () => {
  const oud = nepRecord({ adres: 'Kerkstraat 1', postcode: '4001 MA', huisnummer: '1', toevoeging: '', plaats: 'Tiel' });
  assert.equal(hulp.isAdresAangeraakt(nepRecord({ ...oud.velden, naam: 'x' }), oud), false);
  assert.equal(hulp.isAdresAangeraakt(nepRecord({ ...oud.velden, toevoeging: 'a' }), oud), true);
  assert.equal(hulp.isAdresAangeraakt(nepRecord({ ...oud.velden, plaats: 'Ochten' }), oud), true);
  assert.equal(hulp.isAdresAangeraakt(nepRecord({ ...oud.velden, toevoeging: undefined }), oud), false, 'leeg = leeg');
});

test('serverveldenGestuurd: lat, lon of adres_bron in de body', () => {
  assert.equal(hulp.serverveldenGestuurd({ naam: 'x' }), false);
  assert.equal(hulp.serverveldenGestuurd({ lat: 0 }), true);
  assert.equal(hulp.serverveldenGestuurd({ adres_bron: '' }), true);
  assert.equal(hulp.serverveldenGestuurd(null), false);
});

// ------------------------------------------------------------ vaag vóór de match (antwoord Ibrahim 3)
const aanmelden = laad('hh_aanmelden_hulp.js');
const km = (a, b) => aanmelden.afstandKm(a, b);

test('vaagPunt: ~200 m van het echte punt, stabiel per klus-id', () => {
  const echt = { lat: 51.88761538, lon: 5.43597055 };
  const a = hulp.vaagPunt('k1abcdefghijklm', echt);
  const b = hulp.vaagPunt('k1abcdefghijklm', echt);
  assert.deepEqual(a, b, 'zelfde klus = zelfde punt (niet bij elk verversen anders)');
  const d = km(echt, a);
  assert.ok(d > 0.17 && d < 0.23, `afstand ${d}`);
});

test('vaagPunt: andere klus = andere richting; met zout ook anders', () => {
  const echt = { lat: 51.88, lon: 5.43 };
  const punten = ['a1', 'b2', 'c3', 'd4', 'e5'].map((id) => hulp.vaagPunt(id, echt));
  assert.ok(new Set(punten.map((p) => `${p.lat},${p.lon}`)).size >= 4);
  assert.notDeepEqual(hulp.vaagPunt('a1', echt, 'geheim'), hulp.vaagPunt('a1', echt, ''));
});

test('vaagPunt: geen punt (0/0 of leeg) blijft geen punt', () => {
  assert.equal(hulp.vaagPunt('x', { lat: 0, lon: 0 }), null);
  assert.equal(hulp.vaagPunt('x', null), null);
});

test('afstandAfgerond: meters op 100 afgerond, minstens 100; zonder punt null', () => {
  const a = { lat: 51.88, lon: 5.43 };
  assert.equal(hulp.afstandAfgerond(a, { lat: 51.88, lon: 5.43 }), 100);
  assert.equal(hulp.afstandAfgerond(a, { lat: 51.8827, lon: 5.43 }), 300);
  assert.equal(hulp.afstandAfgerond(a, { lat: 51.9, lon: 5.43 }), 2200);
  assert.equal(hulp.afstandAfgerond(null, a), null);
  assert.equal(hulp.afstandAfgerond({ lat: 0, lon: 0 }, a), null);
});

test('isVoorDeMatch: alleen een helper die niet de toegewezen helper is', () => {
  assert.equal(hulp.isVoorDeMatch({ id: 'h1', collectie: 'hh_users', rol: 'jongere' }, ''), true);
  assert.equal(hulp.isVoorDeMatch({ id: 'h1', collectie: 'hh_users', rol: 'jongere' }, 'h2'), true);
  assert.equal(hulp.isVoorDeMatch({ id: 'h1', collectie: 'hh_users', rol: 'jongere' }, 'h1'), false);
  assert.equal(hulp.isVoorDeMatch({ id: 'b1', collectie: 'hh_users', rol: 'hulpvrager' }, ''), false);
  assert.equal(hulp.isVoorDeMatch({ id: 'c1', collectie: 'hh_users', rol: 'coordinator' }, ''), false);
  assert.equal(hulp.isVoorDeMatch({ id: 's', collectie: '_superusers', rol: '' }, ''), false);
  assert.equal(hulp.isVoorDeMatch(null, ''), false);
});

test('zoektOpLocatie: filter of sort op lat, lon, adres of postcode is voor een helper dicht', () => {
  for (const f of ['lat > 51.8', 'lon<5', 'adres ~ "Kerk"', 'hulpvrager.postcode = "4001 MA"', 'klus.lat>1', '(lat)', 'hulpvrager.huisnummer="1"']) {
    assert.equal(hulp.zoektOpLocatie(f, ''), true, f);
  }
  assert.equal(hulp.zoektOpLocatie('', '-lat'), true);
  for (const f of ['status = "open"', 'klustype.naam = "Tuin"', 'wanneer_van > "2026"', 'plaatsen = 1', 'adres_bron = "pdok"', 'latje = 1']) {
    assert.equal(hulp.zoektOpLocatie(f, '-created'), false, f);
  }
});
