// HeitjeHulp B5 — hh_reacties_hulp.js zonder server: reageren, ouder keurt
// per klus, kiezen (match), intrekken, meldingen, "Ik kan nu helpen",
// geheime vraag. De nep-app (tests/_nep_app.mjs) houdt records in het
// geheugen; de echte rules en PocketBase bewijst 132-b5check.mjs.
// Draaien (vanuit de repo-root): node --test backend/tests/*.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { laadHulp, nepApp, NepRecord, pbDatum } from './_nep_app.mjs';

const hulp = laadHulp('hh_reacties_hulp.js');
const DEP = {
  aanmelden: laadHulp('hh_aanmelden_hulp.js'),
  plaatsen: laadHulp('hh_klusplaatsen_hulp.js'),
  meldingen: laadHulp('hh_meldingen_hulp.js'),
  chat: laadHulp('hh_chat_hulp.js'),
  teksten: laadHulp('hh_reacties_teksten.js'),
};

// Zaterdag 4 oktober 2026, 10:00 UTC (12:00 NL).
const NU = Date.parse('2026-10-04T10:00:00Z');
const UUR = 3600 * 1000;
// Zaterdag 10 oktober 10:00-11:00 NL (zomertijd: 08:00-09:00 UTC).
const VAN = '2026-10-10 08:00:00.000Z';
const TOT = '2026-10-10 09:00:00.000Z';

function wereld(extra = {}) {
  const rijen = {
    hh_wijken: [{ id: 'w-tiel', gemeente: 'Tiel', wijk: 'Tiel en omstreken', regio: true }, { id: 'w-ams', gemeente: 'Amsterdam', wijk: 'Centrum', regio: false }],
    hh_klustypes: [
      { id: 't-licht', naam: 'Boodschappen', min_leeftijd: 10 },
      { id: 't-tuin', naam: 'Tuin', min_leeftijd: 13 },
    ],
    hh_users: [
      { id: 'b1', rol: 'hulpvrager', naam: 'Anja de Vries', wijk: 'w-tiel', adres: 'Kerkstraat 1, 4001 MA Tiel', plaats: 'Tiel' },
      { id: 'b2', rol: 'hulpvrager', naam: 'Kees Bakker', wijk: 'w-tiel' },
      { id: 'h25', rol: 'jongere', naam: 'Ruud Jansen', wijk: 'w-tiel', geboortedatum: '2001-01-01 00:00:00.000Z', sterren_gemiddeld: 4.6 },
      { id: 'h30', rol: 'jongere', naam: 'Sanne Smit', wijk: 'w-tiel', geboortedatum: '1996-05-05 00:00:00.000Z' },
      { id: 'h14', rol: 'jongere', naam: 'Daan Mulder', wijk: 'w-tiel', geboortedatum: '2012-03-01 00:00:00.000Z', ouder_toestemming_op: '2026-09-01 10:00:00.000Z', ouder_email: 'ouder.daan@voorbeeld.nl' },
      { id: 'h11', rol: 'jongere', naam: 'Lisa Kok', wijk: 'w-tiel', geboortedatum: '2015-01-15 00:00:00.000Z', ouder_toestemming_op: '2026-09-01 10:00:00.000Z', ouder_email: 'ouder.lisa@voorbeeld.nl' },
      { id: 'h14z', rol: 'jongere', naam: 'Tom Zonder', wijk: 'w-tiel', geboortedatum: '2012-03-01 00:00:00.000Z' },
      { id: 'hams', rol: 'jongere', naam: 'Ali Ams', wijk: 'w-ams', geboortedatum: '2000-01-01 00:00:00.000Z' },
      { id: 'coord', rol: 'coordinator', naam: 'Meldkamer' },
    ],
    hh_profielen: [
      { id: 'p25', gebruiker: 'h25', verificatiestatus: 'goedgekeurd', vog_gezien_op: '2026-09-01 10:00:00.000Z', id_gecontroleerd_op: '2026-09-01 10:00:00.000Z' },
      { id: 'p30', gebruiker: 'h30', verificatiestatus: 'goedgekeurd', vog_gezien_op: '2026-09-01 10:00:00.000Z' },
      { id: 'p14', gebruiker: 'h14', verificatiestatus: 'goedgekeurd', id_gecontroleerd_op: '2026-09-02 10:00:00.000Z' },
      { id: 'p11', gebruiker: 'h11', verificatiestatus: 'goedgekeurd' },
      { id: 'p14z', gebruiker: 'h14z', verificatiestatus: 'goedgekeurd' },
      { id: 'pams', gebruiker: 'hams', verificatiestatus: 'goedgekeurd', vog_gezien_op: '2026-09-01 10:00:00.000Z' },
    ],
    hh_klussen: [
      {
        id: 'k1', hulpvrager: 'b1', geplaatst_door: 'b1', klustype: 't-licht', status: 'open', toegewezen_jongere: '',
        klus_goedgekeurd_op: '2026-10-03 10:00:00.000Z', wanneer_van: VAN, wanneer_tot: TOT,
        adres: 'Kerkstraat 1, 4001 MA Tiel', omschrijving: 'Boodschappen bij de Jumbo halen.',
      },
      {
        id: 'k2', hulpvrager: 'b2', geplaatst_door: 'b2', klustype: 't-licht', status: 'open', toegewezen_jongere: '',
        klus_goedgekeurd_op: '2026-10-03 10:00:00.000Z', wanneer_van: '2026-10-10 08:30:00.000Z', wanneer_tot: '2026-10-10 09:30:00.000Z',
        adres: 'Dorpsstraat 5, 4005 AB Tiel', omschrijving: 'Tas dragen.',
      },
      {
        id: 'ktuin', hulpvrager: 'b1', geplaatst_door: 'b1', klustype: 't-tuin', status: 'open', toegewezen_jongere: '',
        klus_goedgekeurd_op: '2026-10-03 10:00:00.000Z', wanneer_van: '2026-10-11 08:00:00.000Z', wanneer_tot: '2026-10-11 09:00:00.000Z',
        adres: 'Kerkstraat 1, 4001 MA Tiel', omschrijving: 'Heg knippen.',
      },
      { id: 'kongekeurd', hulpvrager: 'b1', klustype: 't-licht', status: 'open', toegewezen_jongere: '', wanneer_van: VAN },
      { id: 'kbezet', hulpvrager: 'b1', klustype: 't-licht', status: 'geaccepteerd', toegewezen_jongere: 'h30', klus_goedgekeurd_op: '2026-10-03 10:00:00.000Z', wanneer_van: VAN },
      { id: 'kbegonnen', hulpvrager: 'b1', klustype: 't-licht', status: 'open', toegewezen_jongere: '', klus_goedgekeurd_op: '2026-10-03 10:00:00.000Z', wanneer_van: pbDatum(NU - UUR) },
    ],
    hh_ouder_toestemming: [{ id: 'ot14', helper: 'h14', ouder_email: 'ouder.daan@voorbeeld.nl', status: 'gegeven' }],
    hh_reacties: [],
    hh_meldingen: [],
    hh_klus_status: [],
    hh_beoordelingen: [],
    hh_incidenten: [],
    // Antwoord Ibrahim 5: helpers onder 18 pas als de site online is. De
    // meeste tests draaien met de schakelaar AAN; zie de test "onder 18 dicht".
    hh_instellingen: [{ id: 'i-o18', sleutel: 'b5_onder18_reageren_open', waarde: true }],
  };
  for (const [k, v] of Object.entries(extra)) rijen[k] = [...(rijen[k] || []), ...v];
  return rijen;
}

function omgeving(rijen = wereld(), nu = NU) {
  const app = nepApp(rijen, { klok: () => nu });
  const mails = [];
  const store = new Map();
  let n = 0;
  const env = {
    app,
    Record: NepRecord,
    nu: () => nu,
    willekeurig: (lengte) => String(++n).padStart(lengte, 't'),
    sha256: (tekst) => `sha(${tekst})`,
    mail: (m) => {
      if (env.mailFout) throw new Error('smtp weg');
      mails.push(m);
    },
    store: { get: (k) => store.get(k), set: (k, v) => store.set(k, v) },
    log: () => {},
    dep: DEP,
    mails,
  };
  return env;
}

const rec = (env, col, id) => env.app.findRecordById(col, id);
const reacties = (env) => env.app.db.hh_reacties || [];
const meldingenVan = (env, ontvanger) => (env.app.db.hh_meldingen || []).filter((m) => m.get('ontvanger') === ontvanger);
const reageer = (env, helperId, klusId, extra = {}) =>
  hulp.reageer(env, { helper: rec(env, 'hh_users', helperId), klusId, bericht: '', ouderGaatMee: false, ...extra });
const tokenUitMail = (mail) => /token=([A-Za-z0-9]+)/.exec(mail.tekst)[1];

// ---------------------------------------------------------------- puur

test('schoonBericht: max 200 tekens, nummers/mail/links worden •••', () => {
  const f = DEP.chat.filterTekst;
  assert.deepEqual(hulp.schoonBericht('  Ik heb al vaker tuinen gedaan.  ', f), { ok: true, tekst: 'Ik heb al vaker tuinen gedaan.', gefilterd: false });
  const nr = hulp.schoonBericht('Bel me op 06-12345678', f);
  assert.equal(nr.ok, true);
  assert.equal(nr.tekst, 'Bel me op •••');
  assert.equal(nr.gefilterd, true);
  assert.equal(hulp.schoonBericht('x'.repeat(200), f).ok, true);
  assert.equal(hulp.schoonBericht('x'.repeat(201), f).ok, false);
  assert.deepEqual(hulp.schoonBericht('', f), { ok: true, tekst: '', gefilterd: false });
});

test('waarVoorOuder: straat zonder huisnummer + plaats, anders alleen de plaats', () => {
  assert.equal(hulp.waarVoorOuder('Kerkstraat 1, 4001 MA Tiel', ''), 'Kerkstraat, Tiel');
  assert.equal(hulp.waarVoorOuder('Nieuwe Tielseweg 1a-01, 4001 JS Tiel', ''), 'Nieuwe Tielseweg, Tiel');
  assert.equal(hulp.waarVoorOuder('Dorpsstraat 12', 'Ochten'), 'Dorpsstraat, Ochten');
  assert.equal(hulp.waarVoorOuder('', 'Tiel'), 'Tiel');
  assert.equal(hulp.waarVoorOuder('', ''), '');
  assert.ok(!/\d/.test(hulp.waarVoorOuder('Kerkstraat 1, 4001 MA Tiel', '')), 'geen huisnummer of postcode');
});

test('overlapt: tijdvakken (zonder eindtijd 2 uur), zonder begintijd nooit', () => {
  assert.equal(hulp.overlapt({ van: VAN, tot: TOT }, { van: '2026-10-10 08:30:00.000Z', tot: '' }), true);
  assert.equal(hulp.overlapt({ van: VAN, tot: TOT }, { van: TOT, tot: '2026-10-10 10:00:00.000Z' }), false, 'aansluitend mag');
  assert.equal(hulp.overlapt({ van: VAN, tot: '' }, { van: '2026-10-10 09:59:00.000Z', tot: '' }), true, 'zonder eind: 2 uur');
  assert.equal(hulp.overlapt({ van: '', tot: '' }, { van: VAN, tot: TOT }), false);
});

test('instellingAan: alleen waarde true (ook als json-tekst), anders uit', () => {
  const env = omgeving(wereld({ hh_instellingen: [{ id: 'i1', sleutel: hulp.INSTELLING_ACCEPTEREN_DICHT, waarde: true }, { id: 'i2', sleutel: 'x', waarde: 'true' }] }));
  assert.equal(hulp.instellingAan(env.app, hulp.INSTELLING_ACCEPTEREN_DICHT), true);
  assert.equal(hulp.instellingAan(env.app, 'x'), false, 'de tekst "true" (json-string) is geen true');
  assert.equal(hulp.instellingAan(env.app, hulp.INSTELLING_ALLEEN_BESCHIKBAAR), false, 'zonder rij uit');
  // De JSVM geeft een json-veld als bytes; getString geeft de json-tekst.
  const app2 = omgeving(wereld({ hh_instellingen: [{ id: 'i3', sleutel: 'y', waarde: [116, 114, 117, 101] }] })).app;
  app2.db.hh_instellingen.find((r) => r.get('sleutel') === 'y').getString = () => 'true';
  assert.equal(hulp.instellingAan(app2, 'y'), true);
});

test('zoektOpGeheim: filteren of sorteren op de geheime vraag kan niet', () => {
  assert.equal(hulp.zoektOpGeheim('alles_in_orde = "nee"', ''), true);
  assert.equal(hulp.zoektOpGeheim('', '-geheim_toelichting'), true);
  assert.equal(hulp.zoektOpGeheim('klus = "x"', '-created'), false);
});

// ---------------------------------------------------------------- reageren

test('reageren 18+: reactie open, klus blijft open, bewoner krijgt één (gebundelde) melding', () => {
  const env = omgeving();
  const uit = reageer(env, 'h25', 'k1', { bericht: 'Ik heb een fiets met tassen. Bel 0612345678' });
  assert.equal(uit.status, 200, JSON.stringify(uit.body));
  assert.equal(uit.body.status, 'open');
  assert.equal(uit.body.melding, DEP.teksten.MELDING.verstuurd);
  const r = reacties(env)[0];
  assert.equal(r.get('status'), 'open');
  assert.equal(r.get('helper'), 'h25');
  assert.equal(r.get('bericht'), 'Ik heb een fiets met tassen. Bel •••');
  assert.equal(r.get('bericht_gefilterd'), true);
  assert.ok(String(r.get('klus_samenvatting')).startsWith('Boodschappen'), r.get('klus_samenvatting'));
  assert.equal(rec(env, 'hh_klussen', 'k1').get('status'), 'open', 'klus blijft OPEN');
  assert.equal(rec(env, 'hh_klussen', 'k1').get('toegewezen_jongere'), '');
  const m = meldingenVan(env, 'b1');
  assert.equal(m.length, 1);
  assert.equal(m[0].get('soort'), 'reactie');
  assert.equal(m[0].get('titel'), 'Ruud wil je helpen');
  assert.equal(env.mails.length, 0, '18+: geen ouder-mail');

  // Tweede helper: dezelfde (ongelezen) melding wordt bijgewerkt, geen tweede.
  assert.equal(reageer(env, 'h30', 'k1').status, 200);
  const m2 = meldingenVan(env, 'b1');
  assert.equal(m2.length, 1, 'gebundeld');
  assert.equal(m2[0].get('titel'), 'Sanne en Ruud willen je helpen');
  // Gelezen? Dan komt er bij de volgende een nieuwe.
  m2[0].set('gelezen_op', pbDatum(NU));
  assert.equal(reageer(env, 'h14', 'k1').status, 200);
  assert.equal(meldingenVan(env, 'b1').length, 1, 'helper onder 18: bewoner ziet hem pas na de ouder');
});

test('reageren: nog eens 409, na intrekken mag het weer (zelfde rij)', () => {
  const env = omgeving();
  assert.equal(reageer(env, 'h25', 'k1').status, 200);
  const twee = reageer(env, 'h25', 'k1');
  assert.equal(twee.status, 409);
  assert.equal(twee.body.reden, 'algereageerd');
  const id = reacties(env)[0].id;
  assert.equal(hulp.trekIn(env, { helperId: 'h25', reactieId: id }).status, 200);
  assert.equal(reacties(env)[0].get('status'), 'ingetrokken');
  assert.equal(reageer(env, 'h25', 'k1').status, 200);
  assert.equal(reacties(env).length, 1, 'één reactie per helper per klus');
  assert.equal(reacties(env)[0].get('status'), 'open');
});

test('reageren: dezelfde voorwaarden als accepteren', () => {
  const env = omgeving();
  const reden = (helper, klus, extra) => {
    const u = reageer(env, helper, klus, extra);
    return `${u.status} ${u.body.reden}`;
  };
  assert.equal(reden('b1', 'k1'), '403 rol');
  env.app.db.hh_profielen.find((p) => p.get('gebruiker') === 'h30').set('verificatiestatus', 'in_behandeling');
  assert.equal(reden('h30', 'k1'), '403 nietgoedgekeurd');
  assert.equal(reden('h14z', 'k1'), '403 ouder', 'onder 18 zonder ouder-toestemming');
  assert.equal(reden('h25', 'kbezet'), '409 bezet');
  assert.equal(reden('h25', 'kongekeurd'), '409 nietgekeurd');
  assert.equal(reden('h11', 'ktuin'), '403 leeftijd', 'tuin is 13+');
  assert.equal(reden('hams', 'k1'), '409 wijk');
  assert.equal(reden('h25', 'kbegonnen'), '409 begonnen');
  assert.equal(reden('h25', 'bestaatniet'), '404 nietgevonden');
  assert.equal(reden('h25', 'k1', { bericht: 'x'.repeat(201) }), '400 bericht');
  const geenWijk = omgeving();
  geenWijk.app.db.hh_users.find((u) => u.id === 'h25').set('wijk', '');
  assert.equal(reageer(geenWijk, 'h25', 'k1').body.reden, 'geenwijk');
  assert.equal(reacties(env).length, 0, 'niets aangemaakt');
});

test('onder 18 dicht (schakelaar uit, standaard): 409 onder18 met een vriendelijke tekst; 18+ gewoon', () => {
  const env = omgeving();
  env.app.db.hh_instellingen = [];
  const jong = reageer(env, 'h14', 'k1');
  assert.equal(jong.status, 409);
  assert.equal(jong.body.reden, 'onder18');
  assert.equal(jong.body.melding, DEP.teksten.MELDING.onder18);
  assert.equal(env.mails.length, 0, 'geen ouder-mail');
  assert.equal(reacties(env).length, 0);
  // Eerst de gewone weigeringen (zo ziet een kind van 11 bij een tuinklus de leeftijdsgrens).
  assert.equal(reageer(env, 'h11', 'ktuin').body.reden, 'leeftijd');
  assert.equal(reageer(env, 'h25', 'k1').status, 200);
});

test('reageren: hooguit 10 reacties tegelijk open', () => {
  const extra = Array.from({ length: 11 }, (_, i) => ({
    id: `kk${i}`, hulpvrager: 'b2', klustype: 't-licht', status: 'open', toegewezen_jongere: '',
    klus_goedgekeurd_op: '2026-10-03 10:00:00.000Z', wanneer_van: VAN,
  }));
  const env = omgeving(wereld({ hh_klussen: extra }));
  for (let i = 0; i < 10; i++) assert.equal(reageer(env, 'h25', `kk${i}`).status, 200);
  const elfde = reageer(env, 'h25', 'kk10');
  assert.equal(elfde.status, 429);
  assert.equal(elfde.body.reden, 'limiet');
});

test('helper onder 18: wacht_op_ouder, mail aan de ouder met link, geen huisnummer in de mail', () => {
  const env = omgeving();
  const uit = reageer(env, 'h14', 'k1', { bericht: 'Ik help graag!' });
  assert.equal(uit.status, 200, JSON.stringify(uit.body));
  assert.equal(uit.body.status, 'wacht_op_ouder');
  assert.equal(uit.body.melding, DEP.teksten.MELDING.verstuurdOuder);
  const r = reacties(env)[0];
  assert.equal(r.get('status'), 'wacht_op_ouder');
  assert.equal(env.mails.length, 1);
  const mail = env.mails[0];
  assert.equal(mail.aan, 'ouder.daan@voorbeeld.nl', 'adres uit de gegeven toestemming');
  assert.ok(mail.tekst.includes('https://heitjehulp.nl/#/ouder/klus?token='), mail.tekst);
  assert.ok(mail.tekst.includes('Daan wil helpen'));
  assert.ok(mail.tekst.includes('Anja'), 'voornaam bewoner');
  assert.ok(!mail.tekst.includes('de Vries') && !mail.tekst.includes('Mulder'), 'geen achternamen');
  assert.ok(mail.tekst.includes('Waar: Kerkstraat, Tiel'));
  assert.ok(!/Kerkstraat 1/.test(mail.tekst) && !/4001/.test(mail.tekst), 'geen huisnummer of postcode');
  assert.ok(mail.tekst.includes('zaterdag 10 oktober om 10:00'), mail.tekst);
  const token = tokenUitMail(mail);
  assert.equal(r.get('token_hash'), hulp.tokenHash(env.sha256, token), 'alleen de hash staat erin');
  assert.ok(r.get('ouder_gemaild_op'));
});

test('helper onder 18: mail mislukt -> 502 en geen reactie; nep-adres -> geen mail maar wel reactie', () => {
  const env = omgeving();
  env.mailFout = true;
  const uit = reageer(env, 'h14', 'k1');
  assert.equal(uit.status, 502);
  assert.equal(uit.body.reden, 'mail');
  assert.equal(reacties(env).length, 0);
  const nep = omgeving();
  nep.app.db.hh_ouder_toestemming[0].set('ouder_email', 'ouder@b5check.invalid');
  assert.equal(reageer(nep, 'h14', 'k1').status, 200);
  assert.equal(nep.mails.length, 0, '.invalid krijgt nooit mail');
  const zonder = omgeving();
  zonder.app.db.hh_ouder_toestemming = [];
  zonder.app.db.hh_users.find((u) => u.id === 'h14').set('ouder_email', '');
  assert.equal(reageer(zonder, 'h14', 'k1').body.reden, 'geenouder');
});

test('eerste klus bij een nieuwe bewoner: 10-12 jaar moet het vinkje zetten, daarna niet meer', () => {
  const env = omgeving();
  const zonder = reageer(env, 'h11', 'k1');
  assert.equal(zonder.status, 400);
  assert.equal(zonder.body.reden, 'oudermee');
  const met = reageer(env, 'h11', 'k1', { ouderGaatMee: true });
  assert.equal(met.status, 200, JSON.stringify(met.body));
  assert.equal(reacties(env)[0].get('ouder_gaat_mee'), true);
  assert.ok(env.mails[0].tekst.includes('jij meegaat'), 'de ouder leest het ook');
  // Al eens een klus bij deze bewoner gedaan: geen vinkje meer nodig.
  const later = omgeving(wereld({ hh_klussen: [{ id: 'koud', hulpvrager: 'b1', toegewezen_jongere: 'h11', status: 'afgerond', klustype: 't-licht' }] }));
  assert.equal(reageer(later, 'h11', 'k1').status, 200);
  // 13+ (hier 14): alleen een tip in de app, de server eist niets.
  assert.equal(reageer(omgeving(), 'h14', 'k1').status, 200);
});

// ---------------------------------------------------------------- ouder

test('ouder: link toont wat/waar/wanneer/voornaam; Goed -> open + bewoner krijgt melding', () => {
  const env = omgeving();
  reageer(env, 'h14', 'k1', { bericht: 'Graag!' });
  const token = tokenUitMail(env.mails[0]);
  const stand = hulp.ouderStand(env, { token, ip: '1.2.3.4' });
  assert.equal(stand.status, 200, JSON.stringify(stand.body));
  assert.equal(stand.body.status, 'wacht');
  assert.equal(stand.body.helper_voornaam, 'Daan');
  assert.equal(stand.body.klus.wat, 'Boodschappen');
  assert.equal(stand.body.klus.omschrijving, 'Boodschappen bij de Jumbo halen.');
  assert.equal(stand.body.klus.waar, 'Kerkstraat, Tiel');
  assert.equal(stand.body.klus.bewoner_voornaam, 'Anja');
  assert.ok(stand.body.klus.wanneer.includes('10 oktober'));
  assert.equal(JSON.stringify(stand.body).includes('de Vries'), false);

  const goed = hulp.ouderBesluit(env, { token, besluit: 'goed', ip: '1.2.3.4' });
  assert.equal(goed.status, 200, JSON.stringify(goed.body));
  assert.equal(goed.body.status, 'goed');
  const r = reacties(env)[0];
  assert.equal(r.get('status'), 'open');
  assert.equal(r.get('ouder_besluit'), 'goed');
  assert.ok(r.get('ouder_akkoord_op'));
  assert.equal(meldingenVan(env, 'b1').length, 1, 'nu pas ziet de bewoner hem');
  assert.equal(meldingenVan(env, 'h14')[0].get('titel'), 'Je ouder vindt het goed');
  // Nog eens: niets verandert, de stand komt terug.
  const nogEens = hulp.ouderBesluit(env, { token, besluit: 'lieverniet', ip: '1.2.3.4' });
  assert.equal(nogEens.status, 200);
  assert.equal(nogEens.body.status, 'goed');
  assert.equal(r.get('status'), 'open');
});

test('ouder: Liever niet -> afgewezen, bewoner ziet niets; foute token 404; onbekend besluit 400', () => {
  const env = omgeving();
  reageer(env, 'h14', 'k1');
  const token = tokenUitMail(env.mails[0]);
  assert.equal(hulp.ouderBesluit(env, { token, besluit: 'misschien', ip: 'x' }).status, 400);
  const nee = hulp.ouderBesluit(env, { token, besluit: 'lieverniet', ip: 'x' });
  assert.equal(nee.body.status, 'lieverniet');
  assert.equal(reacties(env)[0].get('status'), 'afgewezen');
  assert.equal(reacties(env)[0].get('ouder_besluit'), 'liever_niet');
  assert.equal(meldingenVan(env, 'b1').length, 0);
  assert.equal(meldingenVan(env, 'h14')[0].get('titel'), 'Je ouder koos "liever niet"');
  assert.equal(hulp.ouderStand(env, { token: 'fout', ip: 'x' }).status, 404);
});

test('ouder: de vraag verloopt als de klus begint (en als de klus al een helper heeft)', () => {
  const env = omgeving();
  reageer(env, 'h14', 'k1');
  const token = tokenUitMail(env.mails[0]);
  const later = { ...env, nu: () => Date.parse('2026-10-10T08:00:00Z') };
  const stand = hulp.ouderStand(later, { token, ip: 'x' });
  assert.equal(stand.body.status, 'verlopen');
  assert.equal(reacties(env)[0].get('status'), 'vervallen');
  assert.equal(hulp.ouderBesluit(later, { token, besluit: 'goed', ip: 'x' }).body.status, 'verlopen');

  const env2 = omgeving();
  reageer(env2, 'h14', 'k1');
  const token2 = tokenUitMail(env2.mails[0]);
  rec(env2, 'hh_klussen', 'k1').set('status', 'geaccepteerd');
  assert.equal(hulp.ouderStand(env2, { token: token2, ip: 'x' }).body.status, 'verlopen');
});

test('ouder: hooguit 30 verzoeken per IP per uur', () => {
  const env = omgeving();
  for (let i = 0; i < 30; i++) hulp.ouderStand(env, { token: 'x', ip: '9.9.9.9' });
  const te = hulp.ouderStand(env, { token: 'x', ip: '9.9.9.9' });
  assert.equal(te.status, 429);
  assert.equal(te.body.reden, 'teveel');
  assert.equal(hulp.ouderStand(env, { token: 'x', ip: '8.8.8.8' }).status, 404, 'ander IP telt apart');
});

test('vervalVerlopen: wacht_op_ouder van een begonnen klus vervalt', () => {
  const env = omgeving();
  reageer(env, 'h14', 'k1');
  reageer(env, 'h25', 'k1');
  assert.equal(hulp.vervalVerlopen(env), 0);
  const later = { ...env, nu: () => Date.parse('2026-10-10T08:00:01Z') };
  assert.equal(hulp.vervalVerlopen(later), 1);
  const st = Object.fromEntries(reacties(env).map((r) => [r.get('helper'), r.get('status')]));
  assert.deepEqual(st, { h14: 'vervallen', h25: 'open' }, 'open reacties blijven staan');
});

// ---------------------------------------------------------------- bewoner

test('reacties voor de bewoner: alleen open, voornaam/leeftijd/niveau/sterren/ID/recensie, nooit achternaam of adres', () => {
  const env = omgeving(wereld({
    hh_beoordelingen: [
      { id: 'be1', naar_gebruiker: 'h25', van_gebruiker: 'b2', sterren: 5, tekst: 'Heel netjes de heg geknipt.\nEn opgeruimd.', created: '2026-09-20 10:00:00.000Z' },
      { id: 'be2', naar_gebruiker: 'h25', van_gebruiker: 'b1', sterren: 4, tekst: '', created: '2026-09-25 10:00:00.000Z' },
    ],
  }));
  reageer(env, 'h25', 'k1', { bericht: 'Ik heb tijd.' });
  reageer(env, 'h14', 'k1');
  const uit = hulp.reactiesVoorBewoner(env, { kijker: { id: 'b1', rol: 'hulpvrager' }, klusId: 'k1' });
  assert.equal(uit.status, 200);
  assert.equal(uit.body.reacties.length, 1, 'de reactie die op de ouder wacht, ziet de bewoner niet');
  const k = uit.body.reacties[0];
  assert.equal(k.voornaam, 'Ruud');
  assert.equal(k.leeftijd, 25);
  assert.equal(k.niveau, 'Nieuw');
  assert.equal(k.sterren, 4.6);
  assert.equal(k.beoordelingen, 2);
  assert.equal(k.id_gecontroleerd, true);
  assert.equal(k.laatste_recensie, 'Heel netjes de heg geknipt.', 'één regel, de laatste mét tekst');
  assert.equal(k.bericht, 'Ik heb tijd.');
  const tekst = JSON.stringify(uit.body);
  for (const verboden of ['Jansen', '2001', 'geboortedatum', 'adres', 'email', 'Kerkstraat']) {
    assert.ok(!tekst.includes(verboden), `lekt niet: ${verboden}`);
  }
  assert.equal(hulp.reactiesVoorBewoner(env, { kijker: { id: 'b2', rol: 'hulpvrager' }, klusId: 'k1' }).status, 403);
  assert.equal(hulp.reactiesVoorBewoner(env, { kijker: { id: 'h25', rol: 'jongere' }, klusId: 'k1' }).status, 403);
  assert.equal(hulp.reactiesVoorBewoner(env, { kijker: { id: 'coord', rol: 'coordinator' }, klusId: 'k1' }).status, 200);
  // Een helper die intussen geblokkeerd raakt (ouder trok in), valt eruit.
  rec(env, 'hh_users', 'h25').set('geblokkeerd', true);
  assert.equal(hulp.reactiesVoorBewoner(env, { kijker: { id: 'b1', rol: 'hulpvrager' }, klusId: 'k1' }).body.reacties.length, 0);
});

test('kiezen: in één transactie klus geaccepteerd + helper, gekozen, rest afgewezen/vervallen, logregel, meldingen', () => {
  const env = omgeving();
  reageer(env, 'h25', 'k1');
  reageer(env, 'h30', 'k1');
  reageer(env, 'h14', 'k1');
  const r25 = reacties(env).find((r) => r.get('helper') === 'h25');
  const uit = hulp.kies(env, { kijker: { id: 'b1', rol: 'hulpvrager' }, klusId: 'k1', reactieId: r25.id });
  assert.equal(uit.status, 200, JSON.stringify(uit.body));
  assert.equal(uit.body.status, 'geaccepteerd');
  assert.equal(uit.body.toegewezen_jongere, 'h25');
  assert.equal(uit.body.helper_voornaam, 'Ruud');
  assert.equal(uit.body.melding, 'Het is een match!');
  const klus = rec(env, 'hh_klussen', 'k1');
  assert.equal(klus.get('status'), 'geaccepteerd');
  assert.equal(klus.get('toegewezen_jongere'), 'h25');
  const st = Object.fromEntries(reacties(env).map((r) => [r.get('helper'), r.get('status')]));
  assert.deepEqual(st, { h25: 'gekozen', h30: 'afgewezen', h14: 'vervallen' });
  const logs = env.app.db.hh_klus_status;
  assert.equal(logs.length, 1);
  assert.deepEqual(
    [logs[0].get('van'), logs[0].get('naar'), logs[0].get('door'), logs[0].get('toelichting')],
    ['open', 'geaccepteerd', 'b1', hulp.TOELICHTING_GEKOZEN]
  );
  assert.equal(meldingenVan(env, 'h30')[0].get('titel'), 'De bewoner koos iemand anders');
  assert.equal(meldingenVan(env, 'h14').length, 0, 'wie nog op de ouder wachtte: stil vervallen');
  assert.ok(meldingenVan(env, 'b1').every((m) => m.get('gelezen_op')), 'de reactie-melding van de bewoner is nu gelezen');
  // Tweede klik (of een tweede tabblad): 409.
  const r30 = reacties(env).find((r) => r.get('helper') === 'h30');
  const twee = hulp.kies(env, { kijker: { id: 'b1', rol: 'hulpvrager' }, klusId: 'k1', reactieId: r30.id });
  assert.equal(twee.status, 409);
  assert.equal(twee.body.reden, 'klusbezet');
  assert.equal(env.app.db.hh_klus_status.length, 1);
});

test('kiezen: weigeringen (vreemde, geen reactie, reactie van een andere klus, ingetrokken, helper geblokkeerd)', () => {
  const env = omgeving();
  reageer(env, 'h25', 'k1');
  reageer(env, 'h30', 'k2');
  const r25 = reacties(env).find((r) => r.get('helper') === 'h25');
  const r30 = reacties(env).find((r) => r.get('helper') === 'h30');
  const kies = (kijker, klusId, reactieId) => {
    const u = hulp.kies(env, { kijker, klusId, reactieId });
    return `${u.status} ${u.body.reden}`;
  };
  const b1 = { id: 'b1', rol: 'hulpvrager' };
  assert.equal(kies({ id: 'b2', rol: 'hulpvrager' }, 'k1', r25.id), '403 geenbewoner');
  assert.equal(kies({ id: 'h25', rol: 'jongere' }, 'k1', r25.id), '403 geenbewoner');
  assert.equal(kies(b1, 'k1', ''), '400 geenreactie');
  assert.equal(kies(b1, 'k1', r30.id), '409 reactieweg', 'reactie hoort bij een andere klus');
  assert.equal(kies(b1, 'nietbestaand', r25.id), '404 nietgevonden');
  rec(env, 'hh_users', 'h25').set('geblokkeerd', true);
  assert.equal(kies(b1, 'k1', r25.id), '409 reactieweg');
  assert.equal(r25.get('status'), 'vervallen', 'een geblokkeerde helper vervalt');
  rec(env, 'hh_users', 'h25').set('geblokkeerd', false);
  assert.equal(rec(env, 'hh_klussen', 'k1').get('status'), 'open');
  // De meldkamer mag namens de bewoner kiezen (h25 reageert opnieuw: zelfde rij).
  assert.equal(reageer(env, 'h25', 'k1').status, 200);
  assert.equal(kies({ id: 'coord', rol: 'coordinator' }, 'k1', r25.id), '200 undefined');
  assert.equal(env.app.db.hh_klus_status[0].get('toelichting'), hulp.TOELICHTING_GEKOZEN_MELDKAMER);
});

test('kiezen: dezelfde helper voor twee klussen tegelijk -> één winnaar (helperbezet)', () => {
  const env = omgeving();
  reageer(env, 'h25', 'k1');
  reageer(env, 'h25', 'k2');
  const rk1 = reacties(env).find((r) => r.get('klus') === 'k1');
  const rk2 = reacties(env).find((r) => r.get('klus') === 'k2');
  assert.equal(hulp.kies(env, { kijker: { id: 'b1', rol: 'hulpvrager' }, klusId: 'k1', reactieId: rk1.id }).status, 200);
  const twee = hulp.kies(env, { kijker: { id: 'b2', rol: 'hulpvrager' }, klusId: 'k2', reactieId: rk2.id });
  assert.equal(twee.status, 409);
  assert.equal(twee.body.reden, 'helperbezet');
  assert.equal(rec(env, 'hh_klussen', 'k2').get('status'), 'open');
  // Een klus op een ander moment mag wel.
  reageer(env, 'h25', 'ktuin');
  const rt = reacties(env).find((r) => r.get('klus') === 'ktuin');
  assert.equal(hulp.kies(env, { kijker: { id: 'b1', rol: 'hulpvrager' }, klusId: 'ktuin', reactieId: rt.id }).status, 200);
});

test('intrekken: eigen open of wachtende reactie; niet van een ander, niet na kiezen', () => {
  const env = omgeving();
  reageer(env, 'h25', 'k1');
  reageer(env, 'h14', 'k1');
  const r25 = reacties(env).find((r) => r.get('helper') === 'h25');
  const r14 = reacties(env).find((r) => r.get('helper') === 'h14');
  assert.equal(hulp.trekIn(env, { helperId: 'h30', reactieId: r25.id }).status, 404);
  assert.equal(hulp.trekIn(env, { helperId: 'h14', reactieId: r14.id }).status, 200);
  assert.equal(r14.get('status'), 'ingetrokken');
  hulp.kies(env, { kijker: { id: 'b1', rol: 'hulpvrager' }, klusId: 'k1', reactieId: r25.id });
  const na = hulp.trekIn(env, { helperId: 'h25', reactieId: r25.id });
  assert.equal(na.status, 409);
  assert.equal(na.body.reden, 'status');
});

// ---------------------------------------------------------------- na een statuswissel

test('naKlusWissel: koppelen/accepteren -> open reacties afgewezen; annuleren -> vervallen; teruggeven -> gekozen ingetrokken', () => {
  const env = omgeving();
  reageer(env, 'h25', 'k1');
  reageer(env, 'h14', 'k1');
  const log = (van, naar, door) => new NepRecord('hh_klus_status', { id: `l${van}${naar}`, klus: 'k1', van, naar, door, toelichting: '' });
  rec(env, 'hh_klussen', 'k1').set('status', 'geaccepteerd');
  rec(env, 'hh_klussen', 'k1').set('toegewezen_jongere', 'h30');
  assert.equal(hulp.naKlusWissel(env, log('open', 'geaccepteerd', 'coord')), 2);
  const st = Object.fromEntries(reacties(env).map((r) => [r.get('helper'), r.get('status')]));
  assert.deepEqual(st, { h25: 'afgewezen', h14: 'vervallen' });
  assert.equal(meldingenVan(env, 'h25')[0].get('titel'), 'De bewoner koos iemand anders');

  const env2 = omgeving();
  reageer(env2, 'h25', 'k1');
  rec(env2, 'hh_klussen', 'k1').set('status', 'geannuleerd');
  hulp.naKlusWissel(env2, log('open', 'geannuleerd', 'b1'));
  assert.equal(reacties(env2)[0].get('status'), 'vervallen');
  assert.equal(meldingenVan(env2, 'h25')[0].get('titel'), 'Klus gaat niet door');

  const env3 = omgeving();
  reageer(env3, 'h25', 'k1');
  hulp.kies(env3, { kijker: { id: 'b1', rol: 'hulpvrager' }, klusId: 'k1', reactieId: reacties(env3)[0].id });
  rec(env3, 'hh_klussen', 'k1').set('status', 'open');
  rec(env3, 'hh_klussen', 'k1').set('toegewezen_jongere', '');
  hulp.naKlusWissel(env3, log('geaccepteerd', 'open', 'h25'));
  assert.equal(reacties(env3)[0].get('status'), 'ingetrokken', 'teruggegeven: de gekozen reactie is ingetrokken');
  // ... en hij mag later opnieuw reageren.
  assert.equal(reageer(env3, 'h25', 'k1').status, 200);
});

// ---------------------------------------------------------------- meldingen nakijken

test('nakijkenMelding: match-tekst voor de gekozen helper, geen dubbele melding voor wie zelf koos', () => {
  const env = omgeving();
  reageer(env, 'h25', 'k1');
  hulp.kies(env, { kijker: { id: 'b1', rol: 'hulpvrager' }, klusId: 'k1', reactieId: reacties(env)[0].id });
  const logId = env.app.db.hh_klus_status[0].id;
  const melding = (ontvanger) => new NepRecord('hh_meldingen', { ontvanger, soort: 'toegewezen', klus: 'k1', sleutel: `klusstatus:${logId}`, titel: 'Je hebt een klus', tekst: 'De coordinator heeft je gekoppeld.' });
  const helper = hulp.nakijkenMelding(env, melding('h25'));
  assert.equal(helper.opslaan, true);
  assert.equal(helper.titel, 'Het is een match!');
  assert.ok(helper.tekst.startsWith('Anja koos jou voor Boodschappen'), helper.tekst);
  assert.equal(hulp.nakijkenMelding(env, melding('b1')).opslaan, false, 'de bewoner koos zelf');
  // Een gewone koppeling door de meldkamer: niets aan veranderen.
  env.app.db.hh_klus_status[0].set('toelichting', 'handmatig gekoppeld');
  env.app.db.hh_klus_status[0].set('door', 'coord');
  const gewoon = hulp.nakijkenMelding(env, melding('h25'));
  assert.deepEqual(gewoon, { opslaan: true });
});

test('nakijkenMelding: "nieuwe klus" alleen aan wie nu kan helpen, als de schakelaar aan staat', () => {
  const nieuw = (ontvanger) => new NepRecord('hh_meldingen', { ontvanger, soort: 'nieuwe_klus', klus: 'k1', sleutel: 'klusstatus:x' });
  const uit = omgeving();
  assert.equal(hulp.nakijkenMelding(uit, nieuw('h25')).opslaan, true, 'schakelaar uit: zoals altijd');
  const aan = omgeving(wereld({ hh_instellingen: [{ id: 'i1', sleutel: hulp.INSTELLING_ALLEEN_BESCHIKBAAR, waarde: true }] }));
  assert.equal(hulp.nakijkenMelding(aan, nieuw('h25')).opslaan, false, 'niet beschikbaar: alleen de lijst');
  assert.equal(hulp.zetBeschikbaar(aan, { helper: rec(aan, 'hh_users', 'h25'), aan: true }).status, 200);
  assert.equal(hulp.nakijkenMelding(aan, nieuw('h25')).opslaan, true);
  const laat = { ...aan, nu: () => NU + 3 * UUR + 1 };
  assert.equal(hulp.nakijkenMelding(laat, nieuw('h25')).opslaan, false, 'na 3 uur vanzelf uit');
});

// ---------------------------------------------------------------- Ik kan nu helpen

test('zetBeschikbaar: aan = nu + 3 uur, uit = leeg; alleen een helper met profiel', () => {
  const env = omgeving();
  const aan = hulp.zetBeschikbaar(env, { helper: rec(env, 'hh_users', 'h25'), aan: true });
  assert.equal(aan.status, 200);
  assert.equal(aan.body.beschikbaar_tot, pbDatum(NU + 3 * UUR));
  assert.equal(rec(env, 'hh_profielen', 'p25').get('beschikbaar_tot'), pbDatum(NU + 3 * UUR));
  const uit = hulp.zetBeschikbaar(env, { helper: rec(env, 'hh_users', 'h25'), aan: false });
  assert.equal(uit.body.beschikbaar_tot, '');
  assert.equal(hulp.zetBeschikbaar(env, { helper: rec(env, 'hh_users', 'b1'), aan: true }).status, 403);
  env.app.db.hh_profielen = env.app.db.hh_profielen.filter((p) => p.get('gebruiker') !== 'h30');
  assert.equal(hulp.zetBeschikbaar(env, { helper: rec(env, 'hh_users', 'h30'), aan: true }).status, 409);
});

test('telBeschikbaar: alleen het aantal, binnen werkgebied, passende leeftijd, niet verlopen', () => {
  const env = omgeving();
  for (const id of ['h25', 'h14', 'h11', 'hams', 'h14z']) hulp.zetBeschikbaar(env, { helper: rec(env, 'hh_users', id), aan: true });
  const tel = (klustypeId, van = VAN, tot = TOT, kijker = { id: 'b1', rol: 'hulpvrager', wijk: 'w-tiel' }) =>
    hulp.telBeschikbaar(env, { kijker, klustypeId, van, tot });
  const licht = tel('t-licht');
  assert.equal(licht.status, 200);
  assert.deepEqual(Object.keys(licht.body), ['aantal'], 'alleen een aantal');
  assert.equal(licht.body.aantal, 3, 'h25, h14, h11 (niet Amsterdam, niet zonder ouder-toestemming)');
  assert.equal(tel('t-tuin').body.aantal, 2, 'tuin 13+: h11 telt niet');
  assert.equal(tel('t-licht', '2026-10-10 18:00:00.000Z', '').body.aantal, 1, '20:00 NL: alleen 18+');
  assert.equal(tel('t-licht', VAN, TOT, { id: 'h25', rol: 'jongere', wijk: 'w-tiel' }).status, 403);
  // Onder 18 nog dicht: alleen helpers die nu echt kunnen reageren tellen.
  env.app.db.hh_instellingen = [];
  assert.equal(tel('t-licht').body.aantal, 1, 'alleen h25');
  env.app.db.hh_instellingen = [new NepRecord('hh_instellingen', { id: 'i-o18', sleutel: 'b5_onder18_reageren_open', waarde: true })];
  const later = { ...env, nu: () => NU + 4 * UUR };
  assert.equal(hulp.telBeschikbaar(later, { kijker: { id: 'b1', rol: 'hulpvrager', wijk: 'w-tiel' }, klustypeId: 't-licht', van: VAN, tot: TOT }).body.aantal, 0);
});

// ---------------------------------------------------------------- geheime vraag

test('geheime vraag: "nee" -> één signaal voor de meldkamer (geen probleem), "ja" -> niets', () => {
  const env = omgeving();
  const be = (id, van, naar, alles, toelichting = '') => new NepRecord('hh_beoordelingen', { id, klus: 'k1', van_gebruiker: van, naar_gebruiker: naar, sterren: 4, alles_in_orde: alles, geheim_toelichting: toelichting });
  assert.equal(hulp.verwerkGeheim(env, be('x1', 'b1', 'h25', 'ja')), false);
  assert.equal(hulp.verwerkGeheim(env, be('x2', 'h25', 'b1', 'nee', 'Hij schreeuwde.')), true);
  const inc = env.app.db.hh_incidenten;
  assert.equal(inc.length, 1);
  assert.equal(inc[0].get('melder'), 'h25');
  assert.equal(inc[0].get('klus'), 'k1');
  assert.equal(inc[0].get('soort'), 'signaal', 'antwoord Ibrahim 4: eigen, zachtere soort');
  assert.ok(inc[0].get('omschrijving').includes('Voelde je je veilig?'));
  assert.ok(inc[0].get('omschrijving').includes('Hij schreeuwde.'));
  assert.equal(hulp.verwerkGeheim(env, be('x2', 'h25', 'b1', 'nee')), false, 'niet dubbel');
  assert.equal(env.app.db.hh_incidenten.length, 1);
  assert.ok(hulp.verwerkGeheim(env, be('x3', 'b1', 'h25', 'nee')));
  assert.ok(env.app.db.hh_incidenten[1].get('omschrijving').includes('Was alles in orde?'));
});

test('nakijkenMelding: een signaal geeft GEEN melding (geen alarm), nood/probleem wel', () => {
  const env = omgeving(wereld({
    hh_incidenten: [
      { id: 'inc-s', soort: 'signaal', melder: 'h25', klus: 'k1' },
      { id: 'inc-p', soort: 'probleem', melder: 'h25', klus: 'k1' },
    ],
  }));
  const melding = (incident) => new NepRecord('hh_meldingen', { ontvanger: 'coord', soort: 'incident', incident, klus: 'k1', sleutel: `incident:${incident}` });
  assert.deepEqual(hulp.nakijkenMelding(env, melding('inc-s')), { opslaan: false });
  assert.deepEqual(hulp.nakijkenMelding(env, melding('inc-p')), { opslaan: true });
  assert.deepEqual(hulp.nakijkenMelding(env, melding('bestaatniet')), { opslaan: true }, 'twijfel: wel melden');
});

// ---------------------------------------------------------------- verrijken

test('verrijkKlus: helper ziet het aantal reacties en zijn eigen stand; bewoner alleen open', () => {
  const env = omgeving();
  reageer(env, 'h25', 'k1');
  reageer(env, 'h14', 'k1');
  const klus = rec(env, 'hh_klussen', 'k1');
  assert.deepEqual(hulp.verrijkKlus(env, { kijker: { id: 'h25', rol: 'jongere' }, klus }), { reacties_aantal: 2, mijn_reactie: 'open' });
  assert.deepEqual(hulp.verrijkKlus(env, { kijker: { id: 'h30', rol: 'jongere' }, klus }), { reacties_aantal: 2, mijn_reactie: '' });
  assert.deepEqual(hulp.verrijkKlus(env, { kijker: { id: 'b1', rol: 'hulpvrager' }, klus }), { reacties_aantal: 1 });
  assert.equal(hulp.verrijkKlus(env, { kijker: { id: 'b2', rol: 'hulpvrager' }, klus }), null);
});
