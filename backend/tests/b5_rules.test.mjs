// HeitjeHulp B5 — test van de velden (130) en de rules (131) zonder server.
// Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  COLLECTIE,
  REACTIE_STATUSSEN,
  reactieVelden,
  REACTIE_INDEXEN,
  MELDING_SOORT_REACTIE,
  metSoortReactie,
  EXTRA_VELDEN,
} from '../scripts/130-b5-reacties.mjs';
import { REACTIE_RULES, LEZEN } from '../scripts/131-b5-rules.mjs';
import { laadHulp } from './_nep_app.mjs';

const hulp = laadHulp('hh_reacties_hulp.js');
const IDS = { hh_users: 'u', hh_klussen: 'k' };

test('hh_reacties: klus en helper (cascade), bericht max 200, de 6 statussen, ouder-velden, token hidden', () => {
  assert.equal(COLLECTIE, 'hh_reacties');
  const v = Object.fromEntries(reactieVelden(IDS).map((f) => [f.name, f]));
  assert.equal(v.klus.collectionId, 'k');
  assert.equal(v.klus.required, true);
  assert.equal(v.klus.cascadeDelete, true);
  assert.equal(v.helper.collectionId, 'u');
  assert.equal(v.helper.required, true);
  assert.equal(v.helper.cascadeDelete, true, 'account weg = reacties weg');
  assert.equal(v.bericht.max, 200);
  assert.equal(v.bericht.required, false, 'berichtje is optioneel');
  assert.deepEqual(v.status.values, ['wacht_op_ouder', 'open', 'gekozen', 'afgewezen', 'ingetrokken', 'vervallen']);
  assert.deepEqual(REACTIE_STATUSSEN, hulp.STATUSSEN, 'script en hook kennen dezelfde statussen');
  assert.equal(v.status.required, true);
  assert.equal(v.ouder_akkoord_op.type, 'date');
  assert.deepEqual(v.ouder_besluit.values, ['goed', 'liever_niet']);
  assert.equal(v.ouder_gaat_mee.type, 'bool');
  assert.equal(v.token_hash.hidden, true, 'de hash leest niemand via de API');
  assert.equal(v.created.type, 'autodate');
  assert.ok(REACTIE_INDEXEN.some((i) => /UNIQUE INDEX .* \(klus, helper\)/.test(i)), 'één reactie per helper per klus');
  assert.ok(REACTIE_INDEXEN.some((i) => i.includes('(token_hash)')));
});

test('extra velden: beschikbaar_tot (profiel), geheime vraag (beoordeling); soort "reactie" bij de meldingen', () => {
  const p = EXTRA_VELDEN.hh_profielen.map((f) => f.name);
  assert.deepEqual(p, ['beschikbaar_tot']);
  const b = Object.fromEntries(EXTRA_VELDEN.hh_beoordelingen.map((f) => [f.name, f]));
  assert.deepEqual(b.alles_in_orde.values, ['ja', 'nee']);
  assert.equal(b.geheim_toelichting.max, 300);
  assert.deepEqual(Object.keys(b), hulp.GEHEIME_VELDEN);
  assert.equal(MELDING_SOORT_REACTIE, hulp.MELDING_SOORT);
  const live = ['nieuwe_klus', 'toegewezen', 'onderweg', 'afgerond', 'geannuleerd', 'incident', 'bericht'];
  assert.deepEqual(metSoortReactie(live), [...live, 'reactie']);
  assert.deepEqual(metSoortReactie(metSoortReactie(live)), [...live, 'reactie'], 'idempotent');
});

test('rules hh_reacties: lezen = eigen helper, bewoner (alleen open/gekozen), coordinator; schrijven niemand', () => {
  const r = REACTIE_RULES;
  assert.equal(r.listRule, r.viewRule);
  assert.equal(r.listRule, LEZEN);
  assert.ok(LEZEN.startsWith('@request.auth.id != "" && @request.auth.collectionName = "hh_users"'));
  assert.ok(LEZEN.includes('helper = @request.auth.id'));
  assert.ok(LEZEN.includes('(klus.hulpvrager = @request.auth.id && (status = "open" || status = "gekozen"))'));
  assert.ok(!LEZEN.includes('wacht_op_ouder'), 'wat op de ouder wacht, ziet de bewoner niet');
  assert.ok(LEZEN.includes('@request.auth.rol = "coordinator"'));
  assert.ok(!LEZEN.includes('familie'));
  assert.equal(r.createRule, null, 'alleen via de routes');
  assert.equal(r.updateRule, null);
  assert.equal(r.deleteRule, null);
});
