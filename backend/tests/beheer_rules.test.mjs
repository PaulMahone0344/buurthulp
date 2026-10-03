// HeitjeHulp M14 — test van de rule-wikkel uit scripts/61-beheer-rules.mjs,
// zonder server. Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { metSlot, slot, NIEUWE_RULES, SLOT_VELDEN, COORD } from '../scripts/61-beheer-rules.mjs';

const AUTH = '@request.auth.id != "" && @request.auth.collectionName = "hh_users"';
// Zoals 02 + 21 hem op de server zetten (letterlijk dezelfde bouwstenen).
const USERS_UPDATE =
  `(${AUTH} && ((id = @request.auth.id && @request.body.rol:isset = false) || @request.auth.rol = "coordinator")) && ` +
  '@request.body.sterren_gemiddeld:isset = false && @request.body.klussen_aantal:isset = false';

test('de wikkel laat de huidige rule letterlijk staan en voegt alleen het slot toe', () => {
  const nieuw = metSlot(USERS_UPDATE, ['geblokkeerd']);
  assert.ok(nieuw.startsWith(`(${USERS_UPDATE}) && `));
  assert.ok(nieuw.endsWith(slot(['geblokkeerd'])));
  assert.ok(nieuw.includes('@request.body.geblokkeerd:isset = false'));
  assert.ok(nieuw.includes(COORD));
});

test('de wikkel is idempotent', () => {
  const een = metSlot(USERS_UPDATE, ['geblokkeerd']);
  assert.equal(metSlot(een, ['geblokkeerd']), een);
});

test('null blijft null, leeg wordt geweigerd', () => {
  assert.equal(metSlot(null, ['geblokkeerd']), null);
  assert.throws(() => metSlot('', ['geblokkeerd']));
});

test('profiel: alle drie nieuwe velden achter het slot', () => {
  assert.deepEqual(SLOT_VELDEN.hh_profielen, ['screening_notitie', 'vog_geldig_tot', 'intake_op']);
  const s = slot(SLOT_VELDEN.hh_profielen);
  assert.ok(
    s.includes(
      '@request.body.screening_notitie:isset = false && @request.body.vog_geldig_tot:isset = false && @request.body.intake_op:isset = false'
    )
  );
});

test('nieuwe collecties: alleen coordinator, auditlog niet te schrijven via de API', () => {
  for (const [naam, rules] of Object.entries(NIEUWE_RULES)) {
    for (const [k, r] of Object.entries(rules)) {
      if (r === null) continue;
      assert.ok(r.includes(AUTH), `${naam}.${k} eist login`);
      assert.ok(r.includes('@request.auth.rol = "coordinator"'), `${naam}.${k} eist coordinator`);
      assert.notEqual(r, '', `${naam}.${k} is niet publiek`);
    }
  }
  assert.equal(NIEUWE_RULES.hh_auditlog.createRule, null);
  assert.equal(NIEUWE_RULES.hh_auditlog.updateRule, null);
  assert.equal(NIEUWE_RULES.hh_auditlog.deleteRule, null);
});
