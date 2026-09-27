// HeitjeHulp M8 — test van backend/pb_hooks/hh_meldingen_hulp.js zonder
// server. Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs
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
const bron = readFileSync(path.join(hier, '..', 'pb_hooks', 'hh_meldingen_hulp.js'), 'utf8');
const module_ = { exports: {} };
new Function('module', 'exports', bron)(module_, module_.exports);
const hulp = module_.exports;

// ---- Nederlandse tijd -------------------------------------------------------

test('zomertijd: 08:00 UTC op 15 september is 10:00 in Nederland', () => {
  assert.equal(hulp.wanneerTekst('2026-09-15 08:00:00.000Z'), 'dinsdag 15 september om 10:00');
});

test('wintertijd: 09:30 UTC op 10 december is 10:30 in Nederland', () => {
  assert.equal(hulp.wanneerTekst('2026-12-10T09:30:00Z'), 'donderdag 10 december om 10:30');
});

test('de wissel: 29 maart 2026 01:00 UTC gaat de zomertijd in', () => {
  assert.equal(hulp.nederlandseTijd(Date.UTC(2026, 2, 29, 0, 59)).uur, 1);
  assert.equal(hulp.nederlandseTijd(Date.UTC(2026, 2, 29, 1, 0)).uur, 3);
  // 25 oktober 2026 01:00 UTC terug naar wintertijd.
  assert.equal(hulp.nederlandseTijd(Date.UTC(2026, 9, 25, 0, 59)).uur, 2);
  assert.equal(hulp.nederlandseTijd(Date.UTC(2026, 9, 25, 1, 0)).uur, 2);
});

test('zonder of met een onzinnige datum: lege tekst', () => {
  assert.equal(hulp.wanneerTekst(''), '');
  assert.equal(hulp.wanneerTekst(null), '');
  assert.equal(hulp.wanneerTekst('geen datum'), '');
});

// ---- Wie krijgt wat ---------------------------------------------------------

const KLUS = { hulpvrager: 'o1', geplaatst_door: 'o1', toegewezen_jongere: 'j1' };
const namen = (lijst) => lijst.map((o) => `${o.ontvanger}:${o.soort}`).sort();

test('geaccepteerd -> de oudere, en geplaatst_door als dat iemand anders is', () => {
  assert.deepEqual(namen(hulp.ontvangersVoorWissel(KLUS, { van: 'open', naar: 'geaccepteerd', door: 'j1' })), ['o1:toegewezen']);
  const doorFamilie = { ...KLUS, geplaatst_door: 'f1' };
  const lijst = hulp.ontvangersVoorWissel(doorFamilie, { van: 'open', naar: 'geaccepteerd', door: 'j1' });
  assert.deepEqual(namen(lijst), ['f1:toegewezen', 'o1:toegewezen']);
  assert.equal(lijst.find((o) => o.ontvanger === 'f1').rol, 'familie');
});

test('onderweg -> de oudere; afgerond -> oudere en jongere', () => {
  assert.deepEqual(namen(hulp.ontvangersVoorWissel(KLUS, { van: 'geaccepteerd', naar: 'onderweg', door: 'j1' })), ['o1:onderweg']);
  assert.deepEqual(namen(hulp.ontvangersVoorWissel(KLUS, { van: 'bezig', naar: 'afgerond', door: 'j1' })), ['j1:afgerond', 'o1:afgerond']);
});

test('bezig -> niemand (de oudere ziet de jongere al staan)', () => {
  assert.deepEqual(hulp.ontvangersVoorWissel(KLUS, { van: 'onderweg', naar: 'bezig', door: 'j1' }), []);
});

test('geannuleerd -> de ANDERE deelnemer; door de coordinator -> beide', () => {
  assert.deepEqual(namen(hulp.ontvangersVoorWissel(KLUS, { van: 'geaccepteerd', naar: 'geannuleerd', door: 'o1' })), ['j1:geannuleerd']);
  assert.deepEqual(
    namen(hulp.ontvangersVoorWissel(KLUS, { van: 'geaccepteerd', naar: 'geannuleerd', door: 'c1' })),
    ['j1:geannuleerd', 'o1:geannuleerd'],
  );
  // Open klus zonder jongere, geannuleerd door de oudere: niemand.
  assert.deepEqual(
    hulp.ontvangersVoorWissel({ ...KLUS, toegewezen_jongere: '' }, { van: 'open', naar: 'geannuleerd', door: 'o1' }),
    [],
  );
});

test('terug naar open na teruggeven -> de oudere, gemarkeerd als teruggegeven', () => {
  const vrij = { ...KLUS, toegewezen_jongere: '' };
  const lijst = hulp.ontvangersVoorWissel(vrij, { van: 'onderweg', naar: 'open', door: 'j1' });
  assert.deepEqual(namen(lijst), ['o1:geannuleerd']);
  assert.equal(lijst[0].teruggegeven, true);
  // Een klus die vers open gaat: geen melding aan de oudere zelf.
  assert.deepEqual(hulp.ontvangersVoorWissel(vrij, { van: '', naar: 'open', door: 'o1' }), []);
  assert.deepEqual(hulp.ontvangersVoorWissel(vrij, { van: 'concept', naar: 'open', door: 'o1' }), []);
});

test('nieuwe klus voor de wijk alleen bij naar = open', () => {
  assert.equal(hulp.isNieuweOpenKlus({ van: '', naar: 'open' }), true);
  assert.equal(hulp.isNieuweOpenKlus({ van: 'geaccepteerd', naar: 'open' }), true);
  assert.equal(hulp.isNieuweOpenKlus({ van: '', naar: 'concept' }), false);
  assert.equal(hulp.isNieuweOpenKlus({ van: 'open', naar: 'geaccepteerd' }), false);
});

// ---- Teksten per soort en rol ----------------------------------------------

const CTX = { jongere: 'Sanne', oudere: 'Mevrouw de Vries', klussoort: 'boodschappen', wanneer: 'dinsdag 15 september om 10:00' };

test('de oudere krijgt u en de voornaam van de jongere', () => {
  assert.equal(hulp.tekstVoor('toegewezen', 'hulpvrager', CTX).tekst, 'Sanne komt dinsdag 15 september om 10:00.');
  assert.equal(hulp.tekstVoor('onderweg', 'hulpvrager', CTX).tekst, 'Sanne is onderweg naar u.');
  assert.equal(hulp.tekstVoor('afgerond', 'hulpvrager', CTX).tekst, 'Sanne heeft de klus gedaan.');
  assert.match(hulp.tekstVoor('geannuleerd', 'hulpvrager', { ...CTX, teruggegeven: true }).tekst, /^Sanne kan toch niet komen\. .* voor u\.$/);
  assert.equal(hulp.tekstVoor('geannuleerd', 'hulpvrager', CTX).tekst, 'Uw hulpvraag gaat niet door.');
});

test('de jongere krijgt je', () => {
  assert.deepEqual(hulp.tekstVoor('nieuwe_klus', 'jongere', CTX), {
    titel: 'Nieuwe klus in je buurt',
    tekst: 'Boodschappen dinsdag 15 september om 10:00.',
  });
  assert.match(hulp.tekstVoor('afgerond', 'jongere', CTX).tekst, /^Bedankt voor je hulp\./);
  assert.equal(hulp.tekstVoor('geannuleerd', 'jongere', CTX).tekst, 'Boodschappen dinsdag 15 september om 10:00 gaat niet door.');
});

test('familie en coordinator bij een incident', () => {
  const nood = { incidentSoort: 'nood', melder: 'Mevrouw de Vries', omschrijving: '' };
  assert.deepEqual(hulp.tekstVoor('incident', 'coordinator', nood), {
    titel: 'Noodmelding',
    tekst: 'Mevrouw de Vries heeft op de noodknop gedrukt.',
  });
  assert.match(hulp.tekstVoor('incident', 'familie', nood).tekst, /noodknop/);
  const probleem = { incidentSoort: 'probleem', melder: 'Sanne Bakker', omschrijving: 'Niemand deed open' };
  assert.deepEqual(hulp.tekstVoor('incident', 'coordinator', probleem), {
    titel: 'Probleem gemeld',
    tekst: 'Sanne Bakker: Niemand deed open',
  });
});

test('zonder naam of datum blijft de zin heel', () => {
  assert.equal(hulp.tekstVoor('toegewezen', 'hulpvrager', {}).tekst, 'Iemand heeft uw hulpvraag aangenomen.');
  assert.equal(hulp.tekstVoor('nieuwe_klus', 'jongere', {}).tekst, 'Een klus.');
  assert.equal(hulp.voornaam('  Sanne  Bakker '), 'Sanne');
});

// ---- Idempotent aanmaken en de hele wissel, met een nep-app -----------------

function nepServer() {
  const rec = (collectie, velden) => ({
    id: velden.id,
    collectie,
    velden: { ...velden },
    get(k) { return this.velden[k]; },
    set(k, v) { this.velden[k] = v; },
  });
  const db = {
    hh_users: [
      rec('hh_users', { id: 'o1', rol: 'hulpvrager', naam: 'Mevrouw A. de Vries', wijk: 'w1' }),
      rec('hh_users', { id: 'j1', rol: 'jongere', naam: 'Yusuf el Amrani', wijk: 'w1' }),
      rec('hh_users', { id: 'j2', rol: 'jongere', naam: 'Sanne Bakker', wijk: 'w1' }),
      rec('hh_users', { id: 'c1', rol: 'coordinator', naam: 'Meldkamer' }),
      rec('hh_users', { id: 'c2', rol: 'coordinator', naam: 'Meldkamer 2' }),
      rec('hh_users', { id: 'f1', rol: 'familie', naam: 'Karin de Vries' }),
    ],
    hh_klussen: [
      rec('hh_klussen', { id: 'k1', hulpvrager: 'o1', geplaatst_door: 'o1', toegewezen_jongere: 'j1', klustype: 't1', wanneer_van: '2026-09-15 08:00:00.000Z' }),
    ],
    hh_klustypes: [rec('hh_klustypes', { id: 't1', naam: 'boodschappen' })],
    hh_profielen: [
      rec('hh_profielen', { id: 'p1', gebruiker: 'j1', verificatiestatus: 'goedgekeurd' }),
      rec('hh_profielen', { id: 'p2', gebruiker: 'j2', verificatiestatus: 'goedgekeurd' }),
    ],
    hh_koppelingen: [rec('hh_koppelingen', { id: 'kp1', oudere: 'o1', familielid: 'f1' })],
    hh_meldingen: [],
  };
  let volgnummer = 0;
  const vind = (c, id) => db[c].find((r) => r.id === id);
  const app = {
    findRecordById(c, id) {
      const r = vind(c, id);
      if (!r) throw new Error('niet gevonden');
      return r;
    },
    findFirstRecordByFilter(c, _filter, p) {
      const r = db[c].find((x) => x.get('ontvanger') === p.ontvanger && x.get('soort') === p.soort && x.get('sleutel') === p.sleutel);
      if (!r) throw new Error('niet gevonden');
      return r;
    },
    findRecordsByFilter(c, _filter, _sort, _limit, _offset, p) {
      if (c === 'hh_users') return db.hh_users.filter((u) => u.get('rol') === 'coordinator');
      if (c === 'hh_koppelingen') return db.hh_koppelingen.filter((k) => k.get('oudere') === p.oudere);
      if (c === 'hh_profielen') {
        return db.hh_profielen.filter((pr) => {
          const u = vind('hh_users', pr.get('gebruiker'));
          return pr.get('verificatiestatus') === 'goedgekeurd' && u.get('rol') === 'jongere' && u.get('wijk') === p.wijk;
        });
      }
      return [];
    },
    findCollectionByNameOrId: (naam) => naam,
    save(r) {
      if (!r.id) r.id = `m${++volgnummer}`;
      db[r.collectie].push(r);
    },
  };
  function Record(collectie) {
    return rec(collectie, {});
  }
  return { db, env: { app, Record }, log: (id, van, naar, door) => rec('hh_klus_status', { id, klus: 'k1', van, naar, door }) };
}

test('verwerkWissel: afgerond geeft twee meldingen, nog een keer geeft er nul', () => {
  const s = nepServer();
  const log = s.log('l1', 'bezig', 'afgerond', 'j1');
  assert.equal(hulp.verwerkWissel(s.env, log), 2);
  assert.equal(hulp.verwerkWissel(s.env, log), 0);
  const oudere = s.db.hh_meldingen.find((m) => m.get('ontvanger') === 'o1');
  assert.equal(oudere.get('soort'), 'afgerond');
  assert.equal(oudere.get('klus'), 'k1');
  assert.equal(oudere.get('sleutel'), 'klusstatus:l1');
  assert.equal(oudere.get('tekst'), 'Yusuf heeft de klus gedaan.');
});

test('verwerkWissel: geaccepteerd noemt de tijd in Nederlandse tijd', () => {
  const s = nepServer();
  hulp.verwerkWissel(s.env, s.log('l2', 'open', 'geaccepteerd', 'j1'));
  assert.equal(s.db.hh_meldingen.length, 1);
  assert.equal(s.db.hh_meldingen[0].get('tekst'), 'Yusuf komt dinsdag 15 september om 10:00.');
});

test('verwerkWissel: terug naar open -> oudere + de ANDERE jongeren in de wijk', () => {
  const s = nepServer();
  s.db.hh_klussen[0].set('toegewezen_jongere', '');
  const aantal = hulp.verwerkWissel(s.env, s.log('l3', 'geaccepteerd', 'open', 'j1'));
  assert.equal(aantal, 2);
  const soorten = s.db.hh_meldingen.map((m) => `${m.get('ontvanger')}:${m.get('soort')}`).sort();
  assert.deepEqual(soorten, ['j2:nieuwe_klus', 'o1:geannuleerd']);
  const oudere = s.db.hh_meldingen.find((m) => m.get('ontvanger') === 'o1');
  assert.match(oudere.get('tekst'), /^Yusuf kan toch niet komen\./);
});

test('verwerkWissel: een onbekende klus doet niets', () => {
  const s = nepServer();
  const log = s.log('l4', 'bezig', 'afgerond', 'j1');
  log.set('klus', 'bestaat-niet');
  assert.equal(hulp.verwerkWissel(s.env, log), 0);
});

test('verwerkIncident: nood -> elke coordinator en het familielid, één keer', () => {
  const s = nepServer();
  const rec = { id: 'i1', velden: { soort: 'nood', melder: 'o1', klus: '', omschrijving: '' }, get(k) { return this.velden[k]; } };
  assert.equal(hulp.verwerkIncident(s.env, rec), 3);
  assert.equal(hulp.verwerkIncident(s.env, rec), 0);
  const ontvangers = s.db.hh_meldingen.map((m) => m.get('ontvanger')).sort();
  assert.deepEqual(ontvangers, ['c1', 'c2', 'f1']);
  assert.ok(s.db.hh_meldingen.every((m) => m.get('incident') === 'i1' && m.get('soort') === 'incident'));
});

test('verwerkIncident: probleem -> alleen de coordinatoren', () => {
  const s = nepServer();
  const rec = { id: 'i2', velden: { soort: 'probleem', melder: 'j1', klus: 'k1', omschrijving: 'Niemand deed open' }, get(k) { return this.velden[k]; } };
  assert.equal(hulp.verwerkIncident(s.env, rec), 2);
  assert.equal(s.db.hh_meldingen[0].get('klus'), 'k1');
  assert.equal(s.db.hh_meldingen[0].get('tekst'), 'Yusuf el Amrani: Niemand deed open');
});
