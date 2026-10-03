// HeitjeHulp B6+ (integratie, antwoorden Ibrahim 4 okt) — "Gesprek
// verwijderen" en het wissen van berichten bij accountverwijdering (AVG),
// zonder server. hh_chat_hulp.js krijgt een nep-app met records in het geheugen.
// Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const hier = path.dirname(fileURLToPath(import.meta.url));
const bron = readFileSync(path.join(hier, '..', 'pb_hooks', 'hh_chat_hulp.js'), 'utf8');
const module_ = { exports: {} };
new Function('module', 'exports', bron)(module_, module_.exports);
const hulp = module_.exports;

// ---- nep-app ------------------------------------------------------------------

class NepRecord {
  constructor(collectie, data) {
    this.collectie = collectie;
    this.id = data.id;
    this.data = { ...data };
  }
  get(veld) {
    return this.data[veld];
  }
  set(veld, waarde) {
    this.data[veld] = waarde;
  }
}

function nepApp(rijen) {
  const db = {};
  for (const [collectie, lijst] of Object.entries(rijen)) {
    db[collectie] = lijst.map((d) => new NepRecord(collectie, d));
  }
  const opgeslagen = [];
  const passend = (collectie, filter, p) => {
    const lijst = db[collectie] || [];
    const f = filter.replace(/\s+/g, ' ').trim();
    if (collectie === 'hh_incidenten' && f === "klus = {:klus} && afhandeling = ''") {
      return lijst.filter((r) => r.get('klus') === p.klus && !String(r.get('afhandeling') || '').trim());
    }
    if (collectie === 'hh_berichten' && f === 'klus = {:klus}') return lijst.filter((r) => r.get('klus') === p.klus);
    if (collectie === 'hh_berichten' && f === 'klus = {:klus} && helper = {:helper}') {
      return lijst.filter((r) => r.get('klus') === p.klus && r.get('helper') === p.helper);
    }
    if (collectie === 'hh_berichten' && f === 'afzender = {:afzender}') return lijst.filter((r) => r.get('afzender') === p.afzender);
    if (collectie === 'hh_berichten' && f === 'klus = {:klus} && wissen_na_incident = true') {
      return lijst.filter((r) => r.get('klus') === p.klus && r.get('wissen_na_incident') === true);
    }
    throw new Error(`nep-app kent dit filter niet: ${collectie} "${f}"`);
  };
  return {
    db,
    opgeslagen,
    findRecordById(collectie, id) {
      const r = (db[collectie] || []).find((x) => x.id === id);
      if (!r) throw new Error('niet gevonden');
      return r;
    },
    findRecordsByFilter(collectie, filter, _sort, limit, _offset, params) {
      const uit = passend(collectie, filter, params || {});
      return limit ? uit.slice(0, limit) : uit;
    },
    save(record) {
      opgeslagen.push(record.id);
    },
  };
}

const KLUS = { id: 'k1', hulpvrager: 'bewoner', toegewezen_jongere: 'helper' };
const bericht = (id, afzender, extra = {}) => ({
  id, klus: 'k1', afzender, helper: 'helper', tekst: `tekst ${id}`, gefilterd: false,
  verborgen_bewoner: false, verborgen_helper: false, gewist: false, wissen_na_incident: false, ...extra,
});

// ---- puur ---------------------------------------------------------------------

test('rolInGesprek: bewoner, huidige helper of niemand', () => {
  assert.equal(hulp.rolInGesprek('bewoner', KLUS), 'bewoner');
  assert.equal(hulp.rolInGesprek('helper', KLUS), 'helper');
  assert.equal(hulp.rolInGesprek('ander', KLUS), '');
  assert.equal(hulp.rolInGesprek('', KLUS), '');
  assert.equal(hulp.rolInGesprek('helper', { ...KLUS, toegewezen_jongere: '' }), '');
});

test('verbergVeld: elk zijn eigen markering', () => {
  assert.equal(hulp.verbergVeld('bewoner'), 'verborgen_bewoner');
  assert.equal(hulp.verbergVeld('helper'), 'verborgen_helper');
  assert.equal(hulp.verbergVeld(''), '');
});

test('GEWIST: tekst leeg + markering, geen filter-sporen meer', () => {
  assert.deepEqual(hulp.GEWIST, { tekst: '', gewist: true, gefilterd: false, contactverzoek: false, wissen_na_incident: false });
  assert.equal(hulp.MELDING_INCIDENT.includes('meldkamer'), true);
});

// ---- met app ------------------------------------------------------------------

test('heeftOpenIncident: alleen een incident zonder afhandeling telt', () => {
  const app = nepApp({ hh_incidenten: [{ id: 'i1', klus: 'k1', afhandeling: 'Gebeld.' }] });
  assert.equal(hulp.heeftOpenIncident(app, 'k1'), false);
  app.db.hh_incidenten.push(new NepRecord('hh_incidenten', { id: 'i2', klus: 'k1', afhandeling: '  ' }));
  assert.equal(hulp.heeftOpenIncident(app, 'k1'), true);
  assert.equal(hulp.heeftOpenIncident(app, 'k2'), false);
});

test('verbergGesprek: de bewoner verbergt het hele gesprek alleen voor zichzelf', () => {
  const app = nepApp({
    hh_berichten: [bericht('b1', 'bewoner'), bericht('b2', 'helper'), bericht('b3', 'helper', { helper: 'oudehelper' })],
    hh_incidenten: [],
  });
  const uit = hulp.verbergGesprek(app, new NepRecord('hh_klussen', KLUS), 'bewoner');
  assert.deepEqual(uit, { status: 200, body: { verborgen: 3 } });
  for (const r of app.db.hh_berichten) {
    assert.equal(r.get('verborgen_bewoner'), true, r.id);
    assert.equal(r.get('verborgen_helper'), false, 'de ander houdt zijn kopie');
    assert.equal(r.get('tekst'), `tekst ${r.id}`, 'niets gewist');
  }
});

test('verbergGesprek: de helper verbergt alleen zijn eigen gesprek', () => {
  const app = nepApp({
    hh_berichten: [bericht('b1', 'bewoner'), bericht('b3', 'bewoner', { helper: 'oudehelper' })],
    hh_incidenten: [],
  });
  const uit = hulp.verbergGesprek(app, new NepRecord('hh_klussen', KLUS), 'helper');
  assert.deepEqual(uit, { status: 200, body: { verborgen: 1 } });
  assert.equal(app.db.hh_berichten[0].get('verborgen_helper'), true);
  assert.equal(app.db.hh_berichten[1].get('verborgen_helper'), false);
});

test('verbergGesprek: een ander 403; een lopend incident 409 en er verandert niets', () => {
  const app = nepApp({ hh_berichten: [bericht('b1', 'bewoner')], hh_incidenten: [{ id: 'i1', klus: 'k1', afhandeling: '' }] });
  assert.equal(hulp.verbergGesprek(app, new NepRecord('hh_klussen', KLUS), 'ander').status, 403);
  const uit = hulp.verbergGesprek(app, new NepRecord('hh_klussen', KLUS), 'bewoner');
  assert.equal(uit.status, 409);
  assert.equal(uit.body.reden, 'incident');
  assert.equal(app.db.hh_berichten[0].get('verborgen_bewoner'), false);
  assert.equal(app.opgeslagen.length, 0);
});

test('berichtenVan + wisBerichten: eigen berichten gewist, bij een lopend incident uitgesteld', () => {
  const app = nepApp({
    hh_berichten: [
      bericht('b1', 'helper'),
      bericht('b2', 'bewoner'),
      bericht('b3', 'helper', { klus: 'k2', gefilterd: true }),
    ],
    hh_incidenten: [{ id: 'i1', klus: 'k2', afhandeling: '' }],
  });
  const ids = hulp.berichtenVan(app, 'helper');
  assert.deepEqual(ids, ['b1', 'b3']);
  const uit = hulp.wisBerichten(app, [...ids, 'bestaatniet']);
  assert.deepEqual(uit, { gewist: 1, uitgesteld: 1 });
  const [b1, b2, b3] = app.db.hh_berichten;
  assert.equal(b1.get('tekst'), '');
  assert.equal(b1.get('gewist'), true);
  assert.equal(b2.get('tekst'), 'tekst b2', 'het bericht van de ander blijft');
  assert.equal(b3.get('tekst'), 'tekst b3', 'incident loopt: nog niet wissen');
  assert.equal(b3.get('wissen_na_incident'), true);
  assert.equal(b3.get('gewist'), false);
});

test('wisNaIncident: pas als er geen open incident meer is op de klus', () => {
  const app = nepApp({
    hh_berichten: [bericht('b3', 'helper', { klus: 'k2', wissen_na_incident: true }), bericht('b4', 'bewoner', { klus: 'k2' })],
    hh_incidenten: [{ id: 'i1', klus: 'k2', afhandeling: '' }, { id: 'i2', klus: 'k2', afhandeling: '' }],
  });
  app.db.hh_incidenten[0].set('afhandeling', 'Afgehandeld.');
  assert.equal(hulp.wisNaIncident(app, 'k2'), 0, 'i2 loopt nog');
  app.db.hh_incidenten[1].set('afhandeling', 'Ook klaar.');
  assert.equal(hulp.wisNaIncident(app, 'k2'), 1);
  assert.equal(app.db.hh_berichten[0].get('tekst'), '');
  assert.equal(app.db.hh_berichten[0].get('gewist'), true);
  assert.equal(app.db.hh_berichten[0].get('wissen_na_incident'), false);
  assert.equal(app.db.hh_berichten[1].get('tekst'), 'tekst b4');
  assert.equal(hulp.wisNaIncident(app, 'k2'), 0, 'tweede keer niets meer');
});
