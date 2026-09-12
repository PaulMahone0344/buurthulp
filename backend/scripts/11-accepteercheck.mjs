// HeitjeHulp M5 — bewijst de hook backend/pb_hooks/hh_klussen.pb.js op de
// ECHTE server met de ECHTE seed-accounts (backend/seed-accounts.local.json,
// nooit loggen):
//   A. terugzetten: seed-klussen k02/k11/k03 op open zonder jongere, hun
//      accepteer-logregels weg, eigen [accepteercheck]-rijen weg
//   B. route bestaat: anoniem -> 401 (niet 404)
//   C. geocoding: klus aanmaken zonder lat/lon krijgt coördinaten van de hook;
//      adres wijzigen geeft nieuwe coördinaten
//   D. bestaande klussen zonder lat/lon eenmalig vullen (directe geocode-
//      helper, 1 verzoek per seconde, als superuser)
//   E. rechten: oudere -> 403, niet-goedgekeurde jongere -> 403, andere wijk
//      -> 409, onbekende klus -> 404
//   F. RACE: 20 ronden waarin jongere 1 en jongere 2 TEGELIJK (Promise.all)
//      seed-klus k02 accepteren; elke ronde precies één 200, één 409 en één
//      logregel; de winnaar staat op de klus
//   G. gewone acceptatie van k11 door jongere 1 en een tweede poging -> 409
//   H. terugzetten en nameten (logtellingen gelijk aan het begin)
//
// Wijzigt geen rules. Herhaalbaar. Ook de "terugzet-knop" na een prod-smoke
// vanuit de app met jongere 1:
//   node scripts/11-accepteercheck.mjs --apply --alleen-terugzetten
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/11-accepteercheck.mjs --apply     (zonder --apply: alleen uitleg)

import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, userClient, anonClient, assertHh, APPLY, fail, PB_URL } from './_lib.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ACCOUNTS_FILE = path.resolve(__dirname, '..', 'seed-accounts.local.json');
const MERK = '[accepteercheck]';
const ALLEEN_TERUGZETTEN = process.argv.includes('--alleen-terugzetten');
const RONDEN = Number(process.env.HH_RONDEN || 20);
const SEED_OPEN = ['k02', 'k11', 'k03']; // open in de seed, zonder jongere
const ROUTE = (id) => `/api/hh/klussen/${id}/accepteren`;
const NOMINATIM_UA = 'HeitjeHulp/0.1 (info@heitjehulp.nl)';
const ADRES_A = 'Prins Bernhardlaan 12, 4003 AB Tiel';
const ADRES_B = 'Stationsplein 1, 4001 Tiel';

let groen = 0;
let rood = 0;
function check(label, ok, detail) {
  if (ok) {
    groen++;
    console.log(`  ✓ ${label}`);
  } else {
    rood++;
    console.log(`  ✗ ${label}${detail ? ` — ${detail}` : ''}`);
  }
}
function kop(t) {
  console.log(`\n${t}`);
}
const slaap = (ms) => new Promise((r) => setTimeout(r, ms));

// Een POST naar de route; geeft {status, body} terug, gooit nooit.
async function accepteer(client, klusId) {
  try {
    const body = await client.send(ROUTE(klusId), { method: 'POST' });
    return { status: 200, body };
  } catch (e) {
    return { status: e?.status ?? 0, body: e?.response ?? {} };
  }
}

async function geocodeer(adres) {
  const url = `https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=nl&q=${encodeURIComponent(adres)}`;
  const res = await fetch(url, { headers: { 'User-Agent': NOMINATIM_UA, Accept: 'application/json' } });
  if (!res.ok) return null;
  const lijst = await res.json();
  if (!Array.isArray(lijst) || !lijst.length) return null;
  const lat = parseFloat(lijst[0].lat);
  const lon = parseFloat(lijst[0].lon);
  return Number.isFinite(lat) && Number.isFinite(lon) ? { lat, lon } : null;
}

const inTiel = (r) => r.lat > 51.8 && r.lat < 52.0 && r.lon > 5.3 && r.lon < 5.5;

async function seedKlus(su, key) {
  return su.collection('hh_klussen').getFirstListItem(`omschrijving ~ "[seed ${key}]"`);
}

async function accepteerLogs(su, klusId) {
  return su.collection('hh_klus_status').getFullList({ filter: `klus = "${klusId}" && naar = "geaccepteerd"` });
}

// Zet de open seed-klussen terug en ruimt eigen rijen op. Geeft de logtelling
// per seed-klus terug (na het opruimen).
async function terugzetten(su) {
  const telling = {};
  for (const key of SEED_OPEN) {
    const klus = await seedKlus(su, key);
    if (klus.status !== 'open' || klus.toegewezen_jongere) {
      await su.collection(assertHh('hh_klussen')).update(klus.id, { status: 'open', toegewezen_jongere: '' });
      console.log(`  ↻ ${key} teruggezet op open zonder jongere`);
    }
    for (const log of await accepteerLogs(su, klus.id)) {
      await su.collection(assertHh('hh_klus_status')).delete(log.id);
      console.log(`  ↻ ${key} accepteer-logregel ${log.id} verwijderd`);
    }
    const alle = await su.collection('hh_klus_status').getFullList({ filter: `klus = "${klus.id}"` });
    telling[key] = alle.length;
  }
  const eigen = await su.collection('hh_klussen').getFullList({ filter: `omschrijving ~ "${MERK}"` });
  for (const k of eigen) {
    await su.collection(assertHh('hh_klussen')).delete(k.id);
    console.log(`  ↻ eigen klus ${k.id} verwijderd`);
  }
  return telling;
}

async function main() {
  assertHh('hh_klussen');
  assertHh('hh_klus_status');
  assertHh('hh_profielen');
  if (!APPLY) {
    console.log('DRY-RUN: dit script logt in als de seed-accounts, zet k02/k11/k03 op open, bewijst de route');
    console.log('/api/hh/klussen/{id}/accepteren (401/403/404/409/200), de geocoding-hook, en laat jongere 1 en 2');
    console.log(`${RONDEN} keer tegelijk k02 accepteren (precies één winnaar per ronde). Alles wordt teruggezet.`);
    console.log('Zonder --apply gebeurt er niets. Draai met --apply.');
    return;
  }
  if (!existsSync(ACCOUNTS_FILE)) throw new Error(`${ACCOUNTS_FILE} ontbreekt — draai eerst 03-seed.mjs --apply`);
  const acc = JSON.parse(readFileSync(ACCOUNTS_FILE, 'utf8'));

  const su = await superuserClient();
  console.log('Verbonden met', PB_URL, '\n');

  kop('A. Terugzetten (begin)');
  const tellingBegin = await terugzetten(su);
  check('k02/k11/k03 staan op open zonder jongere', true);
  if (ALLEEN_TERUGZETTEN) {
    console.log(`\n${groen} groen, ${rood} rood. Alleen teruggezet.`);
    return;
  }

  const j1 = await userClient(acc.jongere1.email, acc.jongere1.password);
  const j2 = await userClient(acc.jongere2.email, acc.jongere2.password);
  const j3 = await userClient(acc.jongere3.email, acc.jongere3.password);
  const hv1 = await userClient(acc.hulpvrager1.email, acc.hulpvrager1.password);
  const anon = anonClient();
  const U = Object.fromEntries(Object.entries(acc).map(([k, v]) => [k, v.id]));

  const k02 = await seedKlus(su, 'k02');
  const k11 = await seedKlus(su, 'k11');

  kop('B. Route bestaat');
  {
    const r = await accepteer(anon, k02.id);
    check(`anoniem -> 401 (kreeg ${r.status})`, r.status === 401, JSON.stringify(r.body));
  }

  kop('C. Geocoding-hook (aanmaken en adres wijzigen)');
  let geoKlusId = null;
  {
    const klustype = await su.collection('hh_klustypes').getFirstListItem('naam = "boodschappen"');
    const nu = new Date();
    const van = new Date(nu.getTime() + 24 * 3600 * 1000);
    const tot = new Date(van.getTime() + 3600 * 1000);
    let rij = null;
    try {
      rij = await hv1.collection('hh_klussen').create({
        hulpvrager: U.hulpvrager1,
        geplaatst_door: U.hulpvrager1,
        klustype: klustype.id,
        omschrijving: `${MERK} geocoding-proef`,
        adres: ADRES_A,
        wanneer_van: van.toISOString(),
        wanneer_tot: tot.toISOString(),
        status: 'concept',
        bedrag_bruto: 1000,
        vergoeding_jongere: 1000,
        commissie: 0,
        bron: 'app',
      });
      geoKlusId = rij.id;
      check('oudere 1 maakt een klus aan zonder lat/lon (concept)', true);
    } catch (e) {
      check('oudere 1 maakt een klus aan zonder lat/lon (concept)', false, `status=${e?.status} ${JSON.stringify(e?.response?.data ?? '')}`);
    }
    if (rij) {
      check(`hook zette lat/lon bij aanmaken (${rij.lat}, ${rij.lon})`, inTiel(rij), `lat=${rij.lat} lon=${rij.lon}`);
      const latA = rij.lat;
      await slaap(1100);
      let upd = null;
      try {
        upd = await hv1.collection('hh_klussen').update(rij.id, { adres: ADRES_B });
        check('oudere 1 wijzigt het adres', true);
      } catch (e) {
        check('oudere 1 wijzigt het adres', false, `status=${e?.status}`);
      }
      if (upd) {
        check(`hook zette nieuwe lat/lon bij adreswijziging (${upd.lat}, ${upd.lon})`, inTiel(upd) && upd.lat !== latA, `lat=${upd.lat} lon=${upd.lon} (was ${latA})`);
        await slaap(1100);
        const zonder = await su.collection('hh_klussen').update(rij.id, { status: 'concept' });
        check('een update zonder adreswijziging laat lat/lon staan', zonder.lat === upd.lat && zonder.lon === upd.lon);
      }
    }
  }

  kop('D. Bestaande klussen zonder lat/lon eenmalig vullen');
  {
    const leeg = await su.collection('hh_klussen').getFullList({ filter: 'lat = 0 || lon = 0' });
    let gevuld = 0;
    let overgeslagen = 0;
    for (const k of leeg) {
      const adres = String(k.adres || '').trim();
      if (!adres) {
        overgeslagen++;
        continue;
      }
      await slaap(1100);
      const punt = await geocodeer(adres);
      if (!punt) {
        overgeslagen++;
        console.log(`  · ${k.id}: geen resultaat voor het adres`);
        continue;
      }
      await su.collection(assertHh('hh_klussen')).update(k.id, { lat: punt.lat, lon: punt.lon });
      gevuld++;
    }
    check(`${leeg.length} zonder coördinaten gevonden, ${gevuld} gevuld, ${overgeslagen} overgeslagen (geen adres/resultaat)`, true);
    const nog = await su.collection('hh_klussen').getFullList({ filter: 'lat = 0 || lon = 0' });
    check(`nog ${nog.length} zonder coördinaten (alleen zonder adres of zonder resultaat)`, nog.length === overgeslagen, `verwacht ${overgeslagen}`);
  }

  kop('E. Rechten op de route');
  {
    let r = await accepteer(hv1, k02.id);
    check(`oudere -> 403 (kreeg ${r.status})`, r.status === 403, JSON.stringify(r.body));

    // Jongere 3 tijdelijk niet goedgekeurd (superuser), daarna terug.
    const p3 = await su.collection('hh_profielen').getFirstListItem(`gebruiker = "${U.jongere3}"`);
    await su.collection(assertHh('hh_profielen')).update(p3.id, { verificatiestatus: 'in_behandeling' });
    try {
      r = await accepteer(j3, k02.id);
      check(`niet-goedgekeurde jongere -> 403 (kreeg ${r.status})`, r.status === 403 && r.body?.reden === 'nietgoedgekeurd', JSON.stringify(r.body));
    } finally {
      await su.collection(assertHh('hh_profielen')).update(p3.id, { verificatiestatus: 'goedgekeurd' });
    }
    const p3Na = await su.collection('hh_profielen').getOne(p3.id);
    check('jongere 3 staat weer op goedgekeurd', p3Na.verificatiestatus === 'goedgekeurd');

    r = await accepteer(j3, k02.id);
    check(`andere wijk (jongere 3 Passewaaij op k02 Tiel-West) -> 409 (kreeg ${r.status})`, r.status === 409 && r.body?.reden === 'wijk', JSON.stringify(r.body));
    check('  melding is Nederlands', typeof r.body?.melding === 'string' && r.body.melding.includes('wijk'), JSON.stringify(r.body));

    r = await accepteer(j1, 'bestaatnietxx01');
    check(`onbekende klus -> 404 (kreeg ${r.status})`, r.status === 404, JSON.stringify(r.body));

    const naE = await su.collection('hh_klussen').getOne(k02.id);
    check('k02 is na de weigeringen nog open zonder jongere', naE.status === 'open' && !naE.toegewezen_jongere);
  }

  kop(`F. RACE: jongere 1 en 2 accepteren k02 tegelijk, ${RONDEN} ronden`);
  {
    let goedeRonden = 0;
    let winnaars = { jongere1: 0, jongere2: 0 };
    const uitkomsten = [];
    for (let ronde = 1; ronde <= RONDEN; ronde++) {
      await su.collection(assertHh('hh_klussen')).update(k02.id, { status: 'open', toegewezen_jongere: '' });
      for (const log of await accepteerLogs(su, k02.id)) await su.collection('hh_klus_status').delete(log.id);

      const [r1, r2] = await Promise.all([accepteer(j1, k02.id), accepteer(j2, k02.id)]);
      const statussen = [r1.status, r2.status].sort();
      const logs = await accepteerLogs(su, k02.id);
      const klus = await su.collection('hh_klussen').getOne(k02.id);
      const winnaar = r1.status === 200 ? U.jongere1 : r2.status === 200 ? U.jongere2 : '';
      const ok =
        statussen[0] === 200 &&
        statussen[1] === 409 &&
        logs.length === 1 &&
        klus.status === 'geaccepteerd' &&
        klus.toegewezen_jongere === winnaar &&
        logs[0].door === winnaar &&
        logs[0].van === 'open';
      if (ok) {
        goedeRonden++;
        if (winnaar === U.jongere1) winnaars.jongere1++;
        else winnaars.jongere2++;
      }
      uitkomsten.push(`${ronde}:${r1.status}/${r2.status}/log${logs.length}${ok ? '' : '!'}`);
    }
    console.log(`  ronden: ${uitkomsten.join(' ')}`);
    check(`${goedeRonden}/${RONDEN} ronden precies één 200, één 409 en één logregel (winnaars: j1 ${winnaars.jongere1}, j2 ${winnaars.jongere2})`, goedeRonden === RONDEN);
    const bezet = await accepteer(j2, k02.id);
    check(`409-melding luidt "Deze klus is net door iemand anders aangenomen." (kreeg: ${bezet.body?.melding})`, bezet.status === 409 && bezet.body?.melding === 'Deze klus is net door iemand anders aangenomen.');
  }

  kop('G. Gewone acceptatie van k11 door jongere 1');
  {
    const r = await accepteer(j1, k11.id);
    check(`jongere 1 accepteert k11 -> 200 (kreeg ${r.status})`, r.status === 200 && r.body?.status === 'geaccepteerd' && r.body?.toegewezen_jongere === U.jongere1, JSON.stringify(r.body));
    const klus = await j1.collection('hh_klussen').getOne(k11.id);
    check('k11 staat op geaccepteerd met jongere 1 (gelezen als jongere 1)', klus.status === 'geaccepteerd' && klus.toegewezen_jongere === U.jongere1);
    const logs = await j1.collection('hh_klus_status').getFullList({ filter: `klus = "${k11.id}" && naar = "geaccepteerd"` });
    check('precies één logregel open -> geaccepteerd door jongere 1', logs.length === 1 && logs[0].door === U.jongere1 && logs[0].van === 'open');
    const nogmaals = await accepteer(j1, k11.id);
    check(`tweede poging op dezelfde klus -> 409 (kreeg ${nogmaals.status})`, nogmaals.status === 409 && nogmaals.body?.reden === 'bezet');
    const oudere = await j1.collection('hh_users').getOne(U.hulpvrager1).catch(() => null);
    check('na accepteren ziet jongere 1 de oudere (naam en adres) via de bestaande rule', !!oudere && !!oudere.naam);
  }

  kop('H. Terugzetten (einde) en nameten');
  {
    if (geoKlusId) {
      try {
        await su.collection(assertHh('hh_klussen')).delete(geoKlusId);
      } catch (_) {
        // al weg
      }
    }
    const tellingEind = await terugzetten(su);
    for (const key of SEED_OPEN) {
      const klus = await seedKlus(su, key);
      check(`${key} is open zonder jongere, ${tellingEind[key]} logregels (begin ${tellingBegin[key]})`, klus.status === 'open' && !klus.toegewezen_jongere && tellingEind[key] === tellingBegin[key]);
    }
    const eigen = await su.collection('hh_klussen').getFullList({ filter: `omschrijving ~ "${MERK}"` });
    check('geen eigen [accepteercheck]-klussen achtergebleven', eigen.length === 0);
  }

  console.log(`\n${groen} groen, ${rood} rood (${groen + rood} checks).`);
  if (rood > 0) process.exit(1);
}

main().catch(fail);
