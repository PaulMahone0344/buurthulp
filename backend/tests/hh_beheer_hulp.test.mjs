// HeitjeHulp M14 — test van backend/pb_hooks/hh_beheer_hulp.js zonder server.
// Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const hier = path.dirname(fileURLToPath(import.meta.url));
const bron = readFileSync(path.join(hier, '..', 'pb_hooks', 'hh_beheer_hulp.js'), 'utf8');
const module_ = { exports: {} };
new Function('module', 'exports', bron)(module_, module_.exports);
const hulp = module_.exports;

test('de zes beheercollecties uit de prompt worden gelogd', () => {
  assert.deepEqual(hulp.AUDIT_COLLECTIES, [
    'hh_wijken',
    'hh_klustypes',
    'hh_users',
    'hh_profielen',
    'hh_instellingen',
    'hh_incidenten',
  ]);
});

test('isHhPad: alleen hh-routes, hh-collecties en realtime', () => {
  assert.equal(hulp.isHhPad('/api/hh/klussen/abc/accepteren'), true);
  assert.equal(hulp.isHhPad('/api/collections/hh_klussen/records'), true);
  assert.equal(hulp.isHhPad('/api/collections/hh_users/auth-refresh'), true);
  assert.equal(hulp.isHhPad('/api/realtime'), true);
  assert.equal(hulp.isHhPad('/api/collections/obycom_activities/records'), false);
  assert.equal(hulp.isHhPad('/api/collections/users/auth-with-password'), false);
  assert.equal(hulp.isHhPad('/_/'), false);
  assert.equal(hulp.isHhPad(''), false);
});

test('isCoordinator: rol coordinator uit hh_users, niets anders', () => {
  assert.equal(hulp.isCoordinator('hh_users', 'coordinator'), true);
  assert.equal(hulp.isCoordinator('hh_users', 'jongere'), false);
  assert.equal(hulp.isCoordinator('users', 'coordinator'), false);
  assert.equal(hulp.isCoordinator('', ''), false);
});

test('wijzigen: alleen de velden die veranderden, met van en naar', () => {
  const detail = hulp.auditDetail(
    'wijzigen',
    { naam: 'Sami', rol: 'jongere', geblokkeerd: false, updated: 'a' },
    { naam: 'Sami', rol: 'familie', geblokkeerd: true, updated: 'b' },
  );
  assert.deepEqual(detail, {
    velden: ['geblokkeerd', 'rol'],
    van: { geblokkeerd: false, rol: 'jongere' },
    naar: { geblokkeerd: true, rol: 'familie' },
  });
});

test('geheime velden: wel de naam, nooit de waarde', () => {
  const detail = hulp.auditDetail(
    'wijzigen',
    { iban: 'NL91ABNA0417164300', selfie: 'a.jpg', password: '' },
    { iban: 'NL02RABO0123456789', selfie: 'b.jpg', password: 'nieuw-geheim' },
  );
  assert.deepEqual(detail.velden, ['iban', 'password', 'selfie']);
  assert.deepEqual(detail.van, {});
  assert.deepEqual(detail.naar, {});
  assert.equal(JSON.stringify(detail).includes('NL02'), false);
});

test('aanmaken: alleen gevulde velden', () => {
  const detail = hulp.auditDetail('aanmaken', null, {
    gemeente: 'Tiel',
    wijk: 'Kellen',
    postcodes: ['4005'],
    actief: false,
    leeg: '',
  });
  assert.deepEqual(detail.velden, ['actief', 'gemeente', 'postcodes', 'wijk']);
  assert.deepEqual(detail.waarden.postcodes, ['4005']);
});

test('verwijderen: wat er stond', () => {
  const detail = hulp.auditDetail('verwijderen', { sleutel: 'straal_km', waarde: 5 }, null);
  assert.deepEqual(detail, { velden: ['sleutel', 'waarde'], waarden: { sleutel: 'straal_km', waarde: 5 } });
});

test('lange teksten worden afgekapt', () => {
  const lang = 'x'.repeat(500);
  const detail = hulp.auditDetail('wijzigen', { afhandeling: '' }, { afhandeling: lang });
  assert.equal(detail.naar.afhandeling.length, 201);
});

test('plat: leest velden per soort en slaat wachtwoord en systeemvelden over', () => {
  const velden = [
    ['id', 'text'],
    ['password', 'password'],
    ['naam', 'text'],
    ['geblokkeerd', 'bool'],
    ['richtduur', 'number'],
    ['postcodes', 'json'],
    ['klustypes', 'relation'],
    ['created', 'autodate'],
  ].map(([n, t]) => ({ getName: () => n, type: () => t }));
  const waarden = {
    naam: 'Tiel-West',
    geblokkeerd: true,
    richtduur: 45,
    postcodes: '["4001"]',
    klustypes: ['a', 'b'],
  };
  const record = { collection: () => ({ fields: velden }), get: (n) => waarden[n] };
  assert.deepEqual(hulp.plat(record, (raw) => raw), {
    naam: 'Tiel-West',
    geblokkeerd: true,
    richtduur: 45,
    postcodes: ['4001'],
    klustypes: ['a', 'b'],
  });
});

test('B1 isGoedkeuring: alleen de overgang naar goedgekeurd', () => {
  assert.equal(hulp.isGoedkeuring('in_behandeling', 'goedgekeurd'), true);
  assert.equal(hulp.isGoedkeuring('', 'goedgekeurd'), true);
  assert.equal(hulp.isGoedkeuring('afgewezen', 'goedgekeurd'), true);
  assert.equal(hulp.isGoedkeuring('goedgekeurd', 'goedgekeurd'), false);
  assert.equal(hulp.isGoedkeuring('in_behandeling', 'afgewezen'), false);
  assert.equal(hulp.isGoedkeuring('goedgekeurd', 'in_behandeling'), false);
  assert.equal(hulp.isGoedkeuring(undefined, undefined), false);
});

test('ID-AFKEUR isAfkeuring: alleen de overgang naar afgewezen', () => {
  assert.equal(hulp.isAfkeuring('in_behandeling', 'afgewezen'), true);
  assert.equal(hulp.isAfkeuring('', 'afgewezen'), true);
  assert.equal(hulp.isAfkeuring('goedgekeurd', 'afgewezen'), true);
  assert.equal(hulp.isAfkeuring('afgewezen', 'afgewezen'), false);
  assert.equal(hulp.isAfkeuring('in_behandeling', 'goedgekeurd'), false);
  assert.equal(hulp.isAfkeuring('afgewezen', 'in_behandeling'), false);
  assert.equal(hulp.isAfkeuring(undefined, undefined), false);
});
