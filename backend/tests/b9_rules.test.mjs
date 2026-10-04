// HeitjeHulp B9 — test van de velden (140) en de rules (141) zonder server.
// Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  XP_SOORTEN,
  BADGE_CODES,
  NIVEAU_CODES,
  NIEUWE_COLLECTIES,
  MELDING_SOORT_BELONING,
  xpVelden,
  badgeVelden,
  verklaringVelden,
  extraVelden,
} from '../scripts/140-b9-xp.mjs';
import { NIEUWE_RULES, LEZEN, PROFIEL_SLOT, BEOORDELING_SLOT, metSlot } from '../scripts/141-b9-rules.mjs';
import { laadHulp } from './_nep_app.mjs';

const regels = laadHulp('hh_xp_regels.js');
const hulp = laadHulp('hh_xp_hulp.js');
const IDS = { hh_users: 'u', hh_klussen: 'k', hh_beoordelingen: 'b' };
const opNaam = (lijst) => Object.fromEntries(lijst.map((f) => [f.name, f]));

test('script en hook kennen dezelfde badges, niveaus en XP-soorten', () => {
  assert.deepEqual(BADGE_CODES, regels.BADGES.map((b) => b.code));
  assert.deepEqual(NIVEAU_CODES, regels.NIVEAUS.map((n) => n.code));
  const soorten = new Set(Object.values(regels.gewensteXp(
    [{ id: 'k1', hulpvrager: 'b1', wanneer_van: '2026-10-01 08:00:00.000Z' }, { id: 'k2', hulpvrager: 'b1', wanneer_van: '2026-10-02 08:00:00.000Z' }],
    [{ id: 'o', klus: 'k1', sterren: 5 }]
  )).map((b) => b.soort));
  soorten.add('tegenboeking');
  assert.deepEqual([...soorten].sort(), [...XP_SOORTEN].sort());
  assert.equal(MELDING_SOORT_BELONING, 'beloning');
  assert.equal(hulp.CODE_LENGTE, 10);
});

test('hh_xp: helper cascade, klus/beoordeling zonder cascade, punten niet verplicht (0 mag), uniek per helper', () => {
  const v = opNaam(xpVelden(IDS));
  assert.equal(v.helper.required, true);
  assert.equal(v.helper.cascadeDelete, true, 'account weg = XP weg (AVG)');
  assert.equal(v.klus.required, false);
  assert.equal(v.klus.cascadeDelete, false, 'klus weg = punten blijven');
  assert.equal(v.beoordeling.cascadeDelete, false);
  assert.equal(v.punten.required, false, 'PocketBase weigert 0 bij verplicht');
  assert.equal(v.punten.onlyInt, true);
  assert.deepEqual(v.soort.values, XP_SOORTEN);
  const def = NIEUWE_COLLECTIES.find((c) => c.naam === 'hh_xp');
  assert.ok(def.indexen.some((i) => /UNIQUE INDEX .* \(helper, sleutel\)/.test(i)));
});

test('hh_badges uniek (helper, code); hh_verklaringen code uniek met vast patroon', () => {
  const b = opNaam(badgeVelden(IDS));
  assert.deepEqual(b.code.values, BADGE_CODES);
  assert.equal(b.helper.cascadeDelete, true);
  assert.ok(NIEUWE_COLLECTIES.find((c) => c.naam === 'hh_badges').indexen.some((i) => /UNIQUE .*\(helper, code\)/.test(i)));
  const v = opNaam(verklaringVelden(IDS));
  assert.equal(v.code.pattern, '^[A-Z2-9]{5}-[A-Z2-9]{5}$');
  assert.match('ABCDE-FGH23', new RegExp(v.code.pattern));
  assert.equal(hulp.codeOpmaak('abcde fgh23'), 'ABCDE-FGH23');
  assert.ok(NIEUWE_COLLECTIES.find((c) => c.naam === 'hh_verklaringen').indexen.some((i) => /UNIQUE .*\(code\)/.test(i)));
});

test('extra velden: niveau-keuzes, verborgen_door zonder cascade', () => {
  const e = extraVelden(IDS);
  const p = opNaam(e.hh_profielen);
  assert.deepEqual(p.niveau.values, NIVEAU_CODES);
  assert.equal(p.xp_totaal.type, 'number');
  assert.equal(p.idin_geverifieerd_op.type, 'date');
  const b = opNaam(e.hh_beoordelingen);
  assert.equal(b.verborgen_door.cascadeDelete, false);
  assert.equal(b.verborgen_reden.max, 300);
});

test('rules nieuwe collecties: alleen helper zelf of coordinator lezen, niemand schrijft via de API', () => {
  assert.equal(NIEUWE_RULES.listRule, LEZEN);
  assert.equal(NIEUWE_RULES.viewRule, LEZEN);
  assert.ok(LEZEN.includes('helper = @request.auth.id'));
  assert.ok(LEZEN.includes('@request.auth.rol = "coordinator"'));
  assert.ok(LEZEN.includes('@request.auth.collectionName = "hh_users"'));
  for (const k of ['createRule', 'updateRule', 'deleteRule']) assert.equal(NIEUWE_RULES[k], null, k);
});

test('sloten: wikkelen, tweede keer gelijk, null blijft null, leeg geweigerd', () => {
  const oud = 'gebruiker = @request.auth.id';
  const nieuw = metSlot(oud, PROFIEL_SLOT);
  assert.equal(nieuw, `(${oud}) && ${PROFIEL_SLOT}`);
  assert.equal(metSlot(nieuw, PROFIEL_SLOT), nieuw);
  assert.equal(metSlot(null, PROFIEL_SLOT), null);
  assert.throws(() => metSlot('', PROFIEL_SLOT));
  for (const veld of ['xp_totaal', 'niveau', 'idin_geverifieerd_op']) assert.ok(PROFIEL_SLOT.includes(`@request.body.${veld}:isset = false`));
  for (const veld of ['verborgen_op', 'verborgen_door', 'verborgen_reden']) assert.ok(BEOORDELING_SLOT.includes(`@request.body.${veld}:isset = false`));
});
