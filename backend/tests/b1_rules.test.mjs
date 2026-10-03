// HeitjeHulp B1 — test van de wikkel uit 71-b1-rules.mjs zonder server.
// Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { metSlot } from '../scripts/61-beheer-rules.mjs';
import { B1_SLOT_VELDEN, B1_VRIJ, slot } from '../scripts/71-b1-rules.mjs';

const M14 = '(A && B) && ((@request.auth.collectionName = "hh_users" && @request.auth.rol = "coordinator") || (@request.body.geblokkeerd:isset = false))';

test('B1-slot wikkelt de live rule en laat het M14-slot staan', () => {
  const nieuw = metSlot(M14, B1_SLOT_VELDEN.hh_users);
  assert.ok(nieuw.startsWith(`(${M14}) && `));
  assert.ok(nieuw.includes('@request.body.ouder_toestemming_op:isset = false && @request.body.ouder_iban_ok:isset = false'));
  assert.ok(nieuw.includes(slot(B1_SLOT_VELDEN.hh_users)));
});

test('B1-slot is idempotent en laat null staan', () => {
  const een = metSlot(M14, B1_SLOT_VELDEN.hh_profielen);
  assert.equal(metSlot(een, B1_SLOT_VELDEN.hh_profielen), een);
  assert.equal(metSlot(null, B1_SLOT_VELDEN.hh_profielen), null);
  assert.throws(() => metSlot('', B1_SLOT_VELDEN.hh_profielen));
});

test('ouder_email, ouder_telefoon en huisnummer zitten NIET in het slot', () => {
  for (const v of B1_VRIJ.hh_users) {
    assert.ok(!slot(B1_SLOT_VELDEN.hh_users).includes(v));
    assert.ok(!slot(B1_SLOT_VELDEN.hh_profielen).includes(v));
  }
});
