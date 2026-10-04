// HeitjeHulp B9 — hh_xp_hulp.js zonder server: boeken (idempotent, tegen-
// boeking), niveau en badges op het profiel, beloning + melding, overzicht,
// KiesHelper-info, verklaring van inzet, recensie verbergen, naberekenen.
// De nep-app (tests/_nep_app.mjs) houdt records in het geheugen; de echte
// rules en PocketBase bewijst 142-b9check.mjs.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { laadHulp, nepApp, NepRecord } from './_nep_app.mjs';

const hulp = laadHulp('hh_xp_hulp.js');
const NU = Date.parse('2026-10-04T10:00:00Z');
const UNIEK = { hh_xp: [['helper', 'sleutel']], hh_badges: [['helper', 'code']], hh_verklaringen: [['code']], hh_meldingen: [['ontvanger', 'soort', 'sleutel']] };

function wereld(extra = {}) {
  const rijen = {
    hh_users: [
      { id: 'b1', rol: 'hulpvrager', naam: 'Anja de Vries' },
      { id: 'b2', rol: 'hulpvrager', naam: 'Kees Bakker' },
      { id: 'h1', rol: 'jongere', naam: 'Ruud Jansen', ouder_toestemming_op: '2026-09-01 10:00:00.000Z' },
      { id: 'h2', rol: 'jongere', naam: 'Sanne Smit' },
      { id: 'coord', rol: 'coordinator', naam: 'Meldkamer' },
    ],
    hh_profielen: [
      { id: 'p1', gebruiker: 'h1', sterren_gemiddeld: 5, vog_gezien_op: '2026-09-01 10:00:00.000Z' },
      { id: 'p2', gebruiker: 'h2', sterren_gemiddeld: 0 },
    ],
    hh_klussen: [
      { id: 'k1', hulpvrager: 'b1', toegewezen_jongere: 'h1', status: 'afgerond', wanneer_van: '2026-10-01 08:00:00.000Z', wanneer_tot: '2026-10-01 09:30:00.000Z', vergoeding_jongere: 10 },
      { id: 'k2', hulpvrager: 'b1', toegewezen_jongere: 'h1', status: 'afgerond', wanneer_van: '2026-10-02 08:00:00.000Z', vergoeding_jongere: 7.5 },
      { id: 'k3', hulpvrager: 'b2', toegewezen_jongere: 'h1', status: 'bezig', wanneer_van: '2026-10-03 08:00:00.000Z' },
      { id: 'k4', hulpvrager: 'b2', toegewezen_jongere: 'h2', status: 'open' },
    ],
    hh_beoordelingen: [
      { id: 'o1', klus: 'k1', van_gebruiker: 'b1', naar_gebruiker: 'h1', sterren: 5, tekst: 'Heel fijn geholpen!', created: '2026-10-01 12:00:00.000Z' },
      { id: 'o3', klus: 'k3', van_gebruiker: 'b2', naar_gebruiker: 'h1', sterren: 5, tekst: 'telt nog niet', created: '2026-10-03 12:00:00.000Z' },
    ],
    hh_xp: [],
    hh_badges: [],
    hh_verklaringen: [],
    hh_meldingen: [],
    ...extra,
  };
  const app = nepApp(rijen, { klok: () => NU, uniek: UNIEK });
  let teller = 0;
  const env = {
    app,
    Record: NepRecord,
    nu: () => NU,
    willekeurig: () => ['ABCDEFGHJK', 'ABCDEFGHJM', 'ABCDEFGHJN'][teller++],
  };
  return { app, env };
}

const som = (app, helper) => app.db.hh_xp.filter((r) => r.get('helper') === helper).reduce((s, r) => s + r.get('punten'), 0);

test('werkXpBij: boekt klaar, eerste, herboeking en 5 sterren; profiel krijgt totaal + niveau', () => {
  const { app, env } = wereld();
  const u = hulp.werkXpBij(env, 'h1');
  // k1: 50 + eerste 25 + beoordeling 30; k2: 50 + herboeking 75. k3 (bezig) telt niet.
  assert.equal(u.totaal, 230);
  assert.equal(u.xp_erbij, 230);
  assert.equal(som(app, 'h1'), 230);
  assert.deepEqual(app.db.hh_xp.map((r) => r.get('sleutel')).sort(), ['beoordeling:o1#1', 'eerste#1', 'herboeking:k2#1', 'klaar:k1#1', 'klaar:k2#1']);
  const p1 = app.db.hh_profielen.find((p) => p.id === 'p1');
  assert.equal(p1.get('xp_totaal'), 230);
  assert.equal(p1.get('niveau'), 'nieuw');
  assert.deepEqual(u.nieuwe_badges, ['eerste_klus', 'herboekt']);
  assert.equal(app.db.hh_badges.length, 2);
});

test('werkXpBij: tweede keer niets erbij (idempotent), ook geen dubbele badges', () => {
  const { app, env } = wereld();
  hulp.werkXpBij(env, 'h1');
  const twee = hulp.werkXpBij(env, 'h1');
  assert.equal(twee.xp_erbij, 0);
  assert.deepEqual(twee.boekingen, []);
  assert.deepEqual(twee.nieuwe_badges, []);
  assert.equal(app.db.hh_xp.length, 5);
  assert.equal(app.db.hh_badges.length, 2);
});

test('werkXpBij: klus terug van afgerond -> tegenboeking, niets gewist, badge blijft', () => {
  const { app, env } = wereld();
  hulp.werkXpBij(env, 'h1');
  app.db.hh_klussen.find((k) => k.id === 'k2').set('status', 'probleem');
  const u = hulp.werkXpBij(env, 'h1');
  assert.equal(u.totaal, 105);
  assert.deepEqual(u.boekingen.map((b) => [b.sleutel, b.soort, b.punten]).sort(), [
    ['herboeking:k2#2', 'tegenboeking', -75],
    ['klaar:k2#2', 'tegenboeking', -50],
  ]);
  assert.equal(app.db.hh_xp.length, 7, 'oude rijen blijven staan');
  assert.ok(app.db.hh_badges.some((b) => b.get('code') === 'herboekt'), 'behaald is behaald');
});

test('werkXpBij: geen jongere of onbekend -> null; zonder profiel wel boeken', () => {
  const { app, env } = wereld({ hh_profielen: [] });
  assert.equal(hulp.werkXpBij(env, 'b1'), null);
  assert.equal(hulp.werkXpBij(env, 'bestaatniet'), null);
  assert.equal(hulp.werkXpBij(env, 'h1').totaal, 230);
  assert.equal(app.db.hh_xp.length, 5);
});

test('werkXpBij droog: zegt wat er zou gebeuren, schrijft niets', () => {
  const { app, env } = wereld();
  const u = hulp.werkXpBij(env, 'h1', { droog: true });
  assert.equal(u.totaal, 230);
  assert.equal(u.boekingen.length, 5);
  assert.equal(app.db.hh_xp.length, 0);
  assert.equal(app.db.hh_badges.length, 0);
  assert.equal(app.db.hh_profielen.find((p) => p.id === 'p1').get('xp_totaal'), '');
});

test('werkXpBij: UNIQUE op sleutel (andere hook was eerder) -> overslaan, niet gooien', () => {
  const { app, env } = wereld({ hh_xp: [{ id: 'x0', helper: 'h1', bron: 'andere', punten: 0, sleutel: 'klaar:k1#1' }] });
  const u = hulp.werkXpBij(env, 'h1');
  assert.ok(!u.boekingen.some((b) => b.sleutel === 'klaar:k1#1'));
  assert.equal(app.db.hh_xp.filter((r) => r.get('sleutel') === 'klaar:k1#1').length, 1);
});

test('niveau: genoeg XP + klussen -> ervaren, beloning zegt niveau_omhoog', () => {
  const klussen = [];
  for (let i = 1; i <= 5; i++) klussen.push({ id: `kk${i}`, hulpvrager: 'b1', toegewezen_jongere: 'h1', status: 'afgerond', wanneer_van: `2026-09-0${i} 08:00:00.000Z` });
  const { app, env } = wereld({ hh_klussen: klussen, hh_beoordelingen: [] });
  // 5x50 + 25 + 4x75 = 575 -> ervaren (300 XP, 5 klussen)
  const u = hulp.werkXpBij(env, 'h1');
  assert.equal(u.totaal, 575);
  assert.equal(u.niveau, 'ervaren');
  const b = hulp.beloning(u);
  assert.equal(b.niveau_omhoog, true);
  assert.deepEqual(b.niveau, { code: 'ervaren', naam: 'Ervaren' });
  assert.ok(b.nieuwe_badges.some((x) => x.code === 'vijf_klussen' && x.naam === '5 klussen' && x.icoon));
  assert.equal(app.db.hh_profielen.find((p) => p.id === 'p1').get('niveau'), 'ervaren');
});

test('beloningMelden: één gebundelde melding, niet twee keer; niets erbij = geen melding', () => {
  const { app, env } = wereld();
  const u = hulp.werkXpBij(env, 'h1');
  assert.equal(hulp.beloningMelden(env, u, 'k2'), true);
  assert.equal(hulp.beloningMelden(env, u, 'k2'), false, 'zelfde sleutel');
  assert.equal(app.db.hh_meldingen.length, 1);
  const m = app.db.hh_meldingen[0];
  assert.equal(m.get('soort'), 'beloning');
  assert.equal(m.get('ontvanger'), 'h1');
  assert.equal(m.get('titel'), 'Nieuwe badge!');
  assert.equal(m.get('tekst'), '+230 XP · Nieuwe badge: Eerste klus · Nieuwe badge: Weer gevraagd');
  assert.equal(hulp.beloningMelden(env, hulp.werkXpBij(env, 'h1'), 'k2'), false);
});

test('overzicht: XP, niveau, volgend, badges (alle, behaald met datum), vertrouwen, verdiensten, recensies', () => {
  const { env } = wereld();
  hulp.werkXpBij(env, 'h1');
  const o = hulp.overzicht(env, 'h1');
  assert.equal(o.xp_totaal, 230);
  assert.deepEqual(o.niveau, { code: 'nieuw', naam: 'Nieuw' });
  assert.equal(o.volgend.code, 'ervaren');
  assert.equal(o.volgend.xp_nodig, 70);
  assert.equal(o.klussen_aantal, 2);
  assert.equal(o.badges.length, 7);
  assert.equal(o.badges.find((b) => b.code === 'eerste_klus').behaald_op, '2026-10-01 08:00:00.000Z');
  assert.equal(o.badges.find((b) => b.code === 'tien_klussen').behaald_op, '');
  assert.deepEqual(o.vertrouwen.map((v) => v.code), ['ouder_toestemming', 'vog']);
  assert.deepEqual(o.verdiensten.maanden, [{ maand: '2026-10', bedrag: 17.5, klussen: 2 }]);
  assert.deepEqual(o.recensies, [{ sterren: 5, tekst: 'Heel fijn geholpen!', datum: '2026-10-01 12:00:00.000Z', voornaam: 'Anja' }]);
  assert.equal(o.beoordelingen_aantal, 1, 'k3 is nog niet afgerond');
  assert.ok(o.boekingen.length > 0 && o.boekingen.length <= 10);
});

test('kaartInfo: niveau-naam en Nieuw in de buurt bij 0 afgeronde klussen', () => {
  const { env } = wereld();
  hulp.werkXpBij(env, 'h1');
  assert.deepEqual(hulp.kaartInfo(env, 'h1'), { niveau: 'Nieuw', niveau_code: 'nieuw', nieuw_in_de_buurt: false });
  assert.deepEqual(hulp.kaartInfo(env, 'h2'), { niveau: 'Nieuw', niveau_code: 'nieuw', nieuw_in_de_buurt: true });
});

test('verklaring: code XXXXX-XXXXX, snapshot, binnen een dag zelfde code, opzoeken werkt', () => {
  const { app, env } = wereld();
  hulp.werkXpBij(env, 'h1');
  const v = hulp.verklaringMaken(env, 'h1');
  assert.match(v.code, /^[A-Z2-9]{5}-[A-Z2-9]{5}$/);
  assert.equal(v.gegevens.voornaam, 'Ruud');
  assert.equal(v.gegevens.klussen, 2);
  assert.equal(v.gegevens.uren, 1.5, 'alleen k1 heeft een eindtijd');
  assert.equal(v.gegevens.periode_van, '2026-10-01');
  assert.equal(v.gegevens.periode_tot, '2026-10-02');
  assert.deepEqual(v.gegevens.badges.map((b) => b.naam), ['Eerste klus', 'Weer gevraagd']);
  assert.deepEqual(v.gegevens.vertrouwen.map((b) => b.naam), ['Toestemming ouder', 'VOG gezien']);
  assert.equal(JSON.stringify(v.gegevens).includes('Jansen'), false, 'nooit de achternaam');

  const nog = hulp.verklaringMaken(env, 'h1');
  assert.equal(nog.code, v.code, 'niets veranderd: zelfde verklaring');
  assert.equal(app.db.hh_verklaringen.length, 1);

  const gevonden = hulp.verklaringOpzoeken(env, v.code.toLowerCase().replace('-', ' '));
  assert.equal(gevonden.code, v.code);
  assert.equal(gevonden.gegevens.voornaam, 'Ruud');
  assert.equal(hulp.verklaringOpzoeken(env, 'ZZZZZ-ZZZZZ'), null);
  assert.equal(hulp.verklaringOpzoeken(env, 'kort'), null);
  assert.equal(hulp.verklaringMaken(env, 'b1'), null, 'alleen helpers');
});

test('verklaring: code bezet -> volgende poging', () => {
  const { app, env } = wereld({ hh_verklaringen: [{ id: 'v0', helper: 'h2', code: 'ABCDE-FGHJK', gegevens: {}, created: '2026-01-01 00:00:00.000Z' }] });
  const v = hulp.verklaringMaken(env, 'h1');
  assert.equal(v.code, 'ABCDE-FGHJM');
  assert.equal(app.db.hh_verklaringen.length, 2);
});

test('recensie verbergen: alleen meldkamer; telt daarna niet in XP en recensies; terugzetten kan', () => {
  const { app, env } = wereld();
  hulp.werkXpBij(env, 'h1');
  assert.equal(hulp.recensieVerbergen(env, { id: 'b1', rol: 'hulpvrager' }, 'o1', true).status, 403);
  assert.equal(hulp.recensieVerbergen(env, { id: 'coord', rol: 'coordinator' }, 'weg', true).status, 404);
  const r = hulp.recensieVerbergen(env, { id: 'coord', rol: 'coordinator' }, 'o1', true, 'Scheldwoord');
  assert.equal(r.status, 200);
  assert.equal(r.body.naar_gebruiker, 'h1');
  const o1 = app.db.hh_beoordelingen.find((b) => b.id === 'o1');
  assert.equal(o1.get('verborgen_door'), 'coord');
  assert.equal(o1.get('verborgen_reden'), 'Scheldwoord');
  const u = hulp.werkXpBij(env, 'h1');
  assert.deepEqual(u.boekingen.map((b) => [b.bron, b.punten]), [['beoordeling:o1', -30]]);
  assert.deepEqual(hulp.overzicht(env, 'h1').recensies, []);
  hulp.recensieVerbergen(env, { id: 'coord', rol: 'coordinator' }, 'o1', false);
  assert.equal(o1.get('verborgen_op'), '');
  assert.equal(hulp.werkXpBij(env, 'h1').totaal, 230);
});

test('naberekenen: alle helpers met een afgeronde klus; droog schrijft niets', () => {
  const { app, env } = wereld();
  const droog = hulp.naberekenen(env, { droog: true });
  assert.deepEqual(droog.map((d) => [d.helper, d.totaal]), [['h1', 230]]);
  assert.equal(app.db.hh_xp.length, 0);
  hulp.naberekenen(env, {});
  assert.equal(app.db.hh_xp.length, 5);
  assert.deepEqual(hulp.naberekenen(env, { droog: true }), [], 'daarna niets meer te doen');
});

test('twee helpers hebben elk hun eigen "eerste#1" (uniek per helper)', () => {
  const { app, env } = wereld();
  app.db.hh_klussen.find((k) => k.id === 'k4').set('status', 'afgerond');
  hulp.werkXpBij(env, 'h1');
  const u2 = hulp.werkXpBij(env, 'h2');
  assert.equal(u2.totaal, 75);
  assert.equal(app.db.hh_xp.filter((r) => r.get('sleutel') === 'eerste#1').length, 2);
  assert.deepEqual(u2.nieuwe_badges, ['eerste_klus']);
});
