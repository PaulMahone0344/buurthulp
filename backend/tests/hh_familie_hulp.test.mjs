// HeitjeHulp M9 — test van backend/pb_hooks/hh_familie_hulp.js zonder
// server. Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs
//
// Het hulpbestand is CommonJS (zoals de JSVM het laadt); backend/package.json
// staat op ESM, dus we laden het met een eigen module-wikkel.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const hier = path.dirname(fileURLToPath(import.meta.url));
const bron = readFileSync(path.join(hier, '..', 'pb_hooks', 'hh_familie_hulp.js'), 'utf8');
const module_ = { exports: {} };
new Function('module', 'exports', bron)(module_, module_.exports);
const hulp = module_.exports;

test('e-mail: bijsnijden, kleine letters, eenvoudige vorm', () => {
  assert.equal(hulp.normaliseerEmail('  Oma@Voorbeeld.NL '), 'oma@voorbeeld.nl');
  assert.equal(hulp.isGeldigEmail('oma@voorbeeld.nl'), true);
  for (const fout of ['', 'oma', 'oma@', '@voorbeeld.nl', 'oma voorbeeld@nl', 'oma@voorbeeld']) {
    assert.equal(hulp.isGeldigEmail(fout), false, fout);
  }
});

test('dag in UTC', () => {
  assert.equal(hulp.dagSleutel(Date.UTC(2026, 8, 27, 23, 59)), '2026-09-27');
  assert.equal(hulp.dagSleutel(Date.UTC(2026, 8, 28, 0, 0)), '2026-09-28');
  assert.equal(hulp.dagBeginIso(Date.UTC(2026, 8, 27, 15, 3)), '2026-09-27 00:00:00.000Z');
});

// ---- een nep-server --------------------------------------------------------

function nepServer({ koppelingen = [] } = {}) {
  const rec = (velden) => ({
    id: velden.id,
    velden: { ...velden },
    get(k) { return this.velden[k]; },
    set(k, v) { this.velden[k] = v; },
  });
  const db = {
    hh_users: [
      rec({ id: 'o1', rol: 'hulpvrager', email: 'oma@voorbeeld.nl' }),
      rec({ id: 'j1', rol: 'jongere', email: 'jong@voorbeeld.nl' }),
      rec({ id: 'f1', rol: 'familie', email: 'dochter@voorbeeld.nl' }),
    ],
    hh_koppelingen: koppelingen.map(rec),
  };
  const opslag = new Map();
  let volgnummer = 0;
  const app = {
    findFirstRecordByFilter(c, _f, p) {
      let r;
      if (c === 'hh_users') r = db.hh_users.find((u) => u.get('email') === p.email && u.get('rol') === 'hulpvrager');
      if (c === 'hh_koppelingen') r = db.hh_koppelingen.find((k) => k.get('oudere') === p.oudere && k.get('familielid') === p.familielid);
      if (!r) throw new Error('niet gevonden');
      return r;
    },
    findRecordsByFilter(c, _f, _s, _l, _o, p) {
      return db.hh_koppelingen.filter((k) => k.get('familielid') === p.familielid && k.get('created') >= p.vanaf);
    },
    findCollectionByNameOrId: (n) => n,
    save(r) {
      r.id = `k${++volgnummer}`;
      r.set('created', '2026-09-27 12:00:00.000Z');
      db.hh_koppelingen.push(r);
    },
    store() {
      return { get: (k) => opslag.get(k), set: (k, v) => opslag.set(k, v) };
    },
  };
  function Record() {
    return rec({});
  }
  return { db, env: { app, Record }, opslag };
}

const NU = Date.UTC(2026, 8, 27, 12);

test('aanvraag voor een bekende oudere maakt een koppeling "aangevraagd" zonder rechten', () => {
  const s = nepServer();
  const r = hulp.verwerkAanvraag(s.env, { familielidId: 'f1', rol: 'familie', email: ' OMA@voorbeeld.nl', nu: NU });
  assert.equal(r.status, 200);
  assert.equal(r.body.melding, hulp.VAST_BERICHT);
  const k = s.db.hh_koppelingen.single ?? s.db.hh_koppelingen[0];
  assert.equal(s.db.hh_koppelingen.length, 1);
  assert.equal(k.get('oudere'), 'o1');
  assert.equal(k.get('familielid'), 'f1');
  assert.equal(k.get('status'), 'aangevraagd');
  assert.deepEqual(k.get('rechten'), []);
});

test('onbekend adres, of een jongere: PRECIES hetzelfde antwoord, niets gemaakt', () => {
  const s = nepServer();
  const bekend = hulp.verwerkAanvraag(nepServer().env, { familielidId: 'f1', rol: 'familie', email: 'oma@voorbeeld.nl', nu: NU });
  for (const email of ['niemand@voorbeeld.nl', 'jong@voorbeeld.nl']) {
    const r = hulp.verwerkAanvraag(s.env, { familielidId: 'f1', rol: 'familie', email, nu: NU });
    assert.deepEqual(r, bekend, email);
  }
  assert.equal(s.db.hh_koppelingen.length, 0);
});

test('een koppeling die al bestaat: hetzelfde antwoord, geen tweede', () => {
  const s = nepServer({ koppelingen: [{ id: 'bestaat', oudere: 'o1', familielid: 'f1', status: 'actief', created: '2026-01-01 00:00:00.000Z' }] });
  const r = hulp.verwerkAanvraag(s.env, { familielidId: 'f1', rol: 'familie', email: 'oma@voorbeeld.nl', nu: NU });
  assert.equal(r.body.melding, hulp.VAST_BERICHT);
  assert.equal(s.db.hh_koppelingen.length, 1);
  assert.equal(s.db.hh_koppelingen[0].get('status'), 'actief');
});

test('alleen de rol familie mag aanvragen', () => {
  const s = nepServer();
  const r = hulp.verwerkAanvraag(s.env, { familielidId: 'j1', rol: 'jongere', email: 'oma@voorbeeld.nl', nu: NU });
  assert.equal(r.status, 403);
  assert.equal(s.db.hh_koppelingen.length, 0);
});

test('een ongeldig adres: 400, telt niet mee', () => {
  const s = nepServer();
  const r = hulp.verwerkAanvraag(s.env, { familielidId: 'f1', rol: 'familie', email: 'geen adres', nu: NU });
  assert.equal(r.status, 400);
  assert.equal(r.body.reden, 'email');
  assert.equal(s.opslag.size, 0);
});

test('hooguit 5 aanvragen per dag, ook voor onbekende adressen', () => {
  const s = nepServer();
  for (let i = 0; i < 5; i++) {
    const r = hulp.verwerkAanvraag(s.env, { familielidId: 'f1', rol: 'familie', email: `x${i}@voorbeeld.nl`, nu: NU });
    assert.equal(r.status, 200, `poging ${i + 1}`);
  }
  const zesde = hulp.verwerkAanvraag(s.env, { familielidId: 'f1', rol: 'familie', email: 'oma@voorbeeld.nl', nu: NU });
  assert.equal(zesde.status, 429);
  assert.equal(zesde.body.reden, 'limiet');
  assert.equal(s.db.hh_koppelingen.length, 0, 'na de limiet wordt er niets meer gemaakt');
  // De volgende dag mag het weer.
  const morgen = hulp.verwerkAanvraag(s.env, { familielidId: 'f1', rol: 'familie', email: 'oma@voorbeeld.nl', nu: NU + 24 * 3600 * 1000 });
  assert.equal(morgen.status, 200);
});

test('na een herstart (lege opslag) telt de database als ondergrens', () => {
  const vandaag = Array.from({ length: 5 }, (_, i) => ({
    id: `k${i}`, oudere: `o${i + 10}`, familielid: 'f1', status: 'aangevraagd', created: '2026-09-27 08:00:00.000Z',
  }));
  const s = nepServer({ koppelingen: vandaag });
  const r = hulp.verwerkAanvraag(s.env, { familielidId: 'f1', rol: 'familie', email: 'oma@voorbeeld.nl', nu: NU });
  assert.equal(r.status, 429);
});

test('standaardrechten bij Ja of bij een koppeling die de oudere zelf maakt', () => {
  assert.deepEqual(hulp.ALLE_RECHTEN, ['meekijken', 'plaatsen']);
  assert.deepEqual(hulp.rechtenOfStandaard([]), ['meekijken', 'plaatsen']);
  assert.deepEqual(hulp.rechtenOfStandaard(null), ['meekijken', 'plaatsen']);
  assert.deepEqual(hulp.rechtenOfStandaard(['meekijken']), ['meekijken']);
});
