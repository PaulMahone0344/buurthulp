// HeitjeHulp B3 — test van scripts 90 en 91 zonder server.
// Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { toestemmingVelden, B3_RULES, GEHEIM, STATUSSEN, INDEXEN, COLLECTIE } from '../scripts/90-b3-collectie.mjs';
import { teWijzigen, WIJKEN } from '../scripts/91-b3-wijken.mjs';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const hier = path.dirname(fileURLToPath(import.meta.url));

test('90: alleen de coordinator leest, niemand schrijft via de API', () => {
  assert.match(B3_RULES.listRule, /@request\.auth\.rol = "coordinator"/);
  assert.match(B3_RULES.listRule, /@request\.auth\.collectionName = "hh_users"/);
  assert.equal(B3_RULES.viewRule, B3_RULES.listRule);
  assert.equal(B3_RULES.createRule, null);
  assert.equal(B3_RULES.updateRule, null);
  assert.equal(B3_RULES.deleteRule, null);
});

test('90: hash-velden zijn hidden, er is geen veld voor de code zelf', () => {
  const velden = toestemmingVelden({ hh_users: 'pbc_users' });
  const namen = velden.map((f) => f.name);
  for (const g of GEHEIM) assert.equal(velden.find((f) => f.name === g).hidden, true, g);
  assert.ok(!namen.includes('code'));
  assert.ok(!namen.includes('token'));
  for (const n of ['helper', 'ouder_email', 'code_hash', 'code_verloopt_op', 'pogingen', 'token_hash', 'status', 'ouder_naam', 'iban', 'avp_verklaard', 'gegeven_op', 'ingetrokken_op']) {
    assert.ok(namen.includes(n), n);
  }
  assert.deepEqual(STATUSSEN, ['verstuurd', 'gegeven', 'ingetrokken', 'verlopen']);
  const helper = velden.find((f) => f.name === 'helper');
  assert.equal(helper.collectionId, 'pbc_users');
  assert.equal(helper.cascadeDelete, true);
});

test('90: één rij per helper (unieke index)', () => {
  assert.ok(INDEXEN.some((i) => /CREATE UNIQUE INDEX .* ON hh_ouder_toestemming \(helper\)/.test(i)));
  assert.equal(COLLECTIE, 'hh_ouder_toestemming');
});

test('90: de velden die de hook schrijft bestaan allemaal', () => {
  const hook = readFileSync(path.join(hier, '..', 'pb_hooks', 'hh_ouder_hulp.js'), 'utf8');
  const namen = new Set(toestemmingVelden({ hh_users: 'x' }).map((f) => f.name));
  const geschreven = [...hook.matchAll(/rij[A-Za-z]?\.set\("(\w+)"/g)].map((m) => m[1]);
  assert.ok(geschreven.length > 10);
  for (const n of geschreven) assert.ok(namen.has(n), `hook schrijft onbekend veld ${n}`);
});

test('91: zet alleen Tiel-West en Passewaaij op regio, idempotent', () => {
  const rijen = [
    { id: 'w1', gemeente: 'Tiel', wijk: 'Tiel-West', regio: false },
    { id: 'w2', gemeente: 'Tiel', wijk: 'Passewaaij' },
    { id: 'w3', gemeente: 'Tiel', wijk: 'Tiel en omstreken', regio: true },
  ];
  const { ontbreekt, wijzig } = teWijzigen(rijen);
  assert.deepEqual(ontbreekt, []);
  assert.deepEqual(wijzig.map((r) => r.id), ['w1', 'w2']);
  const klaar = rijen.map((r) => ({ ...r, regio: true }));
  assert.deepEqual(teWijzigen(klaar).wijzig, []);
  assert.deepEqual(teWijzigen(klaar, false).wijzig.map((r) => r.id), ['w1', 'w2']);
  assert.deepEqual(WIJKEN, ['Tiel-West', 'Passewaaij']);
});

test('91: ontbreekt een wijk, dan meldt hij dat', () => {
  const { ontbreekt } = teWijzigen([{ id: 'w1', gemeente: 'Tiel', wijk: 'Tiel-West' }, { id: 'x', gemeente: 'Elders', wijk: 'Passewaaij' }]);
  assert.deepEqual(ontbreekt, ['Passewaaij']);
});

test('94: toont nooit het SMTP-wachtwoord', async () => {
  const { mailStand } = await import('../scripts/94-b3-mailcheck.mjs');
  const s = mailStand({
    smtp: { enabled: true, host: 'smtp.transip.email', port: 587, username: 'info@bovexa.nl', password: 'GEHEIM' },
    meta: { senderAddress: 'info@bovexa.nl', senderName: 'QawayahBase', appURL: 'https://api.qawayahbase.com' },
  });
  assert.equal(s.smtpAan, true);
  assert.equal(s.afzenderNaam, 'QawayahBase');
  assert.ok(!JSON.stringify(s).includes('GEHEIM'));
  assert.equal(mailStand({}).smtpAan, false);
});

test('94: effectieve afzender zonder HH_MAIL_AFZENDER = globaal adres, naam HeitjeHulp', async () => {
  const { effectieveAfzender } = await import('../scripts/94-b3-mailcheck.mjs');
  const inst = { smtp: { enabled: true, username: 'info@bovexa.nl' }, meta: { senderAddress: 'info@bovexa.nl', senderName: 'QawayahBase' } };
  const a = effectieveAfzender(inst, '');
  assert.equal(a.adres, 'info@bovexa.nl');
  assert.equal(a.naam, 'HeitjeHulp');
  assert.equal(a.antwoordAan, '');
  assert.equal(a.waarschuwing, '');
});

test('94: HH_MAIL_AFZENDER op een ander domein dan de SMTP-gebruiker geeft een waarschuwing', async () => {
  const { effectieveAfzender } = await import('../scripts/94-b3-mailcheck.mjs');
  const inst = { smtp: { enabled: true, username: 'info@bovexa.nl' }, meta: { senderAddress: 'info@bovexa.nl' } };
  const a = effectieveAfzender(inst, 'info@heitjehulp.nl');
  assert.equal(a.adres, 'info@heitjehulp.nl');
  assert.equal(a.antwoordAan, 'info@heitjehulp.nl');
  assert.match(a.waarschuwing, /heitjehulp\.nl.*bovexa\.nl/);
  const zelfde = effectieveAfzender({ smtp: { username: 'info@heitjehulp.nl' }, meta: {} }, 'info@heitjehulp.nl');
  assert.equal(zelfde.waarschuwing, '');
});
