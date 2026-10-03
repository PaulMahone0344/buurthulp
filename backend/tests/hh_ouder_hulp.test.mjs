// HeitjeHulp B3 — test van backend/pb_hooks/hh_ouder_hulp.js zonder server.
// Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs
//
// Er gaat NOOIT echte mail de deur uit: de mail-functie is een nep die alleen
// onthoudt wat er verstuurd zou worden.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash, timingSafeEqual } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const hier = path.dirname(fileURLToPath(import.meta.url));
const bron = readFileSync(path.join(hier, '..', 'pb_hooks', 'hh_ouder_hulp.js'), 'utf8');
const module_ = { exports: {} };
new Function('module', 'exports', bron)(module_, module_.exports);
const hulp = module_.exports;

const UUR = 3600 * 1000;
const T0 = Date.UTC(2026, 9, 4, 10, 0, 0); // 4 okt 2026 10:00 UTC

// ---- puur -------------------------------------------------------------------

test('IBAN: NL, mod-97, spaties en kleine letters mogen', () => {
  assert.equal(hulp.isGeldigNlIban('NL91 ABNA 0417 1643 00'), true);
  assert.equal(hulp.isGeldigNlIban('nl91abna0417164300'), true);
  assert.equal(hulp.normaliseerIban(' nl91 abna 0417 1643 00 '), 'NL91ABNA0417164300');
  for (const fout of ['', 'NL91ABNA0417164301', 'DE89370400440532013000', 'NL91ABNA041716430', 'NL91 ABNA 0417 1643 0X']) {
    assert.equal(hulp.isGeldigNlIban(fout), false, fout);
  }
});

test('e-mail: bijsnijden, kleine letters, eenvoudige vorm', () => {
  assert.equal(hulp.normaliseerEmail('  Mama@Voorbeeld.NL '), 'mama@voorbeeld.nl');
  assert.equal(hulp.isGeldigEmail('mama@voorbeeld.nl'), true);
  for (const fout of ['', 'mama', 'mama@', '@x.nl', 'ma ma@x.nl', 'mama@x']) {
    assert.equal(hulp.isGeldigEmail(fout), false, fout);
  }
});

test('nep-adressen (.invalid, .test, .example, .localhost) krijgen nooit echte mail', () => {
  assert.equal(hulp.isNepAdres('b3check-ouder@heitjehulp.invalid'), true);
  assert.equal(hulp.isNepAdres('x@iets.test'), true);
  assert.equal(hulp.isNepAdres('x@voorbeeld.example'), true);
  assert.equal(hulp.isNepAdres('x@localhost'), true);
  assert.equal(hulp.isNepAdres('mama@gmail.com'), false);
  assert.equal(hulp.isNepAdres('mama@invalid.nl'), false);
});

test('link: token achter de # (komt nooit in serverlogs of Referer)', () => {
  assert.equal(hulp.linkVoor('https://heitjehulp.nl', 'abc'), 'https://heitjehulp.nl/#/ouder?t=abc');
  assert.equal(hulp.BASIS_URL, 'https://heitjehulp.nl');
});

test('mail: voornaam, uitleg, code groot, link, 24 uur, negeer-zin; HTML ontsnapt', () => {
  const m = hulp.uitnodigingsMail({ voornaam: 'Daan', code: '482913', link: 'https://heitjehulp.nl/#/ouder?t=abc' });
  assert.equal(m.onderwerp, 'Daan wil helper worden bij HeitjeHulp');
  for (const deel of ['Daan', '482913', 'https://heitjehulp.nl/#/ouder?t=abc', '24 uur', 'Was jij dit niet? Negeer deze mail.', 'HeitjeHulp brengt buren']) {
    assert.ok(m.tekst.includes(deel), `tekst mist ${deel}`);
    assert.ok(m.html.includes(deel.replace('&', '&amp;')), `html mist ${deel}`);
  }
  assert.match(m.html, /font-size:\s*3\dpx/); // de code groot
  const kwaad = hulp.uitnodigingsMail({ voornaam: '<b>x</b>\r\nBcc: y', code: '1', link: 'l' });
  assert.ok(!kwaad.html.includes('<b>x</b>'));
  assert.ok(!/[\r\n]/.test(kwaad.onderwerp));
});

test('mail na intrekken: bevestiging in je-vorm', () => {
  const m = hulp.intrekMail({ voornaam: 'Daan' });
  assert.match(m.onderwerp, /ingetrokken/);
  assert.match(m.tekst, /Je hebt je toestemming voor Daan ingetrokken/);
});

test('hashes: nooit de code zelf, per helper anders', () => {
  const sha = (s) => createHash('sha256').update(s).digest('hex');
  const a = hulp.codeHash(sha, 'helper1', '123456');
  assert.notEqual(a, '123456');
  assert.ok(!a.includes('123456'));
  assert.notEqual(a, hulp.codeHash(sha, 'helper2', '123456'));
  assert.notEqual(hulp.tokenHash(sha, 'x'), hulp.sessieHash(sha, 'x'));
});

// ---- nep-server ---------------------------------------------------------------

function rec(collectie, velden = {}) {
  return {
    collectie,
    id: velden.id || '',
    velden: { ...velden },
    get(k) { return k === 'id' ? this.id : this.velden[k]; },
    set(k, v) { if (k === 'id') this.id = v; else this.velden[k] = v; },
  };
}

/// Filter-taal van de hulp: "veld = {:param}" en 'veld = "waarde"' met &&.
function past(r, filter, params) {
  return filter.split('&&').every((deel) => {
    const m = /^\s*(\w+)\s*=\s*(?:\{:(\w+)\}|"([^"]*)")\s*$/.exec(deel);
    if (!m) throw new Error(`nep kent filter niet: ${deel}`);
    const verwacht = m[2] ? params[m[2]] : m[3];
    return String(r.get(m[1]) ?? '') === String(verwacht);
  });
}

function nepOmgeving({ helpers = [], nu = T0, mailFaalt = false } = {}) {
  const db = {
    hh_users: helpers.map((h) => rec('hh_users', h)),
    hh_ouder_toestemming: [],
  };
  let volgnummer = 0;
  let teller = 0;
  const opslag = new Map();
  const mails = [];
  const app = {
    findRecordById(c, id) {
      const r = db[c].find((x) => x.id === id);
      if (!r) throw new Error('niet gevonden');
      return r;
    },
    findFirstRecordByFilter(c, f, p) {
      const r = db[c].find((x) => past(x, f, p));
      if (!r) throw new Error('niet gevonden');
      return r;
    },
    findRecordsByFilter(c, f, _s, _l, _o, p) {
      return db[c].filter((x) => past(x, f, p));
    },
    findCollectionByNameOrId(c) { return c; },
    save(r) {
      if (!r.id) r.id = `r${++volgnummer}`;
      if (!db[r.collectie].includes(r)) db[r.collectie].push(r);
    },
    runInTransaction(fn) { fn(app); },
  };
  const env = {
    app,
    Record: function (collectie) { return rec(collectie); },
    nu: () => env.klok,
    klok: nu,
    willekeurig: (lengte, alfabet) => {
      teller++;
      let s = '';
      for (let i = 0; i < lengte; i++) s += alfabet[(teller * 7 + i * 3) % alfabet.length];
      return s;
    },
    sha256: (s) => createHash('sha256').update(s).digest('hex'),
    gelijk: (a, b) => a.length === b.length && timingSafeEqual(Buffer.from(a), Buffer.from(b)),
    mail: (bericht) => {
      if (mailFaalt) throw new Error('smtp weg');
      mails.push(bericht);
    },
    store: { get: (k) => opslag.get(k), set: (k, v) => opslag.set(k, v) },
    log: () => {},
  };
  return { env, db, mails };
}

const KIND = { id: 'h1', rol: 'jongere', naam: 'Daan Verhoeven', email: 'daan@voorbeeld.nl', ouder_email: '', ouder_toestemming_op: '' };

function versturen(env, extra = {}) {
  const helper = env.app.findRecordById('hh_users', extra.helperId || 'h1');
  return hulp.verstuur(env, { helper, leeftijd: 'leeftijd' in extra ? extra.leeftijd : 14, ouderEmail: extra.ouderEmail ?? '' });
}

/// De code uit de laatste nep-mail.
function codeUit(mails) {
  return /Je code: (\d{6})/.exec(mails.at(-1).tekst)[1];
}
function tokenUit(mails) {
  return /#\/ouder\?t=([A-Za-z0-9]+)/.exec(mails.at(-1).tekst)[1];
}

// ---- versturen -----------------------------------------------------------------

test('versturen: maakt een rij met hashes, mailt de ouder, bewaart het adres op de helper', () => {
  const { env, db, mails } = nepOmgeving({ helpers: [KIND] });
  const uit = versturen(env, { ouderEmail: ' Mama@Voorbeeld.NL ' });
  assert.equal(uit.status, 200, JSON.stringify(uit.body));
  assert.equal(mails.length, 1);
  assert.equal(mails[0].aan, 'mama@voorbeeld.nl');
  const code = codeUit(mails);
  const rij = db.hh_ouder_toestemming[0];
  assert.equal(rij.get('helper'), 'h1');
  assert.equal(rij.get('status'), 'verstuurd');
  assert.equal(rij.get('pogingen'), 0);
  assert.equal(rij.get('code_hash'), hulp.codeHash(env.sha256, 'h1', code));
  assert.equal(rij.get('token_hash'), hulp.tokenHash(env.sha256, tokenUit(mails)));
  for (const [k, v] of Object.entries(rij.velden)) assert.ok(!String(v).includes(code), `code staat leesbaar in ${k}`);
  assert.equal(Date.parse(rij.get('code_verloopt_op').replace(' ', 'T')), T0 + 24 * UUR);
  assert.equal(db.hh_users[0].get('ouder_email'), 'mama@voorbeeld.nl');
  assert.equal(uit.body.nog_te_sturen, 2);
  assert.ok(!JSON.stringify(uit.body).includes(code));
});

test('versturen: zonder adres in het verzoek het bewaarde adres; geen adres = 400', () => {
  const { env, mails } = nepOmgeving({ helpers: [{ ...KIND, ouder_email: 'papa@voorbeeld.nl' }, { ...KIND, id: 'h2' }] });
  assert.equal(versturen(env).status, 200);
  assert.equal(mails[0].aan, 'papa@voorbeeld.nl');
  const leeg = versturen(env, { helperId: 'h2' });
  assert.equal(leeg.status, 400);
  assert.equal(leeg.body.reden, 'email');
});

test('versturen: je eigen adres is niet het adres van je ouder', () => {
  const { env } = nepOmgeving({ helpers: [KIND] });
  const uit = versturen(env, { ouderEmail: 'DAAN@voorbeeld.nl' });
  assert.equal(uit.status, 400);
  assert.equal(uit.body.reden, 'eigenadres');
});

test('versturen: alleen een helper onder 18 met geboortedatum', () => {
  const { env } = nepOmgeving({ helpers: [KIND, { ...KIND, id: 'b1', rol: 'hulpvrager' }] });
  assert.equal(versturen(env, { helperId: 'b1', ouderEmail: 'm@v.nl' }).body.reden, 'rol');
  assert.equal(versturen(env, { leeftijd: 18, ouderEmail: 'm@v.nl' }).body.reden, 'volwassen');
  assert.equal(versturen(env, { leeftijd: null, ouderEmail: 'm@v.nl' }).body.reden, 'geboortedatum');
});

test('opnieuw sturen: oude code vervalt, nieuwe token, pogingen terug op 0, max 3 per dag', () => {
  const { env, db, mails } = nepOmgeving({ helpers: [KIND] });
  versturen(env, { ouderEmail: 'mama@voorbeeld.nl' });
  const code1 = codeUit(mails);
  const token1 = tokenUit(mails);
  db.hh_ouder_toestemming[0].set('pogingen', 3);
  env.klok += UUR;
  const tweede = versturen(env);
  assert.equal(tweede.status, 200);
  assert.equal(db.hh_ouder_toestemming.length, 1, 'één rij per helper');
  const rij = db.hh_ouder_toestemming[0];
  assert.notEqual(rij.get('code_hash'), hulp.codeHash(env.sha256, 'h1', code1));
  assert.notEqual(tokenUit(mails), token1);
  assert.equal(rij.get('pogingen'), 0);
  assert.equal(tweede.body.nog_te_sturen, 1);
  assert.equal(versturen(env).status, 200);
  const vierde = versturen(env);
  assert.equal(vierde.status, 429);
  assert.equal(vierde.body.reden, 'limiet');
  assert.equal(mails.length, 3);
  // Een nieuwe dag (UTC): weer 3.
  env.klok = Date.UTC(2026, 9, 5, 0, 1);
  assert.equal(versturen(env).status, 200);
});

test('versturen na toestemming: 409; na intrekken mag het weer', () => {
  const { env, db, mails } = nepOmgeving({ helpers: [KIND] });
  versturen(env, { ouderEmail: 'mama@voorbeeld.nl' });
  const { body } = hulp.controleerCode(env, { token: tokenUit(mails), ip: '1.1.1.1' });
  hulp.geefToestemming(env, { sessie: body.sessie, naam: 'Anna Verhoeven', iban: 'NL91ABNA0417164300', akkoord: true, avp: true, ip: '1.1.1.1' });
  const helper = db.hh_users[0];
  assert.ok(helper.get('ouder_toestemming_op'));
  const dicht = versturen(env);
  assert.equal(dicht.status, 409);
  assert.equal(dicht.body.reden, 'algegeven');
  hulp.trekIn(env, { token: tokenUit(mails), ip: '1.1.1.1' });
  assert.equal(versturen(env).status, 200);
  assert.equal(db.hh_ouder_toestemming[0].get('status'), 'verstuurd');
});

test('mail mislukt: 502 en de poging telt niet mee', () => {
  const { env, db } = nepOmgeving({ helpers: [KIND], mailFaalt: true });
  const uit = versturen(env, { ouderEmail: 'mama@voorbeeld.nl' });
  assert.equal(uit.status, 502);
  assert.equal(uit.body.reden, 'mail');
  assert.equal(db.hh_ouder_toestemming[0].get('verstuur_aantal'), 0);
});

test('nep-adres: geen mail, wel een geldige rij (voor 92-b3check op prod)', () => {
  const { env, db, mails } = nepOmgeving({ helpers: [KIND] });
  const uit = versturen(env, { ouderEmail: 'b3check-ouder@heitjehulp.invalid' });
  assert.equal(uit.status, 200);
  assert.equal(mails.length, 0);
  assert.equal(db.hh_ouder_toestemming[0].get('status'), 'verstuurd');
});

// ---- code -------------------------------------------------------------------

test('code + e-mail: goede code geeft een ouder-sessie van 30 minuten', () => {
  const { env, db, mails } = nepOmgeving({ helpers: [KIND] });
  versturen(env, { ouderEmail: 'mama@voorbeeld.nl' });
  const uit = hulp.controleerCode(env, { email: 'MAMA@voorbeeld.nl', code: codeUit(mails), ip: '1.1.1.1' });
  assert.equal(uit.status, 200, JSON.stringify(uit.body));
  assert.equal(uit.body.status, 'verstuurd');
  assert.equal(uit.body.voornaam, 'Daan');
  assert.ok(uit.body.sessie.length >= 32);
  const rij = db.hh_ouder_toestemming[0];
  assert.equal(rij.get('sessie_hash'), hulp.sessieHash(env.sha256, uit.body.sessie));
  assert.equal(Date.parse(rij.get('sessie_verloopt_op').replace(' ', 'T')), T0 + 30 * 60 * 1000);
});

test('code: fout telt per rij; na 5 fouten geblokkeerd, ook de goede code', () => {
  const { env, db, mails } = nepOmgeving({ helpers: [KIND] });
  versturen(env, { ouderEmail: 'mama@voorbeeld.nl' });
  const goed = codeUit(mails);
  const fout = goed === '000000' ? '111111' : '000000';
  for (let i = 1; i <= 4; i++) {
    const uit = hulp.controleerCode(env, { email: 'mama@voorbeeld.nl', code: fout, ip: `ip${i}` });
    assert.equal(uit.status, 400);
    assert.equal(uit.body.reden, 'code');
  }
  const vijfde = hulp.controleerCode(env, { email: 'mama@voorbeeld.nl', code: fout, ip: 'ip5' });
  assert.equal(vijfde.status, 429);
  assert.equal(vijfde.body.reden, 'geblokkeerd');
  assert.equal(db.hh_ouder_toestemming[0].get('pogingen'), 5);
  const daarna = hulp.controleerCode(env, { email: 'mama@voorbeeld.nl', code: goed, ip: 'ip6' });
  assert.equal(daarna.status, 429);
  assert.equal(daarna.body.reden, 'geblokkeerd');
});

test('code: onbekend adres geeft hetzelfde antwoord als een foute code', () => {
  const { env, mails } = nepOmgeving({ helpers: [KIND] });
  versturen(env, { ouderEmail: 'mama@voorbeeld.nl' });
  const onbekend = hulp.controleerCode(env, { email: 'iemand@anders.nl', code: codeUit(mails), ip: 'a' });
  const foutCode = hulp.controleerCode(env, { email: 'mama@voorbeeld.nl', code: codeUit(mails) === '999999' ? '888888' : '999999', ip: 'b' });
  assert.deepEqual(onbekend, foutCode);
});

test('code: na 24 uur verlopen (status verlopen), ook met de link', () => {
  const { env, db, mails } = nepOmgeving({ helpers: [KIND] });
  versturen(env, { ouderEmail: 'mama@voorbeeld.nl' });
  env.klok += 24 * UUR + 1000;
  const uit = hulp.controleerCode(env, { email: 'mama@voorbeeld.nl', code: codeUit(mails), ip: 'a' });
  assert.equal(uit.status, 400);
  assert.equal(uit.body.reden, 'code');
  const viaLink = hulp.controleerCode(env, { token: tokenUit(mails), ip: 'a' });
  assert.equal(viaLink.status, 200);
  assert.equal(viaLink.body.status, 'verlopen');
  assert.equal(viaLink.body.sessie, undefined);
  assert.equal(db.hh_ouder_toestemming[0].get('status'), 'verlopen');
});

test('code: ongeldige invoer geeft 400 invoer', () => {
  const { env } = nepOmgeving({ helpers: [KIND] });
  assert.equal(hulp.controleerCode(env, { email: 'mama@voorbeeld.nl', code: '12a456', ip: 'a' }).body.reden, 'invoer');
  assert.equal(hulp.controleerCode(env, { email: 'geen-adres', code: '123456', ip: 'a' }).body.reden, 'invoer');
  assert.equal(hulp.controleerCode(env, { ip: 'a' }).body.reden, 'invoer');
});

test('link (token): direct een sessie, ook na 5 foute codes van een ander', () => {
  const { env, db, mails } = nepOmgeving({ helpers: [KIND] });
  versturen(env, { ouderEmail: 'mama@voorbeeld.nl' });
  db.hh_ouder_toestemming[0].set('pogingen', 5);
  const uit = hulp.controleerCode(env, { token: tokenUit(mails), ip: 'a' });
  assert.equal(uit.status, 200);
  assert.ok(uit.body.sessie);
});

test('link: onbekende of oude token geeft 404 link', () => {
  const { env, mails } = nepOmgeving({ helpers: [KIND] });
  versturen(env, { ouderEmail: 'mama@voorbeeld.nl' });
  const oud = tokenUit(mails);
  env.klok += UUR;
  versturen(env);
  const uit = hulp.controleerCode(env, { token: oud, ip: 'a' });
  assert.equal(uit.status, 404);
  assert.equal(uit.body.reden, 'link');
});

test('rate-limit per IP: na 30 verzoeken per uur 429, ander IP gaat door', () => {
  const { env } = nepOmgeving({ helpers: [KIND] });
  for (let i = 0; i < 30; i++) hulp.controleerCode(env, { email: 'x@y.nl', code: '123456', ip: '9.9.9.9' });
  const uit = hulp.controleerCode(env, { email: 'x@y.nl', code: '123456', ip: '9.9.9.9' });
  assert.equal(uit.status, 429);
  assert.equal(uit.body.reden, 'teveel');
  assert.equal(hulp.controleerCode(env, { email: 'x@y.nl', code: '123456', ip: '8.8.8.8' }).body.reden, 'code');
  env.klok += UUR;
  assert.equal(hulp.controleerCode(env, { email: 'x@y.nl', code: '123456', ip: '9.9.9.9' }).body.reden, 'code');
});

// ---- toestemming ----------------------------------------------------------------

function metSessie() {
  const omg = nepOmgeving({ helpers: [KIND] });
  versturen(omg.env, { ouderEmail: 'mama@voorbeeld.nl' });
  const sessie = hulp.controleerCode(omg.env, { token: tokenUit(omg.mails), ip: 'a' }).body.sessie;
  return { ...omg, sessie };
}

test('toestemming: zet ouder_toestemming_op en ouder_iban_ok op de helper', () => {
  const { env, db, sessie } = metSessie();
  const uit = hulp.geefToestemming(env, { sessie, naam: ' Anna Verhoeven ', iban: 'nl91 abna 0417 1643 00', akkoord: true, avp: true, ip: 'a' });
  assert.equal(uit.status, 200, JSON.stringify(uit.body));
  assert.equal(uit.body.status, 'gegeven');
  assert.equal(uit.body.avp, true);
  const rij = db.hh_ouder_toestemming[0];
  assert.equal(rij.get('status'), 'gegeven');
  assert.equal(rij.get('ouder_naam'), 'Anna Verhoeven');
  assert.equal(rij.get('iban'), 'NL91ABNA0417164300');
  assert.equal(rij.get('avp_verklaard'), true);
  assert.equal(rij.get('code_hash'), '');
  assert.ok(rij.get('gegeven_op'));
  const helper = db.hh_users[0];
  assert.equal(helper.get('ouder_toestemming_op'), rij.get('gegeven_op'));
  assert.equal(helper.get('ouder_iban_ok'), true);
});

test('toestemming: akkoord verplicht, naam en IBAN gecontroleerd, AVP mag nee', () => {
  const { env, db, sessie } = metSessie();
  const basis = { sessie, naam: 'Anna', iban: 'NL91ABNA0417164300', akkoord: true, avp: false, ip: 'a' };
  assert.equal(hulp.geefToestemming(env, { ...basis, akkoord: false }).body.reden, 'akkoord');
  assert.equal(hulp.geefToestemming(env, { ...basis, akkoord: 'ja' }).body.reden, 'akkoord');
  assert.equal(hulp.geefToestemming(env, { ...basis, naam: 'A' }).body.reden, 'naam');
  assert.equal(hulp.geefToestemming(env, { ...basis, iban: 'NL91ABNA0417164301' }).body.reden, 'iban');
  assert.equal(db.hh_users[0].get('ouder_toestemming_op'), '');
  const goed = hulp.geefToestemming(env, basis);
  assert.equal(goed.status, 200);
  assert.equal(db.hh_ouder_toestemming[0].get('avp_verklaard'), false);
});

test('toestemming: zonder of met verlopen sessie 401', () => {
  const { env, sessie } = metSessie();
  const basis = { naam: 'Anna', iban: 'NL91ABNA0417164300', akkoord: true, avp: false, ip: 'a' };
  assert.equal(hulp.geefToestemming(env, { ...basis, sessie: 'onzin' }).status, 401);
  assert.equal(hulp.geefToestemming(env, { ...basis, sessie: '' }).status, 401);
  env.klok += 31 * 60 * 1000;
  const uit = hulp.geefToestemming(env, { ...basis, sessie });
  assert.equal(uit.status, 401);
  assert.equal(uit.body.reden, 'sessie');
});

test('link na toestemming: status gegeven, geen nieuwe sessie nodig', () => {
  const { env, mails, sessie } = metSessie();
  hulp.geefToestemming(env, { sessie, naam: 'Anna', iban: 'NL91ABNA0417164300', akkoord: true, avp: true, ip: 'a' });
  const uit = hulp.controleerCode(env, { token: tokenUit(mails), ip: 'a' });
  assert.equal(uit.status, 200);
  assert.equal(uit.body.status, 'gegeven');
  assert.equal(uit.body.avp, true);
  assert.equal(uit.body.sessie, undefined);
});

// ---- intrekken -------------------------------------------------------------------

test('intrekken met de link: wist het veld op de helper en mailt de ouder', () => {
  const { env, db, mails, sessie } = metSessie();
  hulp.geefToestemming(env, { sessie, naam: 'Anna', iban: 'NL91ABNA0417164300', akkoord: true, avp: true, ip: 'a' });
  env.klok += 90 * 24 * UUR; // de link blijft altijd geldig
  const uit = hulp.trekIn(env, { token: tokenUit(mails.slice(0, 1)), ip: 'a' });
  assert.equal(uit.status, 200, JSON.stringify(uit.body));
  assert.equal(uit.body.status, 'ingetrokken');
  const helper = db.hh_users[0];
  assert.equal(helper.get('ouder_toestemming_op'), '');
  assert.equal(helper.get('ouder_iban_ok'), false);
  const rij = db.hh_ouder_toestemming[0];
  assert.equal(rij.get('status'), 'ingetrokken');
  assert.ok(rij.get('ingetrokken_op'));
  assert.equal(rij.get('sessie_hash'), '');
  assert.match(mails.at(-1).onderwerp, /ingetrokken/);
  assert.equal(mails.at(-1).aan, 'mama@voorbeeld.nl');
  // Nog een keer: zelfde uitkomst, geen tweede mail.
  const aantal = mails.length;
  assert.equal(hulp.trekIn(env, { token: tokenUit(mails.slice(0, 1)), ip: 'a' }).body.status, 'ingetrokken');
  assert.equal(mails.length, aantal);
});

test('intrekken met de sessie (ouder kwam via de code) kan ook', () => {
  const { env, db, sessie } = metSessie();
  hulp.geefToestemming(env, { sessie, naam: 'Anna', iban: 'NL91ABNA0417164300', akkoord: true, avp: false, ip: 'a' });
  assert.equal(hulp.trekIn(env, { sessie, ip: 'a' }).status, 200);
  assert.equal(db.hh_users[0].get('ouder_toestemming_op'), '');
});

test('intrekken vóór toestemming: de code vervalt, niets op de helper', () => {
  const { env, db, mails } = metSessie();
  const uit = hulp.trekIn(env, { token: tokenUit(mails), ip: 'a' });
  assert.equal(uit.status, 200);
  assert.equal(db.hh_ouder_toestemming[0].get('code_hash'), '');
  assert.equal(db.hh_ouder_toestemming[0].get('status'), 'ingetrokken');
});

test('intrekken: mail mislukt telt niet, het intrekken gaat door', () => {
  const omg = metSessie();
  omg.env.mail = () => { throw new Error('smtp weg'); };
  assert.equal(omg.env.mail === undefined, false);
  const uit = hulp.trekIn(omg.env, { token: tokenUit(omg.mails), ip: 'a' });
  assert.equal(uit.status, 200);
});

test('intrekken: onbekende link 404, geen link en geen sessie 400', () => {
  const { env } = metSessie();
  assert.equal(hulp.trekIn(env, { token: 'onzin', ip: 'a' }).status, 404);
  assert.equal(hulp.trekIn(env, { ip: 'a' }).status, 400);
});

// ---- status voor de app --------------------------------------------------------

test('status voor de helper: geen -> verstuurd -> gegeven -> ingetrokken; nooit hashes', () => {
  const { env, db, mails } = nepOmgeving({ helpers: [KIND] });
  const helper = () => db.hh_users[0];
  assert.equal(hulp.statusVoorHelper(env, { helper: helper(), leeftijd: 14 }).body.status, 'geen');
  versturen(env, { ouderEmail: 'mama@voorbeeld.nl' });
  let s = hulp.statusVoorHelper(env, { helper: helper(), leeftijd: 14 }).body;
  assert.equal(s.status, 'verstuurd');
  assert.equal(s.ouder_email, 'mama@voorbeeld.nl');
  assert.equal(s.nog_te_sturen, 2);
  assert.equal(s.nodig, true);
  for (const k of Object.keys(s)) assert.ok(!/hash|code$|token|sessie|iban/.test(k), k);
  const sessie = hulp.controleerCode(env, { token: tokenUit(mails), ip: 'a' }).body.sessie;
  hulp.geefToestemming(env, { sessie, naam: 'Anna', iban: 'NL91ABNA0417164300', akkoord: true, avp: true, ip: 'a' });
  assert.equal(hulp.statusVoorHelper(env, { helper: helper(), leeftijd: 14 }).body.status, 'gegeven');
  hulp.trekIn(env, { token: tokenUit(mails), ip: 'a' });
  assert.equal(hulp.statusVoorHelper(env, { helper: helper(), leeftijd: 14 }).body.status, 'ingetrokken');
  assert.equal(hulp.statusVoorHelper(env, { helper: helper(), leeftijd: 19 }).body.nodig, false);
});

test('status: na 5 foute codes geblokkeerd, na 24 uur verlopen', () => {
  const { env, db } = nepOmgeving({ helpers: [KIND] });
  versturen(env, { ouderEmail: 'mama@voorbeeld.nl' });
  db.hh_ouder_toestemming[0].set('pogingen', 5);
  assert.equal(hulp.statusVoorHelper(env, { helper: db.hh_users[0], leeftijd: 14 }).body.geblokkeerd, true);
  env.klok += 25 * UUR;
  assert.equal(hulp.statusVoorHelper(env, { helper: db.hh_users[0], leeftijd: 14 }).body.status, 'verlopen');
});

// ---- de echte omgeving ---------------------------------------------------------

test('jsvmOmgeving: mail met de afzender uit de serverinstellingen, verder $security', () => {
  const verstuurd = [];
  const app = {
    settings: () => ({ meta: { senderAddress: 'info@bovexa.nl', senderName: 'QawayahBase' } }),
    newMailClient: () => ({ send: (m) => verstuurd.push(m) }),
    store: () => ({ get() {}, set() {} }),
  };
  function MailerMessage(m) { Object.assign(this, m); }
  const security = {
    randomStringWithAlphabet: (n, a) => a[0].repeat(n),
    sha256: (s) => `sha(${s})`,
    equal: (a, b) => a === b,
  };
  const env = hulp.jsvmOmgeving({ app, Record: function () {}, security, MailerMessage });
  env.mail({ aan: 'mama@voorbeeld.nl', onderwerp: 'O', tekst: 'T', html: 'H' });
  assert.equal(verstuurd.length, 1);
  assert.deepEqual(verstuurd[0].from, { address: 'info@bovexa.nl', name: 'QawayahBase' });
  assert.deepEqual(verstuurd[0].to, [{ address: 'mama@voorbeeld.nl' }]);
  assert.equal(verstuurd[0].subject, 'O');
  assert.equal(verstuurd[0].text, 'T');
  assert.equal(env.willekeurig(6, hulp.CIJFERS), '000000');
  assert.equal(env.sha256('x'), 'sha(x)');
  assert.equal(env.gelijk('a', 'a'), true);
});
