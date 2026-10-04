// HeitjeHulp B9 — hh_xp_regels.js zonder server: XP per bron, tegenboeking,
// niveaus, badges, vertrouwensbadges met datum, verdiensten per maand/jaar.
// Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { laadHulp } from './_nep_app.mjs';

const r = laadHulp('hh_xp_regels.js');

const klus = (id, bewoner, van, extra = {}) => ({ id, hulpvrager: bewoner, wanneer_van: van, ...extra });

test('XP: eerste klus = klaar + eerste-bonus', () => {
  const g = r.gewensteXp([klus('k1', 'b1', '2026-10-01 08:00:00.000Z')], []);
  assert.deepEqual(Object.keys(g).sort(), ['eerste', 'klaar:k1']);
  assert.equal(g['klaar:k1'].punten, 50);
  assert.equal(g.eerste.punten, 25);
  assert.equal(g.eerste.klus, 'k1');
});

test('XP: herboeking bij dezelfde bewoner geeft de meeste XP', () => {
  const g = r.gewensteXp(
    [
      klus('k2', 'b1', '2026-10-08 08:00:00.000Z'),
      klus('k1', 'b1', '2026-10-01 08:00:00.000Z'),
      klus('k3', 'b2', '2026-10-09 08:00:00.000Z'),
    ],
    []
  );
  assert.equal(g['herboeking:k2'].punten, 75);
  assert.equal(g['herboeking:k1'], undefined, 'de eerste klus bij een bewoner is geen herboeking');
  assert.equal(g['herboeking:k3'], undefined, 'andere bewoner');
  assert.equal(g.eerste.klus, 'k1', 'eerste = vroegste, niet de eerste in de lijst');
  const perKlus = (id) => Object.values(g).filter((b) => b.klus === id && b.soort !== 'eerste_klus').reduce((s, b) => s + b.punten, 0);
  assert.ok(perKlus('k2') > perKlus('k3'), 'herboekte klus levert meer dan een gewone');
  assert.ok(r.XP.herboeking > r.XP.klus_klaar && r.XP.herboeking > r.XP.beoordeling[5]);
});

test('XP: beoordeling 5 = 30, 4 = 15, 3 of minder = 0, verborgen = 0', () => {
  const g = r.gewensteXp([], [
    { id: 'b5', klus: 'k1', sterren: 5 },
    { id: 'b4', klus: 'k1', sterren: 4 },
    { id: 'b3', klus: 'k1', sterren: 3 },
    { id: 'bv', klus: 'k1', sterren: 5, verborgen_op: '2026-10-04 10:00:00.000Z' },
  ]);
  assert.equal(g['beoordeling:b5'].punten, 30);
  assert.equal(g['beoordeling:b4'].punten, 15);
  assert.equal(g['beoordeling:b3'], undefined);
  assert.equal(g['beoordeling:bv'], undefined);
});

test('teBoeken: alleen het verschil, terug = tegenboeking, niets dubbel', () => {
  const gewenst = r.gewensteXp([klus('k1', 'b1', '2026-10-01 08:00:00.000Z')], [{ id: 'x', klus: 'k1', sterren: 5 }]);
  const eerst = r.teBoeken({}, gewenst);
  assert.equal(eerst.reduce((s, b) => s + b.punten, 0), 105);
  assert.ok(eerst.every((b) => b.punten > 0));
  const huidig = {};
  for (const b of eerst) huidig[b.bron] = (huidig[b.bron] || 0) + b.punten;
  assert.deepEqual(r.teBoeken(huidig, gewenst), [], 'tweede keer: niets te doen');

  // Beoordeling verborgen -> 30 terug als tegenboeking.
  const zonder = r.gewensteXp([klus('k1', 'b1', '2026-10-01 08:00:00.000Z')], [{ id: 'x', klus: 'k1', sterren: 5, verborgen_op: 'nu' }]);
  const terug = r.teBoeken(huidig, zonder);
  assert.deepEqual(terug.map((b) => [b.bron, b.soort, b.punten]), [['beoordeling:x', 'tegenboeking', -30]]);

  // Klus niet meer afgerond -> alles terug.
  const leeg = r.teBoeken(huidig, {});
  assert.equal(leeg.reduce((s, b) => s + b.punten, 0), -105);
  assert.ok(leeg.every((b) => b.soort === 'tegenboeking'));
});

test('teBoeken: 4 sterren wordt 5 sterren -> +15 als beoordeling', () => {
  const vier = r.gewensteXp([], [{ id: 'x', klus: 'k1', sterren: 4 }]);
  const vijf = r.gewensteXp([], [{ id: 'x', klus: 'k1', sterren: 5 }]);
  const bij = r.teBoeken({ 'beoordeling:x': vier['beoordeling:x'].punten }, vijf);
  assert.deepEqual(bij.map((b) => [b.soort, b.punten]), [['beoordeling', 15]]);
});

test('niveaus: drempels op XP, klussen en sterren; geverifieerd alleen met iDIN', () => {
  assert.equal(r.niveauVoor({ xp: 0, klussen: 0, sterren: 0 }), 'nieuw');
  assert.equal(r.niveauVoor({ xp: 299, klussen: 9, sterren: 5 }), 'nieuw');
  assert.equal(r.niveauVoor({ xp: 300, klussen: 4, sterren: 5 }), 'nieuw', '5 klussen nodig');
  assert.equal(r.niveauVoor({ xp: 300, klussen: 5, sterren: 0 }), 'ervaren');
  assert.equal(r.niveauVoor({ xp: 2000, klussen: 30, sterren: 4.4 }), 'ervaren', 'top vraagt 4,5 sterren');
  assert.equal(r.niveauVoor({ xp: 1000, klussen: 15, sterren: 4.5 }), 'top');
  assert.equal(r.niveauVoor({ xp: 1000, klussen: 15, sterren: 4.5, idin: '2026-10-01' }), 'geverifieerd');
  assert.equal(r.niveauVoor({ xp: 10, klussen: 1, sterren: 5, idin: '2026-10-01' }), 'nieuw', 'iDIN alleen is niet genoeg');
  assert.equal(r.niveauNaam('top'), 'Top');
});

test('volgend niveau: wat nog nodig is + grenzen voor de balk', () => {
  const v = r.volgendNiveau({ xp: 120, klussen: 2, sterren: 5 });
  assert.deepEqual(v, { code: 'ervaren', naam: 'Ervaren', xp_nodig: 180, klussen_nodig: 3, sterren_nodig: 0, xp_vanaf: 0, xp_tot: 300 });
  const t = r.volgendNiveau({ xp: 500, klussen: 8, sterren: 4.2 });
  assert.equal(t.code, 'top');
  assert.equal(t.sterren_nodig, 4.5);
  assert.equal(t.xp_vanaf, 300);
  assert.equal(r.volgendNiveau({ xp: 1500, klussen: 20, sterren: 4.8 }), null, 'Top: geverifieerd kun je niet verdienen');
});

test('badges: eerste, 5, 10, 25 klussen op het moment van die klus', () => {
  const klussen = [];
  for (let i = 1; i <= 25; i++) {
    const dag = String(i).padStart(2, '0');
    klussen.push(klus(`k${i}`, `b${i}`, `2026-08-${dag} 08:00:00.000Z`));
  }
  const b = r.badgesVoor(klussen, []);
  const op = Object.fromEntries(b.map((x) => [x.code, x.behaald_op]));
  assert.equal(op.eerste_klus, '2026-08-01 08:00:00.000Z');
  assert.equal(op.vijf_klussen, '2026-08-05 08:00:00.000Z');
  assert.equal(op.tien_klussen, '2026-08-10 08:00:00.000Z');
  assert.equal(op.vijfentwintig_klussen, '2026-08-25 08:00:00.000Z');
  assert.equal(op.drie_buren, '2026-08-03 08:00:00.000Z');
  assert.equal(op.herboekt, undefined);
  assert.deepEqual(b.map((x) => x.code), ['eerste_klus', 'vijf_klussen', 'tien_klussen', 'vijfentwintig_klussen', 'drie_buren'], 'volgorde van BADGES');
});

test('badges: herboekt en drie buren tellen bewoners, niet klussen', () => {
  const b = r.badgesVoor(
    [klus('k1', 'b1', '2026-10-01 08:00:00.000Z'), klus('k2', 'b1', '2026-10-02 08:00:00.000Z'), klus('k3', 'b2', '2026-10-03 08:00:00.000Z')],
    []
  );
  const codes = b.map((x) => x.code);
  assert.ok(codes.includes('herboekt'));
  assert.ok(!codes.includes('drie_buren'), 'twee bewoners');
});

test('badges: 5 keer 5 sterren achter elkaar; een 4 breekt de reeks; verborgen telt niet', () => {
  const bo = (n, sterren, extra = {}) => ({ id: `b${n}`, sterren, created: `2026-10-0${n} 10:00:00.000Z`, ...extra });
  const zonder = r.badgesVoor([], [bo(1, 5), bo(2, 5), bo(3, 4), bo(4, 5), bo(5, 5), bo(6, 5), bo(7, 5)]);
  assert.ok(!zonder.some((x) => x.code === 'vijf_sterren_reeks'));
  const met = r.badgesVoor([], [bo(1, 5), bo(2, 5), bo(3, 5), bo(4, 5), bo(5, 5)]);
  assert.equal(met.find((x) => x.code === 'vijf_sterren_reeks').behaald_op, '2026-10-05 10:00:00.000Z');
  const verborgen = r.badgesVoor([], [bo(1, 5), bo(2, 5), bo(3, 5), bo(4, 5), bo(5, 5, { verborgen_op: 'x' })]);
  assert.ok(!verborgen.some((x) => x.code === 'vijf_sterren_reeks'));
});

test('vertrouwensbadges: datum, VOG verloopt na 3 jaar of op vog_geldig_tot', () => {
  const nu = Date.parse('2026-10-04T10:00:00Z');
  const v = r.vertrouwensBadges(
    { ouder_toestemming_op: '2026-09-01 10:00:00.000Z' },
    { vog_gezien_op: '2023-09-01 10:00:00.000Z', id_gecontroleerd_op: '2026-09-02 10:00:00.000Z' },
    nu
  );
  assert.deepEqual(v.map((x) => x.code), ['ouder_toestemming', 'vog', 'id_gecontroleerd']);
  const vog = v.find((x) => x.code === 'vog');
  assert.equal(vog.geldig_tot, '2026-09-01 10:00:00.000Z');
  assert.equal(vog.verlopen, true);
  assert.equal(v.find((x) => x.code === 'id_gecontroleerd').verlopen, false);

  const vast = r.vertrouwensBadges({}, { vog_gezien_op: '2026-01-01 10:00:00.000Z', vog_geldig_tot: '2027-01-01 00:00:00.000Z' }, nu);
  assert.deepEqual(vast.map((x) => [x.code, x.geldig_tot, x.verlopen]), [['vog', '2027-01-01 00:00:00.000Z', false]]);
  assert.deepEqual(r.vertrouwensBadges({}, {}, nu), []);
  assert.equal(r.vertrouwensBadges({}, { idin_geverifieerd_op: '2026-10-01 10:00:00.000Z' }, nu)[0].code, 'idin');
});

test('verdiensten: per maand en jaar in Nederlandse tijd, nieuwste eerst', () => {
  const v = r.verdiensten([
    // 31 okt 23:30 UTC = 1 nov 00:30 NL (wintertijd) -> november.
    klus('k1', 'b1', '2026-10-31 23:30:00.000Z', { vergoeding_jongere: 7.5 }),
    klus('k2', 'b1', '2026-10-10 08:00:00.000Z', { vergoeding_jongere: 10 }),
    klus('k3', 'b2', '2026-10-12 08:00:00.000Z', { bedrag_bruto: 5 }),
    klus('k4', 'b2', '2025-12-31 23:30:00.000Z', { vergoeding_jongere: 4 }),
    klus('k5', 'b2', '2026-10-13 08:00:00.000Z'),
  ]);
  assert.deepEqual(v.maanden, [
    { maand: '2026-11', bedrag: 7.5, klussen: 1 },
    { maand: '2026-10', bedrag: 15, klussen: 3 },
    { maand: '2026-01', bedrag: 4, klussen: 1 },
  ]);
  assert.deepEqual(v.jaren, [
    { jaar: '2026', bedrag: 26.5, klussen: 5 },
  ]);
  assert.equal(v.totaal, 26.5);
});

test('uren: alleen met begin en eind, op een kwartier', () => {
  assert.equal(r.klusUren({ wanneer_van: '2026-10-10 08:00:00.000Z', wanneer_tot: '2026-10-10 09:20:00.000Z' }), 1.25);
  assert.equal(r.klusUren({ wanneer_van: '2026-10-10 08:00:00.000Z' }), 0);
});
