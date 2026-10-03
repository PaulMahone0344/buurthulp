// HeitjeHulp ADRES stap 3 — bestaande accounts krijgen hun PDOK-punt
// (4 okt 2026). DRY-RUN STANDAARD.
//
// Zoekt bewoners en helpers (hh_users, rol hulpvrager of jongere) met een
// geldige 6-tekens-postcode en een huisnummer, maar nog zonder adres_bron, en
// vraagt via de eigen server-route GET /api/hh/adres (als superuser: geen
// rate-limit, dezelfde PDOK-logica en cache als de hook) het adres op.
//   Precies één adres en de opgeslagen straat (als die er is) klopt
//     -> zet ALLEEN lat, lon en adres_bron = "pdok".
//   Verder NIETS: straat, plaats, postcode, wijk en werkgebied_status blijven
//   zoals ze zijn (geen datamigratie). Wat afwijkt staat in de lijst; dat
//   past de gebruiker zelf aan via Mijn gegevens (gele balk "Vul je adres aan").
// Overgeslagen (met reden): onvolledig adres, niet gevonden, meerdere
// toevoegingen, straat wijkt af, PDOK onbereikbaar.
// Werkgebied: alleen ter informatie toont het script waar het exacte punt
// een ander werkgebied geeft dan wat er staat (85 blijft de wijk zetten).
//
// VOORWAARDE: 120 --apply en 123-hook-deploy.sh (de route moet er zijn).
//
//   node scripts/121-adres-coordinaten.mjs           dry-run (schrijft niets)
//   node scripts/121-adres-coordinaten.mjs --apply   schrijft naar prod
// Superuser uit de omgeving: set -a; . /Users/h/Desktop/qawayhabase/.env; set +a

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

/// Rustig aan voor PDOK (gratis dienst): hooguit ~4 verzoeken per seconde.
const TUSSENPOOS_MS = 250;
const slaap = (ms) => new Promise((r) => setTimeout(r, ms));

export function netjesPostcode(pc) {
  const m = /^([1-9]\d{3})\s*([A-Za-z]{2})$/.exec(String(pc || '').trim());
  return m ? `${m[1]} ${m[2].toUpperCase()}` : null;
}

/// "12a" -> { huisnummer: "12", toevoeging: "a" }; ook met een los
/// toevoeging-veld. null als het niet met een cijfer begint.
export function nummerEnToevoeging(huisnummer, toevoeging) {
  const m = /^(\d{1,5})\s*-?\s*(.*)$/.exec(String(huisnummer || '').trim());
  if (!m) return null;
  return { huisnummer: String(Number(m[1])), toevoeging: String(toevoeging || '').trim() || m[2].trim() };
}

const sleutel = (t) => String(t || '').toLowerCase().replace(/[\s,.-]+/g, '');

/// Wat doet 121 met dit account? { actie: 'zet' | 'sla over', reden, adres }
export function beslis(u, antwoord) {
  if (!antwoord) return { actie: 'sla over', reden: 'PDOK onbereikbaar' };
  if (!antwoord.gevonden) {
    const reden = antwoord.reden === 'toevoeging' ? 'toevoeging onbekend' : antwoord.reden === 'dienst' ? 'PDOK onbereikbaar' : 'niet gevonden';
    return { actie: 'sla over', reden };
  }
  const lijst = antwoord.adressen || [];
  const kaal = lijst.filter((a) => !a.toevoeging);
  const adres = lijst.length === 1 ? lijst[0] : kaal.length === 1 && !String(u.toevoeging || '').trim() ? kaal[0] : null;
  if (!adres) return { actie: 'sla over', reden: `${lijst.length} adressen (toevoeging kiezen)` };
  const eigen = String(u.adres || '').trim();
  if (eigen && sleutel(eigen) !== sleutel(adres.adres)) {
    return { actie: 'sla over', reden: `straat wijkt af ("${eigen}" vs PDOK "${adres.adres}")`, adres };
  }
  return { actie: 'zet', adres };
}

async function main() {
  const pb = await superuserClient();
  logMode();
  const users = await pb.collection(assertHh('hh_users')).getFullList({
    filter: '(rol = "hulpvrager" || rol = "jongere") && adres_bron = ""',
    fields: 'id,naam,rol,adres,postcode,huisnummer,toevoeging,plaats,werkgebied_status,wijk',
  });
  const teller = { gezet: 0, zou: 0, overgeslagen: 0, onvolledig: 0 };
  const anders = [];

  for (const u of users) {
    const pc = netjesPostcode(u.postcode);
    const nt = nummerEnToevoeging(u.huisnummer, u.toevoeging);
    if (!pc || !nt) {
      teller.onvolledig++;
      console.log(`  · onvolledig (gele balk): ${u.id} ${u.naam} (${u.rol}) pc "${u.postcode}" nr "${u.huisnummer}"`);
      continue;
    }
    await slaap(TUSSENPOOS_MS);
    let antwoord = null;
    try {
      antwoord = await pb.send('/api/hh/adres', {
        method: 'GET',
        query: { postcode: pc, huisnummer: nt.huisnummer, toevoeging: nt.toevoeging },
      });
    } catch (e) {
      antwoord = e?.status === 400 ? { gevonden: false, reden: 'nietgevonden' } : null;
    }
    const b = beslis(u, antwoord);
    if (b.actie !== 'zet') {
      teller.overgeslagen++;
      console.log(`  - sla over: ${u.id} ${u.naam} (${u.rol}) ${pc} ${nt.huisnummer}${nt.toevoeging} — ${b.reden}`);
      continue;
    }
    const werk = b.adres.binnen_werkgebied ? 'binnen' : 'buiten';
    if (u.werkgebied_status && u.werkgebied_status !== werk) anders.push(`${u.id} ${u.naam}: staat "${u.werkgebied_status}", punt zegt "${werk}"`);
    console.log(`  ${APPLY ? '↻ zet' : '+ ZOU zetten'}: ${u.id} ${u.naam} (${u.rol}) ${b.adres.weergave} -> ${b.adres.lat}, ${b.adres.lon}`);
    if (APPLY) {
      await pb.collection(assertHh('hh_users')).update(u.id, { lat: b.adres.lat, lon: b.adres.lon, adres_bron: 'pdok' });
      teller.gezet++;
    } else {
      teller.zou++;
    }
  }

  console.log(`\n${users.length} bewoner(s)/helper(s) zonder adres_bron: ${APPLY ? teller.gezet + ' gezet' : teller.zou + ' zou(den) gezet worden'}, ${teller.overgeslagen} overgeslagen, ${teller.onvolledig} onvolledig.`);
  if (anders.length) {
    console.log('\nTer informatie (NIET aangepast): het exacte punt geeft een ander werkgebied dan er staat:');
    for (const r of anders) console.log(`  ! ${r}`);
  }
  console.log(APPLY ? '✓ klaar.' : 'DRY-RUN: niets geschreven. Draai met --apply.');
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
