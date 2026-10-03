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
} from '../scripts/80-b2-rules.mjs';

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
