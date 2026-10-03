// HeitjeHulp B4 — test van 100-b4-velden.mjs en 101-b4-rules.mjs zonder server.
// Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { B4_ANKER, B4_HELPER_VOORWAARDE, KEUR_SLOT, SERVER_VELDEN, metB4Voorwaarde, B4_WIJZIGINGEN } from '../scripts/101-b4-rules.mjs';
import { B4_VELDNAMEN, klustypePlan, b4Velden, plaatsHulp } from '../scripts/100-b4-velden.mjs';
import { KLUS_VOORWAARDE } from '../scripts/80-b2-rules.mjs';

// hh_klussen.listRule zoals live op prod na B2 (3 okt 2026).
const LIVE =
  '@request.auth.id != "" && @request.auth.collectionName = "hh_users" && (hulpvrager = @request.auth.id || ' +
  'toegewezen_jongere = @request.auth.id || (@request.auth.rol = "jongere" && status = "open" && @request.auth.wijk != "" && ' +
  '(hulpvrager.wijk = @request.auth.wijk || (hulpvrager.wijk.gemeente = @request.auth.wijk.gemeente && ' +
  '(hulpvrager.wijk.regio = true || @request.auth.wijk.regio = true))) && @collection.hh_profielen.gebruiker ?= @request.auth.id && ' +
  '@collection.hh_profielen.verificatiestatus ?= "goedgekeurd" && (@request.auth.ouder_toestemming_op != "" || ' +
  '@collection.hh_profielen.vog_gezien_op ?!= "")) || (@request.auth.rol = "familie" && @collection.hh_koppelingen.oudere ?= hulpvrager && ' +
  '@collection.hh_koppelingen.familielid ?= @request.auth.id && @collection.hh_koppelingen.status ?= "actief" && ' +
  '@collection.hh_koppelingen.rechten ?~ "meekijken") || @request.auth.rol = "coordinator")';

test('het anker is de B2-voorwaarde', () => {
  assert.equal(B4_ANKER, KLUS_VOORWAARDE);
});

test('B4-voorwaarde komt precies in de helper-tak, de rest blijft letterlijk', () => {
  const nieuw = metB4Voorwaarde(LIVE);
  assert.equal(nieuw, LIVE.replace(B4_ANKER, `${B4_ANKER} && ${B4_HELPER_VOORWAARDE}`));
  assert.ok(nieuw.startsWith('@request.auth.id != "" && @request.auth.collectionName = "hh_users" && (hulpvrager = @request.auth.id || toegewezen_jongere = @request.auth.id || ('));
  assert.ok(nieuw.includes('@request.auth.rol = "familie"'), 'familie-tak ongemoeid');
  // Binnen de helper-tak: tussen "jongere" en de afsluitende ")) ||".
  const tak = nieuw.slice(nieuw.indexOf('@request.auth.rol = "jongere"'), nieuw.indexOf('|| (@request.auth.rol = "familie"'));
  assert.ok(tak.includes('klus_goedgekeurd_op != ""'));
  assert.ok(tak.includes('@request.auth.geboortedatum <= geboren_uiterlijk'));
});

test('B4-voorwaarde is idempotent en stopt bij een afwijkende rule', () => {
  const een = metB4Voorwaarde(LIVE);
  assert.equal(metB4Voorwaarde(een), een);
  assert.equal(metB4Voorwaarde(null), null);
  assert.throws(() => metB4Voorwaarde('@request.auth.id != ""'), /staat 0x/);
  assert.throws(() => metB4Voorwaarde(`${B4_ANKER} || ${B4_ANKER}`), /staat 2x/);
});

test('de helper-voorwaarde eist goedkeuring, een grens en een geboortedatum', () => {
  assert.match(B4_HELPER_VOORWAARDE, /klus_goedgekeurd_op != ""/);
  assert.match(B4_HELPER_VOORWAARDE, /geboren_uiterlijk != ""/);
  // Zonder deze stap is "" <= "2013-..." waar: lege geboortedatum zou alles zien.
  assert.match(B4_HELPER_VOORWAARDE, /@request\.auth\.geboortedatum != ""/);
});

test('keur-slot: coordinator vrij, iedereen anders stuurt de servervelden niet mee', () => {
  assert.ok(KEUR_SLOT.startsWith('((@request.auth.collectionName = "hh_users" && @request.auth.rol = "coordinator") || ('));
  for (const v of SERVER_VELDEN) assert.ok(KEUR_SLOT.includes(`@request.body.${v}:isset = false`), v);
  // Elk serverveld bestaat in 100.
  for (const v of SERVER_VELDEN) assert.ok(B4_VELDNAMEN.hh_klussen.includes(v), v);
  // foto en nee_lijst_akkoord stuurt de bewoner WEL mee.
  assert.ok(!SERVER_VELDEN.includes('foto'));
  assert.ok(!SERVER_VELDEN.includes('nee_lijst_akkoord'));
});

test('wijzigingen: list/view gericht, create/update gewikkeld', () => {
  const regels = Object.fromEntries(B4_WIJZIGINGEN.map((w) => [w.rule, w.nieuw]));
  assert.equal(regels.listRule(LIVE), metB4Voorwaarde(LIVE));
  const create = '@request.auth.id != ""';
  assert.equal(regels.createRule(create), `(${create}) && ${KEUR_SLOT}`);
  assert.equal(regels.updateRule(regels.updateRule(create)), `(${create}) && ${KEUR_SLOT}`);
  assert.ok(B4_WIJZIGINGEN.every((w) => w.collectie === 'hh_klussen'));
});

test('velden: foto is protected, afbeeldingen, max 5 MB; relatie zonder cascade', () => {
  const v = b4Velden({ hh_users: 'users-id' });
  const foto = v.hh_klussen.find((f) => f.name === 'foto');
  assert.equal(foto.protected, true);
  assert.equal(foto.maxSize, 5 * 1024 * 1024);
  assert.deepEqual(foto.mimeTypes, ['image/jpeg', 'image/png', 'image/heic', 'image/heif']);
  const door = v.hh_klussen.find((f) => f.name === 'klus_goedgekeurd_door');
  assert.equal(door.collectionId, 'users-id');
  assert.equal(door.cascadeDelete, false);
  assert.deepEqual(B4_VELDNAMEN.hh_klustypes, ['min_leeftijd', 'actief', 'volgorde']);
});

test('klustypePlan: 13 nieuw naast de 6 oude, oude alleen een min_leeftijd', () => {
  const oud = Object.keys(plaatsHulp.OUDE_KLUSTYPES_MIN_LEEFTIJD).map((naam, i) => ({ id: `o${i}`, naam }));
  const plan = klustypePlan(oud);
  assert.equal(plan.maak.length, 13);
  assert.ok(plan.maak.every((c) => c.actief === true && c.min_leeftijd >= 10 && c.volgorde >= 1));
  assert.equal(plan.zet.length, 6);
  assert.deepEqual(plan.zet.find((z) => z.naam === 'klusje in huis'), { id: 'o2', naam: 'klusje in huis', min_leeftijd: 16 });
  assert.deepEqual(plan.onbekend, []);
});

test('klustypePlan: tweede keer niets; onbekend type wordt gemeld, niet aangepast', () => {
  const al = [
    ...plaatsHulp.KLUS_CATEGORIEEN.map((c, i) => ({ id: `n${i}`, ...c, actief: true })),
    { id: 'o1', naam: 'tuin', min_leeftijd: 13 },
    { id: 'x', naam: 'ramen lappen' },
  ];
  const plan = klustypePlan(al);
  assert.deepEqual(plan.maak, []);
  assert.deepEqual(plan.zet, []);
  assert.deepEqual(plan.onbekend, ['ramen lappen']);
});

test('104 seedPlan: alleen seed-klussen, alleen wat nog leeg of anders is', async () => {
  const { seedPlan } = await import('../scripts/104-b4-seed-keuren.mjs');
  const nu = new Date('2026-10-04T10:00:00.000Z');
  const seed = { omschrijving: 'Heg knippen [seed k02]', wanneer_van: '2026-10-06 12:00:00.000Z', wanneer_tot: '2026-10-06 13:30:00.000Z' };
  const plan = seedPlan(seed, 13, nu);
  assert.equal(plan.klus_goedgekeurd_op, nu.toISOString());
  assert.equal(plan.min_leeftijd, 13);
  assert.equal(plan.geboren_uiterlijk, '2013-10-06 23:59:59.999Z');
  assert.deepEqual(seedPlan({ ...seed, ...plan }, 13, nu), {}, 'tweede keer niets');
  assert.deepEqual(seedPlan({ omschrijving: 'echte klus' }, 13, nu), {}, 'geen seed: niets');
});
