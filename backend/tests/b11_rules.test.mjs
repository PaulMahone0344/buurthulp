// HeitjeHulp B11 — test van de velden (150) en de rules (151) zonder server.
// Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { PARTNERS, partnerVelden, userVelden, NIEUWE_COLLECTIES } from '../scripts/150-b11-velden.mjs';
import {
  PARTNER_RULES,
  USERS_SLOT_KENNISMAKING,
  USERS_SLOT_PARTNER,
  BERICHTEN_OUD,
  BERICHTEN_NIEUW,
  chatVoorMeldkamer,
} from '../scripts/151-b11-rules.mjs';
import { laadHulp } from './_nep_app.mjs';

const hulp = laadHulp('hh_meldkamer_hulp.js');
const IDS = { hh_users: 'u', hh_partners: 'p' };
const opNaam = (lijst) => Object.fromEntries(lijst.map((f) => [f.name, f]));

test('hh_partners: code uniek met hetzelfde patroon als de hook', () => {
  const v = opNaam(partnerVelden());
  assert.equal(v.code.required, true);
  assert.equal(v.code.pattern, '^[A-Z0-9-]{3,20}$');
  assert.equal(v.naam.required, true);
  assert.equal(v.actief.type, 'bool');
  const def = NIEUWE_COLLECTIES.find((c) => c.naam === PARTNERS);
  assert.ok(def.indexen.some((i) => /UNIQUE INDEX .*\(code\)/.test(i)));
  assert.equal(hulp.normaliseerCode('tiel-jw'), 'TIEL-JW');
  assert.match('TIEL-JW', new RegExp(v.code.pattern));
});

test('hh_users: kennismaking-keuzes gelijk aan de hook, relaties zonder cascade', () => {
  const v = opNaam(userVelden(IDS));
  assert.deepEqual(v.kennismaking_status.values, hulp.KENNISMAKING_STATUSSEN);
  assert.equal(v.kennismaking_door.cascadeDelete, false);
  assert.equal(v.kennismaking_notitie.max, hulp.NOTITIE_MAX);
  assert.equal(v.partner.collectionId, 'p');
  assert.equal(v.partner.cascadeDelete, false, 'partner weg = helper blijft');
  assert.equal(v.partner.required, false);
});

test('rules hh_partners: alleen coordinator, alles', () => {
  for (const k of ['listRule', 'viewRule', 'createRule', 'updateRule', 'deleteRule']) {
    assert.ok(PARTNER_RULES[k].includes('@request.auth.rol = "coordinator"'), k);
    assert.ok(PARTNER_RULES[k].includes('@request.auth.collectionName = "hh_users"'), k);
  }
});

test('sloten hh_users: kennismaking voor niemand via de API, partner alleen coordinator', () => {
  for (const veld of ['kennismaking_status', 'kennismaking_op', 'kennismaking_door', 'kennismaking_notitie']) {
    assert.ok(USERS_SLOT_KENNISMAKING.includes(`@request.body.${veld}:isset = false`), veld);
  }
  assert.ok(!USERS_SLOT_KENNISMAKING.includes('coordinator'), 'ook de coordinator gaat via de route');
  assert.ok(USERS_SLOT_PARTNER.includes('@request.body.partner:isset = false'));
  assert.ok(USERS_SLOT_PARTNER.includes('@request.auth.rol = "coordinator"'));
});

test('chat: meldkamer leest alles (besluit 4 okt); rest van de rule blijft gelijk; tweede keer niets', () => {
  const oud =
    '@request.auth.id != "" && @request.auth.collectionName = "hh_users" && ((klus.hulpvrager = @request.auth.id && verborgen_bewoner = false) || ' +
    BERICHTEN_OUD +
    ')';
  const nieuw = chatVoorMeldkamer(oud);
  assert.ok(nieuw.includes(BERICHTEN_NIEUW));
  assert.ok(!nieuw.includes('hh_incidenten'));
  assert.ok(nieuw.includes('klus.hulpvrager = @request.auth.id && verborgen_bewoner = false'));
  assert.equal(chatVoorMeldkamer(nieuw), nieuw);
  assert.throws(() => chatVoorMeldkamer('iets anders'), /herken/);
  assert.equal(chatVoorMeldkamer(null), null);
});

test('startwaarden instellingen: alles uit, 4 klussen in 30 dagen', () => {
  const op = Object.fromEntries(hulp.STANDAARD_INSTELLINGEN.map((r) => [r.sleutel, r.waarde]));
  assert.equal(op.b11_kennismaking_verplicht, false);
  assert.equal(op.b11_zelfde_paar_aan, false);
  assert.equal(op.b11_zelfde_paar_aantal, 4);
  assert.equal(op.b11_zelfde_paar_dagen, 30);
});
