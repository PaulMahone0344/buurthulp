// HeitjeHulp B2 — test van de wikkels uit 80-b2-rules.mjs zonder server.
// Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  KLUS_ANKER,
  KLUS_VOORWAARDE,
  ID_SLOT,
  GEBOORTEDATUM_SLOT,
  metKlusVoorwaarde,
  metExtra,
  metRuimeWijk,
  WIJK_ANKER,
  WIJK_RUIM,
  WERKGEBIED_SLOT,
  B2_WIJZIGINGEN,
} from '../scripts/80-b2-rules.mjs';
import { REGIO_WIJK, B2_VELDEN, WERKGEBIED_STATUSSEN } from '../scripts/81-b2-werkgebied.mjs';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const hier = path.dirname(fileURLToPath(import.meta.url));
const bron = readFileSync(path.join(hier, '..', 'pb_hooks', 'hh_aanmelden_hulp.js'), 'utf8');
const module_ = { exports: {} };
new Function('module', 'exports', bron)(module_, module_.exports);
const hulp = module_.exports;

// Zoals hh_klussen.listRule live op prod (3 okt 2026), ingekort.
const LIVE =
  '@request.auth.id != "" && (hulpvrager = @request.auth.id || toegewezen_jongere = @request.auth.id || ' +
  '(@request.auth.rol = "jongere" && status = "open" && @request.auth.wijk != "" && hulpvrager.wijk = @request.auth.wijk && ' +
  '@collection.hh_profielen.gebruiker ?= @request.auth.id && @collection.hh_profielen.verificatiestatus ?= "goedgekeurd") || ' +
  '@request.auth.rol = "coordinator")';

test('klusvoorwaarde komt precies in de helper-tak, de rest blijft letterlijk', () => {
  const nieuw = metKlusVoorwaarde(LIVE);
  assert.equal(nieuw, LIVE.replace(KLUS_ANKER, `${KLUS_ANKER} && ${KLUS_VOORWAARDE}`));
  assert.ok(nieuw.includes('toegewezen_jongere = @request.auth.id || ('), 'eigen klussen blijven zichtbaar');
  assert.ok(nieuw.includes('@request.auth.ouder_toestemming_op != ""'));
  assert.ok(nieuw.includes('@collection.hh_profielen.vog_gezien_op ?!= ""'));
});

test('klusvoorwaarde is idempotent', () => {
  const een = metKlusVoorwaarde(LIVE);
  assert.equal(metKlusVoorwaarde(een), een);
});

test('klusvoorwaarde weigert als het anker er niet precies één keer staat', () => {
  assert.throws(() => metKlusVoorwaarde('@request.auth.rol = "coordinator"'));
  assert.throws(() => metKlusVoorwaarde(`${LIVE} || (${KLUS_ANKER})`));
  assert.equal(metKlusVoorwaarde(null), null);
});

test('ID-slot: eigenaar mag document_foto alleen zetten zolang niet goedgekeurd', () => {
  assert.ok(ID_SLOT.includes('verificatiestatus != "goedgekeurd"'));
  assert.ok(ID_SLOT.includes('@request.body.document_foto:isset = false'));
  assert.ok(ID_SLOT.includes('@request.auth.rol = "coordinator"'));
});

test('geboortedatum-slot: alleen de coordinator wijzigt hem na aanmaken', () => {
  assert.ok(GEBOORTEDATUM_SLOT.includes('@request.body.geboortedatum:isset = false'));
  assert.ok(GEBOORTEDATUM_SLOT.includes('@request.auth.rol = "coordinator"'));
});

test('metExtra wikkelt, is idempotent, laat null staan en weigert ""', () => {
  const oud = '(A) && (B)';
  const nieuw = metExtra(oud, ID_SLOT);
  assert.equal(nieuw, `(${oud}) && ${ID_SLOT}`);
  assert.equal(metExtra(nieuw, ID_SLOT), nieuw);
  assert.equal(metExtra(null, ID_SLOT), null);
  assert.throws(() => metExtra('', ID_SLOT));
});

test('ruime wijk: precies het anker vervangen, idempotent, weigert afwijking', () => {
  const nieuw = metRuimeWijk(LIVE);
  assert.equal(nieuw, LIVE.replace(WIJK_ANKER, WIJK_RUIM));
  assert.equal(metRuimeWijk(nieuw), nieuw);
  assert.throws(() => metRuimeWijk('@request.auth.rol = "coordinator"'));
  assert.equal(metRuimeWijk(null), null);
  assert.ok(WIJK_RUIM.includes('hulpvrager.wijk.regio = true || @request.auth.wijk.regio = true'));
});

test('hh_klussen list/view: klusvoorwaarde én ruime wijk, in één keer', () => {
  for (const rule of ['listRule', 'viewRule']) {
    const w = B2_WIJZIGINGEN.find((x) => x.collectie === 'hh_klussen' && x.rule === rule);
    const nieuw = w.nieuw(LIVE);
    assert.ok(nieuw.includes(KLUS_VOORWAARDE));
    assert.ok(nieuw.includes(WIJK_RUIM));
    assert.equal(w.nieuw(nieuw), nieuw);
  }
});

test('werkgebied-slot: wijk en werkgebied_status alleen coordinator/server', () => {
  assert.ok(WERKGEBIED_SLOT.includes('@request.body.wijk:isset = false'));
  assert.ok(WERKGEBIED_SLOT.includes('@request.body.werkgebied_status:isset = false'));
  const users = B2_WIJZIGINGEN.filter((x) => x.collectie === 'hh_users').map((x) => x.rule).sort();
  assert.deepEqual(users, ['createRule', 'updateRule']);
  const upd = B2_WIJZIGINGEN.find((x) => x.collectie === 'hh_users' && x.rule === 'updateRule').nieuw('(A)');
  assert.ok(upd.includes(GEBOORTEDATUM_SLOT) && upd.includes(WERKGEBIED_SLOT));
});

test('81: de regio-wijk is dezelfde als WERKGEBIEDEN in de hook', () => {
  const [g] = hulp.WERKGEBIEDEN;
  assert.equal(REGIO_WIJK.gemeente, g.gemeente);
  assert.equal(REGIO_WIJK.wijk, g.wijk);
  assert.equal(REGIO_WIJK.regio, true);
  assert.equal(REGIO_WIJK.actief, true);
  assert.deepEqual(WERKGEBIED_STATUSSEN, ['binnen', 'buiten', 'onbekend']);
  assert.equal(B2_VELDEN.hh_wijken[0].name, 'regio');
  assert.equal(B2_VELDEN.hh_users[0].name, 'werkgebied_status');
});

test('84: alleen jongere1-3 met rol jongere, geen andere seed-accounts', async () => {
  const { seedHelpers } = await import('../scripts/84-seed-vog.mjs');
  const accounts = {
    hulpvrager1: { id: 'h1', rol: 'hulpvrager' },
    jongere2: { id: 'j2', rol: 'jongere' },
    jongere1: { id: 'j1', rol: 'jongere' },
    jongere3: { id: 'j3', rol: 'jongere' },
    jongereX: { id: 'jx', rol: 'jongere' },
    jongere4: { id: 'j4', rol: 'coordinator' },
    coordinator1: { id: 'c1', rol: 'coordinator' },
  };
  assert.deepEqual(seedHelpers(accounts), [
    { sleutel: 'jongere1', id: 'j1' },
    { sleutel: 'jongere2', id: 'j2' },
    { sleutel: 'jongere3', id: 'j3' },
  ]);
  assert.deepEqual(seedHelpers(null), []);
});
