// HeitjeHulp B6 — test van backend/pb_hooks/hh_chat_hulp.js zonder server.
// Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs
//
// Het hulpbestand is CommonJS (zoals de JSVM van PocketBase het laadt), maar
// backend/package.json staat op "type": "module". Daarom laden we het met
// een eigen module-wikkel in plaats van require().

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const hier = path.dirname(fileURLToPath(import.meta.url));
const bron = readFileSync(path.join(hier, '..', 'pb_hooks', 'hh_chat_hulp.js'), 'utf8');
const module_ = { exports: {} };
new Function('module', 'exports', bron)(module_, module_.exports);
const hulp = module_.exports;

const V = hulp.VERVANGING;
const filter = (t) => hulp.filterTekst(t);

// ---- Constanten ---------------------------------------------------------------

test('constanten: 3 dagen open na afloop, 10 minuten tussen meldingen, 500 tekens', () => {
  assert.equal(hulp.CHAT_DICHT_NA_UREN, 72);
  assert.equal(hulp.MELDING_INTERVAL_MINUTEN, 10);
  assert.equal(hulp.MAX_TEKST, 500);
  assert.equal(V, '•••');
});

// ---- Telefoonnummers -------------------------------------------------------------

const NUMMERS = [
  '0612345678',
  '06-12345678',
  '06 12345678',
  '06 1234 5678',
  '06 12 34 56 78',
  '06-12 34 56 78',
  '06.12.34.56.78',
  '+31612345678',
  '+31 6 12345678',
  '+31 6 1234 5678',
  '+31 (0)6 12345678',
  '+31-6-12345678',
  '0031612345678',
  '0031 6 12 34 56 78',
  '(06) 12345678',
  '0344-123456',
  '0344 12 34 56',
  '(0344) 123456',
  '+49 170 1234567',
  '6 1 2 3 4 5 6 7 8',
];

for (const nummer of NUMMERS) {
  test(`telefoonnummer "${nummer}" wordt ${V}`, () => {
    const uit = filter(`Bel me op ${nummer} oke`);
    assert.equal(uit.tekst, `Bel me op ${V} oke`);
    assert.equal(uit.gefilterd, true);
  });
}

test('nummer aan het begin, aan het eind en twee keer', () => {
  assert.equal(filter('0612345678 is mijn nummer').tekst, `${V} is mijn nummer`);
  assert.equal(filter('nummer: 0612345678').tekst, `nummer: ${V}`);
  assert.equal(filter('0612345678 of 0687654321').tekst, `${V} of ${V}`);
});

const GEEN_NUMMER = [
  'Ik kom om 10:00',
  'Ik kom zaterdag om 10.30 uur',
  'Tussen 9 en 12 uur',
  'Het kost 12,50 euro',
  'Postcode 4001 AB, huisnummer 12',
  'Op 12-10-2026 om 14.30',
  'Op 12-10-2026 14.30',
  '3 zakken en 2 dozen',
  'Kamer 12, derde verdieping',
  'Het is 1.250 meter',
];

for (const tekst of GEEN_NUMMER) {
  test(`geen nummer: "${tekst}" blijft staan`, () => {
    const uit = filter(tekst);
    assert.equal(uit.tekst, tekst);
    assert.equal(uit.gefilterd, false);
  });
}

// ---- E-mail ---------------------------------------------------------------------

const MAILS = [
  'jan@gmail.com',
  'Jan.de.Vries@hotmail.nl',
  'jan+chat@outlook.com',
  'jan @ gmail.com',
  'jan(at)gmail.com',
  'jan [at] gmail.com',
  'jan at gmail dot com',
  'jan@gmail punt com',
];

for (const mail of MAILS) {
  test(`e-mailadres "${mail}" wordt ${V}`, () => {
    const uit = filter(`Mail naar ${mail} graag`);
    assert.equal(uit.tekst, `Mail naar ${V} graag`);
    assert.equal(uit.gefilterd, true);
  });
}

// ---- Links -----------------------------------------------------------------------

const LINKS = [
  'https://instagram.com/jan',
  'http://example.org',
  'www.google.nl',
  'wa.me/31612345678',
  'instagram.com/jan_123',
  'bit.ly/abc',
  't.me/jan',
  'tiktok.com/@jan',
  'heitjehulp.nl/hoi?x=1',
];

for (const link of LINKS) {
  test(`link "${link}" wordt ${V}`, () => {
    const uit = filter(`Kijk ${link} even`);
    assert.equal(uit.tekst, `Kijk ${V} even`);
    assert.equal(uit.gefilterd, true);
  });
}

test('gewone zinnen met een punt blijven staan', () => {
  for (const tekst of ['Ik ben er.Tot zo', 'Klaar. Dank je wel!', 'Ok.', 'Dat is 2.5 uur']) {
    const uit = filter(tekst);
    assert.equal(uit.tekst, tekst, tekst);
    assert.equal(uit.gefilterd, false, tekst);
  }
});

// ---- Contactverzoek (markeren, niet blokkeren) -------------------------------

const VERZOEKEN = [
  'Heb je whatsapp?',
  'Zullen we via WhatsApp verder praten',
  'app me even',
  'Kun je me appen?',
  'Stuur me een appje',
  'Wat is je snapchat',
  'Heb je snap? dan voeg ik je toe',
  'Volg me op insta',
  'Mijn instagram is jantje',
  'Heb je tiktok?',
  'Zit je op telegram',
  'Geef me je nummer',
  'Wat is jouw telefoonnummer?',
  'Mag ik je 06 nummer',
  'Mail me even',
  'Wat is je e-mailadres',
  'w h a t s a p p',
  'W.h.a.t.s.a.p.p',
  'S N A P C H A T',
  'watsapp',
];

for (const tekst of VERZOEKEN) {
  test(`contactverzoek gemarkeerd: "${tekst}"`, () => {
    const uit = filter(tekst);
    assert.equal(uit.contactverzoek, true);
    // Niet blokkeren: de woorden zelf blijven staan.
    assert.equal(uit.tekst, tekst);
  });
}

const GEEN_VERZOEK = [
  'Ik snap het',
  'Snap je wat ik bedoel?',
  'Ik zie het in de app',
  'De app werkt goed',
  'Het nummer van de bus is 12',
  'Huisnummer 12',
  'Bel even aan',
  'Ik ben onderweg',
  'Prima!',
];

for (const tekst of GEEN_VERZOEK) {
  test(`geen contactverzoek: "${tekst}"`, () => {
    assert.equal(filter(tekst).contactverzoek, false);
  });
}

test('nummer EN verzoek: gefilterd en gemarkeerd', () => {
  const uit = filter('App me op 06-12345678');
  assert.equal(uit.tekst, `App me op ${V}`);
  assert.equal(uit.gefilterd, true);
  assert.equal(uit.contactverzoek, true);
});

test('lege of rare invoer: nooit een fout', () => {
  assert.deepEqual(filter(''), { tekst: '', gefilterd: false, contactverzoek: false });
  assert.deepEqual(filter(null), { tekst: '', gefilterd: false, contactverzoek: false });
  assert.equal(filter('   hoi   ').tekst, 'hoi', 'spaties eromheen weg');
});

// ---- Chat open of dicht -------------------------------------------------------------

const UUR = 3600 * 1000;
const NU = Date.UTC(2026, 9, 4, 12, 0, 0);

test('zonder helper is de chat dicht (concept, open, of geannuleerd zonder helper)', () => {
  assert.equal(hulp.chatStand('open', '', 0, NU), 'geenhelper');
  assert.equal(hulp.chatStand('concept', '', 0, NU), 'geenhelper');
  assert.equal(hulp.chatStand('geannuleerd', '', NU, NU), 'geenhelper');
  // Een vreemde status met helper telt ook niet als open.
  assert.equal(hulp.chatStand('open', 'j1', 0, NU), 'geenhelper');
});

test('met helper en de klus loopt: open', () => {
  for (const status of ['geaccepteerd', 'onderweg', 'bezig', 'probleem']) {
    assert.equal(hulp.chatStand(status, 'j1', 0, NU), 'open', status);
  }
});

test('afgerond of geannuleerd: open tot en met 72 uur, daarna dicht', () => {
  for (const status of ['afgerond', 'geannuleerd']) {
    assert.equal(hulp.chatStand(status, 'j1', NU - 1 * UUR, NU), 'open', status);
    assert.equal(hulp.chatStand(status, 'j1', NU - 72 * UUR, NU), 'open', `${status} precies 72 uur`);
    assert.equal(hulp.chatStand(status, 'j1', NU - 72 * UUR - 1, NU), 'dicht', `${status} net te laat`);
    assert.equal(hulp.chatStand(status, 'j1', NU - 30 * 24 * UUR, NU), 'dicht', status);
  }
});

test('afgerond zonder bekend moment: dicht (liever dicht dan open)', () => {
  assert.equal(hulp.chatStand('afgerond', 'j1', NaN, NU), 'dicht');
  assert.equal(hulp.chatStand('afgerond', 'j1', null, NU), 'dicht');
});

test('serverdatum van PocketBase wordt een moment', () => {
  assert.equal(hulp.momentVan('2026-10-04 12:00:00.000Z'), NU);
  assert.ok(Number.isNaN(hulp.momentVan('')));
  assert.ok(Number.isNaN(hulp.momentVan('onzin')));
});

// ---- Ontvanger en melding -----------------------------------------------------------

test('ontvanger is de andere deelnemer van de chat', () => {
  const klus = { hulpvrager: 'b1', toegewezen_jongere: 'j1' };
  assert.equal(hulp.ontvangerVan('b1', 'j1', klus), 'j1');
  assert.equal(hulp.ontvangerVan('j1', 'j1', klus), 'b1');
  // Het bericht hoort bij een vorige helper: de nieuwe helper krijgt niets.
  assert.equal(hulp.ontvangerVan('b1', 'j0', klus), '');
  // Een vreemde afzender (kan niet door de rule, maar toch): niemand.
  assert.equal(hulp.ontvangerVan('x', 'j1', klus), '');
});

test('melding: hooguit een per 10 minuten per chat', () => {
  assert.equal(hulp.magMelden(NaN, NU), true, 'nog nooit gemeld');
  assert.equal(hulp.magMelden(NU - 9 * 60 * 1000, NU), false);
  assert.equal(hulp.magMelden(NU - 10 * 60 * 1000, NU), true);
});

test('melding in gewone taal, zonder de inhoud van het bericht', () => {
  const m = hulp.meldingTekst('Daan de Vries', 'tuin');
  assert.equal(m.titel, 'Nieuw bericht van Daan');
  assert.equal(m.tekst, 'Over je klus: Tuin. Open de chat om te lezen.');
  const zonder = hulp.meldingTekst('', '');
  assert.equal(zonder.titel, 'Nieuw bericht');
  assert.equal(zonder.tekst, 'Open de chat om te lezen.');
});

test('PocketBase-datum voor een filter', () => {
  assert.equal(hulp.pbDatum(NU), '2026-10-04 12:00:00.000Z');
});

// ---- Sim 24 uur (5 okt): uitgeschreven nummers en gebruikersnamen ----------------

const NUMMERS_IN_WOORDEN = [
  'nul zes een twee drie vier vijf zes zeven acht',
  '06 een twee 34 vijf zes 78',
  'Nul Zes Een Twee Drie Vier Vijf Zes Zeven Acht',
  'nul-zes-een-twee-drie-vier-vijf-zes-zeven-acht',
  'nul zes, een twee, drie vier, vijf zes, zeven acht',
  'nul zes één twee drie vier vijf zes zeven acht',
  'nul zes twaalf vierendertig zesenvijftig achtenzeventig',
  '06 twaalf 34 zesenvijftig 78',
  'zero six one two three four five six seven eight',
];

for (const nummer of NUMMERS_IN_WOORDEN) {
  test(`nummer in woorden wordt verborgen: ${nummer}`, () => {
    const uit = filter(`Bel me op ${nummer} graag`);
    assert.equal(uit.gefilterd, true);
    assert.equal(uit.tekst, `Bel me op ${V} graag`);
    assert.equal(uit.contactverzoek, true, 'de meldkamer moet het zien');
  });
}

const GEEN_NUMMER_IN_WOORDEN = [
  'Ik heb een, twee, drie zakken tuinafval.',
  'Kun je 12-10-2026 drie uur helpen?',
  'Kom je 12-10-2026 een uur eerder?',
  'Het zijn twee of drie dozen, een kwartier werk.',
  'Een twee drie vier, hoedje van papier.',
  'Tussen vier en vijf, huisnummer 12, zes treden op.',
  'Ik reken 5 euro voor twee uur, een keer per week.',
];

for (const zin of GEEN_NUMMER_IN_WOORDEN) {
  test(`gewone zin met telwoorden blijft staan: ${zin}`, () => {
    const uit = filter(zin);
    assert.equal(uit.tekst, zin);
    assert.equal(uit.gefilterd, false);
  });
}

test('één telwoord tussen de cijfers: niet verbergen (kan een datum zijn), wel melden', () => {
  const uit = filter('0612345 zes 78');
  assert.equal(uit.contactverzoek, true);
});

test('datum met één telwoord erachter is geen contactverzoek', () => {
  assert.equal(filter('Kun je 12-10-2026 drie uur helpen?').contactverzoek, false);
  assert.equal(filter('Kom je 12-10-2026 een uur eerder?').contactverzoek, false);
});

const GEBRUIKERSNAMEN = [
  ['snap: daan_2011', `snap: ${V}`],
  ['Snap = daan.2011', `Snap = ${V}`],
  ['mijn insta: daan_2011 voeg me toe', `mijn insta: ${V} voeg me toe`],
  ['sc: daan2011', `sc: ${V}`],
  ['ig: daan.de.vries', `ig: ${V}`],
  ['tiktok: @daan2011', `tiktok: ${V}`],
  ['zoek me op, @daan_2011', `zoek me op, ${V}`],
  ['@daan2011', V],
];

for (const [tekst, verwacht] of GEBRUIKERSNAMEN) {
  test(`gebruikersnaam wordt verborgen en gemeld: ${tekst}`, () => {
    const uit = filter(tekst);
    assert.equal(uit.tekst, verwacht);
    assert.equal(uit.gefilterd, true);
    assert.equal(uit.contactverzoek, true);
  });
}

const GEEN_GEBRUIKERSNAAM = [
  'Ik snap het, tot morgen!',
  'Snap je wat ik bedoel?',
  'Tot 14.30 @ de voordeur',
  'Ik snap: het gras eerst, dan de heg.',
  'Let op: de poort klemt.',
];

for (const zin of GEEN_GEBRUIKERSNAAM) {
  test(`geen gebruikersnaam: ${zin}`, () => {
    const uit = filter(zin);
    assert.equal(uit.tekst, zin);
    assert.equal(uit.gefilterd, false);
  });
}

test('"voeg me toe" en "add me" zijn een contactverzoek', () => {
  assert.equal(hulp.isContactverzoek('voeg me even toe'), true);
  assert.equal(hulp.isContactverzoek('add me maar'), true);
  assert.equal(hulp.isContactverzoek('Ik voeg de zakken toe aan de stapel'), false);
});
