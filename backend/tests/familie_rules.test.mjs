// HeitjeHulp M9 — test van de rule-wikkel uit scripts/41-familie-rules.mjs,
// zonder server. Draaien (vanuit de repo-root):
//   node --test backend/tests/*.test.mjs
//
// De invoer zijn de rules zoals 02/06/13 ze op de server zetten (letterlijk
// dezelfde bouwstenen). 41 mag ALLEEN de familie-takken aanraken.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  wikkelRule,
  wikkelCollectie,
  ACTIEF,
  MAG_MEEKIJKEN,
  MAG_PLAATSEN,
  JONGERE_VAN_MIJN_OUDERE,
} from '../scripts/41-familie-rules.mjs';

const AUTH = '@request.auth.id != "" && @request.auth.collectionName = "hh_users"';
const COORD = '@request.auth.rol = "coordinator"';
const FAMILIE_VAN = (veld) =>
  `(@request.auth.rol = "familie" && @collection.hh_koppelingen.oudere ?= ${veld} && @collection.hh_koppelingen.familielid ?= @request.auth.id)`;

const KLUSSEN_LIST =
  `${AUTH} && (hulpvrager = @request.auth.id || toegewezen_jongere = @request.auth.id || ` +
  '(@request.auth.rol = "jongere" && status = "open" && @request.auth.wijk != "" && hulpvrager.wijk = @request.auth.wijk) || ' +
  `${FAMILIE_VAN('hulpvrager')} || ${COORD})`;

const KLUSSEN_CREATE =
  `${AUTH} && (` +
  '(@request.auth.rol = "hulpvrager" && @request.body.hulpvrager = @request.auth.id && @request.body.geplaatst_door = @request.auth.id && ' +
  '@request.body.bron = "app" && X) || ' +
  '(@request.auth.rol = "familie" && @request.body.geplaatst_door = @request.auth.id && @request.body.bron = "familie" && ' +
  '@collection.hh_koppelingen.oudere ?= @request.body.hulpvrager && @collection.hh_koppelingen.familielid ?= @request.auth.id && ' +
  `X) || ${COORD})`;

const KLUSSEN_UPDATE =
  `${AUTH} && (` +
  `((hulpvrager = @request.auth.id || ${FAMILIE_VAN('hulpvrager')}) && @request.body.hulpvrager:isset = false && @request.body.geplaatst_door:isset = false) || ` +
  `${COORD})`;

const USERS_LIST =
  `${AUTH} && (id = @request.auth.id || ${COORD} || ` +
  'hh_klussen_via_toegewezen_jongere.hulpvrager ?= @request.auth.id || ' +
  'hh_klussen_via_hulpvrager.toegewezen_jongere ?= @request.auth.id || ' +
  'hh_koppelingen_via_oudere.familielid ?= @request.auth.id || ' +
  'hh_koppelingen_via_familielid.oudere ?= @request.auth.id)';

test('lezen: de familie-tak eist een actieve koppeling met recht meekijken', () => {
  const r = wikkelRule('hh_klussen', 'listRule', KLUSSEN_LIST);
  assert.equal(r.aantal, 1);
  assert.ok(r.rule.includes(`${ACTIEF} && ${MAG_MEEKIJKEN})`));
  assert.ok(!r.rule.includes(MAG_PLAATSEN));
  // De rest van de rule staat er letterlijk nog.
  assert.ok(r.rule.startsWith(`${AUTH} && (hulpvrager = @request.auth.id || toegewezen_jongere = @request.auth.id || (@request.auth.rol = "jongere"`));
  assert.ok(r.rule.endsWith(` || ${COORD})`));
});

test('plaatsen: createRule van hh_klussen eist actief en recht plaatsen', () => {
  const r = wikkelRule('hh_klussen', 'createRule', KLUSSEN_CREATE);
  assert.equal(r.aantal, 1);
  assert.ok(r.rule.includes(`@collection.hh_koppelingen.familielid ?= @request.auth.id && ${ACTIEF} && ${MAG_PLAATSEN} && X)`));
  // De tak van de oudere zelf is ongemoeid.
  assert.ok(r.rule.includes('@request.body.bron = "app" && X) || '));
});

test('plaatsen: updateRule van hh_klussen (familie-tak) eist recht plaatsen', () => {
  const r = wikkelRule('hh_klussen', 'updateRule', KLUSSEN_UPDATE);
  assert.equal(r.aantal, 1);
  assert.ok(r.rule.includes(`${ACTIEF} && ${MAG_PLAATSEN})`));
  assert.ok(!r.rule.includes(MAG_MEEKIJKEN));
});

test('hh_users: familielid ziet de oudere pas bij actief, en de jongere op zijn klus', () => {
  const r = wikkelRule('hh_users', 'listRule', USERS_LIST);
  assert.equal(r.aantal, 1);
  assert.ok(r.rule.includes('(hh_koppelingen_via_oudere.familielid ?= @request.auth.id && hh_koppelingen_via_oudere.status ?= "actief")'));
  assert.ok(r.rule.includes(JONGERE_VAN_MIJN_OUDERE));
  // De oudere ziet een familielid ook bij een aanvraag (om Ja of Nee te zeggen).
  assert.ok(r.rule.includes('hh_koppelingen_via_familielid.oudere ?= @request.auth.id)'));
  assert.ok(!r.rule.includes('hh_koppelingen_via_familielid.status'));
});

test('idempotent: een tweede keer wikkelen verandert niets', () => {
  for (const [col, key, rule] of [
    ['hh_klussen', 'listRule', KLUSSEN_LIST],
    ['hh_klussen', 'createRule', KLUSSEN_CREATE],
    ['hh_klussen', 'updateRule', KLUSSEN_UPDATE],
    ['hh_users', 'listRule', USERS_LIST],
  ]) {
    const eerste = wikkelRule(col, key, rule);
    const tweede = wikkelRule(col, key, eerste.rule);
    assert.equal(tweede.rule, eerste.rule, `${col}.${key}`);
    assert.equal(tweede.aantal, 0, `${col}.${key}`);
    assert.equal(tweede.alGewikkeld, true, `${col}.${key}`);
  }
});

test('rules zonder familie-tak blijven letterlijk gelijk', () => {
  for (const rule of [
    `${AUTH} && (melder = @request.auth.id || ${COORD})`,
    `${AUTH} && ${COORD}`,
    null,
    `${AUTH} && (oudere = @request.auth.id || familielid = @request.auth.id || ${COORD})`,
  ]) {
    const r = wikkelRule('hh_incidenten', 'listRule', rule);
    assert.equal(r.rule, rule);
    assert.equal(r.aantal, 0);
  }
});

test('meerdere familie-takken in één rule worden allemaal gewikkeld', () => {
  const rule = `${AUTH} && (${FAMILIE_VAN('klus.hulpvrager')} || ${FAMILIE_VAN('oudere')})`;
  const r = wikkelRule('hh_vertrouwd', 'viewRule', rule);
  assert.equal(r.aantal, 2);
});

test('wikkelCollectie: alleen de sleutels die veranderen', () => {
  const uit = wikkelCollectie('hh_klussen', {
    listRule: KLUSSEN_LIST,
    viewRule: KLUSSEN_LIST,
    createRule: KLUSSEN_CREATE,
    updateRule: KLUSSEN_UPDATE,
    deleteRule: `${AUTH} && ((hulpvrager = @request.auth.id && status = "concept") || ${COORD})`,
  });
  assert.deepEqual(Object.keys(uit.gewijzigd).sort(), ['createRule', 'listRule', 'updateRule', 'viewRule']);
});

test('een lege rule ("" = publiek) wordt geweigerd', () => {
  assert.throws(() => wikkelRule('hh_klussen', 'listRule', ''));
});
