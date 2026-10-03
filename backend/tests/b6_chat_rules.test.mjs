// HeitjeHulp B6 — test van de velden (110) en de rules (111) van hh_berichten
// zonder server. Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  BERICHT_SOORTEN,
  berichtVelden,
  BERICHT_INDEXEN,
  MELDING_SOORT_BERICHT,
  metSoortBericht,
} from '../scripts/110-b6-berichten.mjs';
import { BERICHTEN_RULES, STATUS_SCHRIJVEN, LEZEN, COORDINATOR_INZAGE } from '../scripts/111-b6-rules.mjs';

const IDS = { hh_users: 'u', hh_klussen: 'k' };

test('velden: klus (cascade), afzender, helper, tekst max 500, soort, gelezen_op, markeringen', () => {
  const velden = Object.fromEntries(berichtVelden(IDS).map((v) => [v.name, v]));
  assert.equal(velden.klus.collectionId, 'k');
  assert.equal(velden.klus.cascadeDelete, true, 'verdwijnt mee met de klus');
  assert.equal(velden.klus.required, true);
  assert.equal(velden.afzender.collectionId, 'u');
  assert.equal(velden.afzender.required, false, 'integratie: berichten blokkeren accountverwijdering niet');
  assert.equal(velden.afzender.cascadeDelete, false);
  assert.equal(velden.helper.collectionId, 'u');
  assert.equal(velden.tekst.max, 500);
  assert.equal(velden.tekst.required, false, 'integratie: een gewist bericht heeft een lege tekst');
  assert.deepEqual(velden.soort.values, ['tekst', 'snel']);
  assert.deepEqual(BERICHT_SOORTEN, ['tekst', 'snel']);
  assert.equal(velden.gelezen_op.type, 'date');
  assert.equal(velden.gefilterd.type, 'bool');
  assert.equal(velden.contactverzoek.type, 'bool');
  assert.equal(velden.created.type, 'autodate');
  assert.ok(BERICHT_INDEXEN.some((i) => i.includes('(klus, created)')));
});

test('hh_meldingen.soort krijgt "bericht" erbij; de bestaande waarden blijven letterlijk', () => {
  const live = ['nieuwe_klus', 'toegewezen', 'onderweg', 'afgerond', 'geannuleerd', 'incident'];
  const uit = metSoortBericht(live);
  assert.deepEqual(uit, [...live, MELDING_SOORT_BERICHT]);
  assert.equal(MELDING_SOORT_BERICHT, 'bericht');
  // Idempotent en zonder iets te verwijderen (ook als een ander er al iets bij zette).
  assert.deepEqual(metSoortBericht(uit), uit);
  assert.deepEqual(metSoortBericht([...live, 'goedkeuring']), [...live, 'goedkeuring', 'bericht']);
});

test('lezen: bewoner, de HUIDIGE helper van deze chat, coordinator alleen bij een incident', () => {
  const r = BERICHTEN_RULES.listRule;
  assert.equal(r, BERICHTEN_RULES.viewRule);
  assert.ok(r.startsWith('@request.auth.id != "" && @request.auth.collectionName = "hh_users"'));
  assert.ok(r.includes('klus.hulpvrager = @request.auth.id'));
  // Integratie: met 'verborgen_helper = false' erbij (zie de AVG-test).
  assert.ok(r.includes('(helper = @request.auth.id && klus.toegewezen_jongere = @request.auth.id'));
  assert.ok(r.includes(COORDINATOR_INZAGE));
  assert.ok(COORDINATOR_INZAGE.includes('@collection.hh_incidenten.klus ?= klus'));
  assert.ok(COORDINATOR_INZAGE.includes('@request.auth.rol = "coordinator"'));
  // Geen familie-tak (ouder leest niet mee).
  assert.ok(!r.includes('familie'));
  assert.ok(!r.includes('hh_koppelingen'));
  assert.ok(LEZEN.length > 0);
});

test('schrijven: alleen de twee partijen, als zichzelf, alleen bij een klus met helper', () => {
  const r = BERICHTEN_RULES.createRule;
  assert.ok(r.includes('@request.body.afzender = @request.auth.id'));
  assert.ok(r.includes('(klus.hulpvrager = @request.auth.id || klus.toegewezen_jongere = @request.auth.id)'));
  assert.ok(r.includes('klus.toegewezen_jongere != ""'));
  for (const s of STATUS_SCHRIJVEN) assert.ok(r.includes(`klus.status = "${s}"`), s);
  assert.deepEqual(STATUS_SCHRIJVEN, ['geaccepteerd', 'onderweg', 'bezig', 'probleem', 'afgerond', 'geannuleerd']);
  for (const v of ['helper', 'gelezen_op', 'gefilterd', 'contactverzoek']) {
    assert.ok(r.includes(`@request.body.${v}:isset = false`), v);
  }
  // De coordinator schrijft niet in de chat.
  assert.ok(!r.includes('coordinator'));
});

test('bijwerken: alleen de ontvanger, alleen gelezen_op', () => {
  const r = BERICHTEN_RULES.updateRule;
  assert.ok(r.includes('afzender != @request.auth.id'));
  for (const v of ['klus', 'afzender', 'helper', 'tekst', 'soort', 'gefilterd', 'contactverzoek']) {
    assert.ok(r.includes(`@request.body.${v}:isset = false`), v);
  }
  assert.ok(!r.includes('@request.body.gelezen_op:isset'));
  assert.ok(!r.includes('coordinator'));
});

test('verwijderen: niemand via de API (verdwijnt mee met de klus)', () => {
  assert.equal(BERICHTEN_RULES.deleteRule, null);
});

test('geen enkele rule is leeg ("" = publiek)', () => {
  for (const [k, v] of Object.entries(BERICHTEN_RULES)) assert.notEqual(v, '', k);
});

// ---- Integratie (antwoorden Ibrahim 4 okt): gesprek verwijderen + AVG ----------

test('AVG-velden: verborgen per kant, gewist, wissen_na_incident; afzender en tekst niet verplicht', () => {
  const velden = Object.fromEntries(berichtVelden(IDS).map((v) => [v.name, v]));
  for (const v of ['verborgen_bewoner', 'verborgen_helper', 'gewist', 'wissen_na_incident']) {
    assert.equal(velden[v]?.type, 'bool', v);
  }
  // Berichten blokkeren het verwijderen van een account niet meer: PocketBase
  // maakt een niet-verplichte relatie leeg; de hook wist de tekst.
  assert.equal(velden.afzender.required, false);
  assert.equal(velden.afzender.cascadeDelete, false);
  // Een gewist bericht heeft een lege tekst; een NIEUW bericht moet tekst hebben (hook).
  assert.equal(velden.tekst.required, false);
});

test('lezen: wie het gesprek verborg ziet het niet meer, de ander wel; de meldkamer bij een incident altijd', () => {
  const r = BERICHTEN_RULES.listRule;
  assert.ok(r.includes('(klus.hulpvrager = @request.auth.id && verborgen_bewoner = false)'));
  assert.ok(r.includes('(helper = @request.auth.id && klus.toegewezen_jongere = @request.auth.id && verborgen_helper = false)'));
  assert.ok(r.includes(COORDINATOR_INZAGE));
  assert.ok(!COORDINATOR_INZAGE.includes('verborgen'));
});

test('de AVG-velden zet nooit een gebruiker (aanmaken en bijwerken)', () => {
  for (const k of ['createRule', 'updateRule']) {
    for (const v of ['verborgen_bewoner', 'verborgen_helper', 'gewist', 'wissen_na_incident']) {
      assert.ok(BERICHTEN_RULES[k].includes(`@request.body.${v}:isset = false`), `${k} ${v}`);
    }
  }
});
