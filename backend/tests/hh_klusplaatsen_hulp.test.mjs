// HeitjeHulp B4 — test van backend/pb_hooks/hh_klusplaatsen_hulp.js zonder server.
// Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const hier = path.dirname(fileURLToPath(import.meta.url));
function laad(naam) {
  const bron = readFileSync(path.join(hier, '..', 'pb_hooks', naam), 'utf8');
  const module_ = { exports: {} };
  new Function('module', 'exports', bron)(module_, module_.exports);
  return module_.exports;
}
const hulp = laad('hh_klusplaatsen_hulp.js');
const aanmelden = laad('hh_aanmelden_hulp.js');

// Zomertijd (CEST, +2): 5 oktober 2026. Wintertijd (CET, +1): 5 november 2026.
const zomer = (uur, minuut = 0) => new Date(Date.UTC(2026, 9, 5, uur - 2, minuut)).toISOString();
const winter = (uur, minuut = 0) => new Date(Date.UTC(2026, 10, 5, uur - 1, minuut)).toISOString();

test('nlTijd: UTC naar Nederlandse wandklok, zomer en winter', () => {
  assert.deepEqual(hulp.nlTijd(zomer(14)), { datum: '2026-10-05', minuten: 14 * 60 });
  assert.deepEqual(hulp.nlTijd(winter(14)), { datum: '2026-11-05', minuten: 14 * 60 });
  // PocketBase-vorm met een spatie.
  assert.deepEqual(hulp.nlTijd('2026-10-05 12:00:00.000Z'), { datum: '2026-10-05', minuten: 14 * 60 });
  // Kwart voor middernacht UTC is in de zomer al de volgende dag.
  assert.deepEqual(hulp.nlTijd('2026-10-05 22:45:00.000Z'), { datum: '2026-10-06', minuten: 45 });
  assert.equal(hulp.nlTijd(''), null);
  assert.equal(hulp.nlTijd('onzin'), null);
});

test('tijdregel: binnen 07:00-19:00 en hooguit 2 uur is voor iedereen', () => {
  assert.equal(hulp.isAlleen18Plus({ van: zomer(14), tot: zomer(16) }), false);
  assert.equal(hulp.isAlleen18Plus({ van: zomer(7), tot: zomer(9) }), false, 'precies 07:00 en precies 2 uur');
  assert.equal(hulp.isAlleen18Plus({ van: zomer(17), tot: zomer(19) }), false, 'eindigt precies 19:00');
  assert.equal(hulp.isAlleen18Plus({ van: zomer(17) }), false, 'precies 17:00 zonder eindtijd');
  assert.equal(hulp.isAlleen18Plus({ van: winter(10), tot: winter(11, 30) }), false);
});

test('tijdregel: te vroeg, te laat, te lang of laat zonder eindtijd is alleen 18+', () => {
  assert.equal(hulp.isAlleen18Plus({ van: zomer(6, 45), tot: zomer(8) }), true, 'begint voor 07:00');
  assert.equal(hulp.isAlleen18Plus({ van: zomer(18), tot: zomer(19, 15) }), true, 'eindigt na 19:00');
  assert.equal(hulp.isAlleen18Plus({ van: zomer(20) }), true, '20:00 zonder eindtijd');
  assert.equal(hulp.isAlleen18Plus({ van: zomer(17, 15) }), true, 'na 17:00 zonder eindtijd');
  assert.equal(hulp.isAlleen18Plus({ van: zomer(14), tot: zomer(16, 15) }), true, 'langer dan 2 uur');
  assert.equal(hulp.isAlleen18Plus({ van: zomer(18), tot: '2026-10-06 06:00:00.000Z' }), true, 'over middernacht');
  assert.equal(hulp.isAlleen18Plus({ van: winter(6, 59), tot: winter(7, 30) }), true, 'wintertijd telt ook');
});

test('tijdregel: zonder begintijd geen tijdregel; een eindtijd vóór het begin telt als geen eindtijd', () => {
  assert.equal(hulp.isAlleen18Plus({}), false);
  assert.equal(hulp.isAlleen18Plus({ van: '', tot: '' }), false);
  assert.equal(hulp.isAlleen18Plus({ van: zomer(14), tot: zomer(13) }), false);
});

test('minLeeftijdVoorKlus: maximum van categorie en tijdregel, nooit onder 10', () => {
  assert.equal(hulp.minLeeftijdVoorKlus({ typeMinLeeftijd: 13, van: zomer(14), tot: zomer(15) }), 13);
  assert.equal(hulp.minLeeftijdVoorKlus({ typeMinLeeftijd: 10, van: zomer(20) }), 18);
  assert.equal(hulp.minLeeftijdVoorKlus({ typeMinLeeftijd: 16, van: zomer(10), tot: zomer(11) }), 16);
  assert.equal(hulp.minLeeftijdVoorKlus({ typeMinLeeftijd: 4, van: zomer(10) }), 10);
  // Onbekende categorie (geen getal): veilig 18.
  assert.equal(hulp.minLeeftijdVoorKlus({ typeMinLeeftijd: 0, van: zomer(10) }), 18);
  assert.equal(hulp.minLeeftijdVoorKlus({ typeMinLeeftijd: undefined }), 18);
});

test('geborenUiterlijk: de klusdag min de jaren, als PocketBase-datum aan het eind van de dag', () => {
  assert.equal(hulp.geborenUiterlijk(zomer(14), 13), '2013-10-05 23:59:59.999Z');
  // De NL-dag telt, niet de UTC-dag.
  assert.equal(hulp.geborenUiterlijk('2026-10-05 22:30:00.000Z', 10), '2016-10-06 23:59:59.999Z');
  // 29 februari bestaat niet in het doeljaar: 28 februari.
  assert.equal(hulp.geborenUiterlijk('2028-02-29 10:00:00.000Z', 13), '2015-02-28 23:59:59.999Z');
  assert.equal(hulp.geborenUiterlijk('', 13), '');
});

test('isOudGenoeg klopt met leeftijd() uit B2 op de klusdag', () => {
  const klusdag = zomer(14); // 2026-10-05
  const grens = hulp.geborenUiterlijk(klusdag, 13);
  for (const geboren of ['2013-10-05', '2013-10-06', '2013-10-04', '2012-02-29', '2014-01-01', '2000-01-01']) {
    const pb = `${geboren} 00:00:00.000Z`;
    assert.equal(hulp.isOudGenoeg(pb, grens), aanmelden.leeftijd(pb, '2026-10-05') >= 13, geboren);
  }
  assert.equal(hulp.isOudGenoeg('', grens), false, 'geen geboortedatum');
  assert.equal(hulp.isOudGenoeg('2000-01-01 00:00:00.000Z', ''), false, 'geen grens');
  // Schrikkeldag-grens: wie op 1 maart jarig is, is op 29 februari nog niet 13.
  const schrikkel = hulp.geborenUiterlijk('2028-02-29 10:00:00.000Z', 13);
  assert.equal(hulp.isOudGenoeg('2015-03-01 00:00:00.000Z', schrikkel), false);
  assert.equal(hulp.isOudGenoeg('2015-02-28 00:00:00.000Z', schrikkel), true);
});

test('voorfilter: telefoon, e-mail, link en de nee-lijst, zonder vals alarm', () => {
  assert.deepEqual(hulp.voorfilter('Bel me op 06-12345678 voor de details'), ['telefoon']);
  assert.deepEqual(hulp.voorfilter('Mijn nummer: +31 6 1234 5678'), ['telefoon']);
  assert.deepEqual(hulp.voorfilter('Mail naar jan@example.nl'), ['email']);
  assert.deepEqual(hulp.voorfilter('Kijk op www.voorbeeld.nl'), ['link']);
  assert.deepEqual(hulp.voorfilter('zie https://x.y/z'), ['link']);
  assert.deepEqual(hulp.voorfilter('Een krat Bier halen bij de supermarkt'), ['neelijst']);
  assert.deepEqual(hulp.voorfilter('Sigaretten en een ladder'), ['neelijst']);
  assert.deepEqual(
    hulp.voorfilter('Bel 0612345678 of mail a@b.nl, ook voor bier'),
    ['telefoon', 'email', 'neelijst'],
  );
  for (const gewoon of [
    'De heg aan de voorkant knippen. Het snoeiafval mag in de groene bak.',
    'Boodschappen voor 2 dagen, rond 10 uur, postcode 4003 AB',
    'Op 12-10-2026 om 14:00 de fiets plakken',
    'Bierviltjes sorteren', // geen heel woord
    '',
  ]) {
    assert.deepEqual(hulp.voorfilter(gewoon), [], gewoon);
  }
});

test('controleerNieuweKlus: foto, omschrijving, vinkje, tijd', () => {
  const nu = new Date(zomer(9)).getTime();
  const goed = { omschrijving: 'Heg knippen', heeftFoto: true, neeLijstAkkoord: true, van: zomer(14), tot: zomer(15), nu };
  assert.equal(hulp.controleerNieuweKlus(goed), null);
  assert.equal(hulp.controleerNieuweKlus({ ...goed, tot: '' }), null, 'eindtijd is optioneel');
  const reden = (extra) => hulp.controleerNieuweKlus({ ...goed, ...extra })?.reden;
  assert.equal(reden({ heeftFoto: false }), 'foto');
  assert.equal(reden({ omschrijving: '   ' }), 'omschrijving');
  assert.equal(reden({ omschrijving: 'abc' }), 'omschrijving');
  assert.equal(reden({ omschrijving: 'x'.repeat(301) }), 'omschrijving');
  assert.equal(reden({ neeLijstAkkoord: false }), 'neelijst');
  assert.equal(reden({ van: '' }), 'wanneer');
  assert.equal(reden({ van: zomer(8) }), 'verleden');
  assert.equal(reden({ tot: zomer(13) }), 'tot');
  // Elke weigering heeft een Nederlandse melding.
  assert.match(hulp.controleerNieuweKlus({ ...goed, heeftFoto: false }).melding, /foto/i);
});

test('afkeurTekst: titel en tekst voor de bewoner, met de reden', () => {
  const t = hulp.afkeurTekst('Er staat een telefoonnummer in.');
  assert.equal(t.titel, 'Je klus is afgekeurd');
  assert.match(t.tekst, /telefoonnummer/);
});

test('magNieuweKlusMelding: alleen bij een goedgekeurde klus en een helper die oud genoeg is', () => {
  const grens = hulp.geborenUiterlijk(zomer(14), 13);
  const basis = { goedgekeurdOp: '2026-10-05 08:00:00.000Z', geborenUiterlijk: grens };
  assert.equal(hulp.magNieuweKlusMelding({ ...basis, geboortedatum: '2000-01-01 00:00:00.000Z' }), true);
  assert.equal(hulp.magNieuweKlusMelding({ ...basis, geboortedatum: '2015-01-01 00:00:00.000Z' }), false, 'te jong');
  assert.equal(hulp.magNieuweKlusMelding({ ...basis, goedgekeurdOp: '', geboortedatum: '2000-01-01 00:00:00.000Z' }), false, 'nog niet gekeurd');
  assert.equal(hulp.magNieuweKlusMelding({ ...basis, geboortedatum: '' }), false);
});

test('de 13 categorieën met minimumleeftijd (besluit punt 6, voorstel)', () => {
  const namen = hulp.KLUS_CATEGORIEEN.map((c) => c.naam);
  assert.deepEqual(namen, [
    'Tuin', 'Auto & fiets', 'Schoonmaak', 'Opruimen', 'Boodschappen', 'Dieren', 'Computer',
    'Rondom huis', 'Helpende hand', 'Creatief', 'Kleine klusjes', 'Hulp & kennis', 'Overig',
  ]);
  const per = Object.fromEntries(hulp.KLUS_CATEGORIEEN.map((c) => [c.naam, c.min_leeftijd]));
  for (const n of ['Boodschappen', 'Dieren', 'Kleine klusjes', 'Helpende hand', 'Rondom huis']) assert.equal(per[n], 10, n);
  for (const n of ['Tuin', 'Opruimen', 'Auto & fiets', 'Computer', 'Creatief', 'Hulp & kennis', 'Overig']) assert.equal(per[n], 13, n);
  assert.equal(per.Schoonmaak, 16);
  hulp.KLUS_CATEGORIEEN.forEach((c, i) => {
    assert.equal(c.volgorde, i + 1);
    assert.ok(c.icoon, `${c.naam} heeft een icoon`);
  });
  // Elk oud klustype van de seed krijgt een minimumleeftijd.
  for (const oud of ['boodschappen', 'tuin', 'klusje in huis', 'telefoon/tablet-hulp', 'wandelen/gezelschap', 'vervoer']) {
    assert.ok(hulp.OUDE_KLUSTYPES_MIN_LEEFTIJD[oud] >= 10, oud);
  }
});

// Antwoord Ibrahim (4 okt): helpers van 10 t/m 14 jaar moeten om 18:00 klaar
// zijn; 15-17 blijft 19:00; 18+ geen grens.
test('tijdregel 10-14: na 18:00 klaar (of zonder eindtijd na 16:00 begonnen) is pas vanaf 15', () => {
  assert.equal(hulp.LAATSTE_EIND_JONG_MIN, 18 * 60);
  assert.equal(hulp.LAATSTE_START_ZONDER_EIND_JONG_MIN, 16 * 60);
  assert.equal(hulp.JONG_TOT_EN_MET, 14);
  assert.equal(hulp.tijdMinLeeftijd({ van: zomer(16), tot: zomer(18) }), 0, 'precies 18:00 klaar: iedereen');
  assert.equal(hulp.tijdMinLeeftijd({ van: zomer(16, 30), tot: zomer(18, 15) }), 15, 'eindigt 18:15');
  assert.equal(hulp.tijdMinLeeftijd({ van: zomer(17), tot: zomer(19) }), 15, 'eindigt precies 19:00');
  assert.equal(hulp.tijdMinLeeftijd({ van: zomer(18), tot: zomer(19, 15) }), 18, 'eindigt na 19:00');
  assert.equal(hulp.tijdMinLeeftijd({ van: zomer(16) }), 0, 'precies 16:00 zonder eindtijd');
  assert.equal(hulp.tijdMinLeeftijd({ van: zomer(16, 15) }), 15, 'na 16:00 zonder eindtijd');
  assert.equal(hulp.tijdMinLeeftijd({ van: zomer(17, 15) }), 18, 'na 17:00 zonder eindtijd');
  assert.equal(hulp.tijdMinLeeftijd({ van: winter(17), tot: winter(18, 30) }), 15, 'wintertijd telt ook');
  assert.equal(hulp.tijdMinLeeftijd({}), 0, 'zonder begintijd geen tijdregel');
});

test('minLeeftijdVoorKlus: de 18:00-grens tilt 10- en 13-categorieën naar 15, niet 16 of hoger', () => {
  assert.equal(hulp.minLeeftijdVoorKlus({ typeMinLeeftijd: 10, van: zomer(17), tot: zomer(18, 30) }), 15);
  assert.equal(hulp.minLeeftijdVoorKlus({ typeMinLeeftijd: 13, van: zomer(16, 30) }), 15);
  assert.equal(hulp.minLeeftijdVoorKlus({ typeMinLeeftijd: 16, van: zomer(17), tot: zomer(18, 30) }), 16);
  assert.equal(hulp.minLeeftijdVoorKlus({ typeMinLeeftijd: 10, van: zomer(15), tot: zomer(17) }), 10);
});
