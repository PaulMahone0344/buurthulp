// HeitjeHulp B4 stap 1 — velden en categorieën voor "klus plaatsen".
// ADDITIEF en idempotent; alleen hh_-collecties (hard-guard). Er wordt geen
// enkele klus aangeraakt en geen klustype verwijderd.
//
//   hh_klussen
//     + foto                  1-3 afbeeldingen (jpg/png/heic), max 5 MB,
//                             PROTECTED: alleen met een bestandstoken van wie
//                             de klus mag zien (bewoner, coordinator, de
//                             toegewezen helper en helpers die de goedgekeurde
//                             klus in hun lijst zien). De hook eist er één bij
//                             het plaatsen door een bewoner.
//     + nee_lijst_akkoord     ja/nee: "Mijn klus valt hier niet onder"
//     + klus_goedgekeurd_op   datum  ┐ alleen coordinator (101) en de
//     + klus_goedgekeurd_door -> hh_users, geen cascade │ keur-route
//     + klus_afgekeurd_op     datum  │ (hh_klusplaatsen.pb.js)
//     + klus_afkeur_reden     tekst, max 300 ┘
//     + controle_markering    keuze, meerdere: telefoon | email | link |
//                             neelijst (voorfilter van de hook; blokkeert niet)
//     + min_leeftijd          getal: max van categorie en tijdregel (hook)
//     + geboren_uiterlijk     datum: klusdag min min_leeftijd jaar (hook);
//                             de lijst-rule vergelijkt de geboortedatum van
//                             de helper hiermee (een rule kan niet rekenen)
//   hh_klustypes
//     + min_leeftijd          getal (10 / 13 / 16; besluit punt 6, voorstel)
//     + actief                ja/nee; nieuw veld = nee voor de 6 oude types
//     + volgorde              getal (volgorde van de tegels in de app)
//   hh_klustypes rijen
//     + de 13 categorieën uit de mockup (actief, met min_leeftijd en volgorde)
//     ~ de 6 oude types krijgen ALLEEN een min_leeftijd (OUDE_KLUSTYPES_
//       MIN_LEEFTIJD); actief blijft nee. De klussen die ernaar verwijzen
//       blijven precies zoals ze zijn. Een type dat niet in die lijst staat:
//       niets aangepast, wel gemeld (dan telt hij veilig als 18).
//
// VOLGORDE: 100 -> 103 (hooks) -> 101 (rules; leunen op deze velden) -> 104.
//
// DRAAIEN (eerst 00-backup.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/100-b4-velden.mjs            (dry-run)
//   node scripts/100-b4-velden.mjs --apply

import path from 'node:path';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

/// Het hulpbestand van de hook is CommonJS-stijl (module.exports) voor de
/// JSVM; dit pakket is "type": "module". Daarom zo geladen, zoals de tests.
function laadHookHulp(naam) {
  const bron = readFileSync(path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'pb_hooks', naam), 'utf8');
  const module_ = { exports: {} };
  new Function('module', 'exports', bron)(module_, module_.exports);
  return module_.exports;
}
export const plaatsHulp = laadHookHulp('hh_klusplaatsen_hulp.js');

const MB = 1024 * 1024;
export const FOTO_TYPES = ['image/jpeg', 'image/png', 'image/heic', 'image/heif'];
export const MARKERINGEN = ['telefoon', 'email', 'link', 'neelijst'];

/// De nieuwe velden per collectie; [ids] = { hh_users } (voor de relatie).
export function b4Velden(ids) {
  return {
    hh_klussen: [
      { name: 'foto', type: 'file', maxSelect: 3, maxSize: 5 * MB, mimeTypes: FOTO_TYPES, protected: true },
      { name: 'nee_lijst_akkoord', type: 'bool' },
      { name: 'klus_goedgekeurd_op', type: 'date' },
      { name: 'klus_goedgekeurd_door', type: 'relation', collectionId: ids.hh_users, maxSelect: 1, cascadeDelete: false },
      { name: 'klus_afgekeurd_op', type: 'date' },
      { name: 'klus_afkeur_reden', type: 'text', max: 300 },
      { name: 'controle_markering', type: 'select', values: MARKERINGEN, maxSelect: MARKERINGEN.length },
      { name: 'min_leeftijd', type: 'number', onlyInt: true, min: 0, max: 99 },
      { name: 'geboren_uiterlijk', type: 'date' },
    ],
    hh_klustypes: [
      { name: 'min_leeftijd', type: 'number', onlyInt: true, min: 0, max: 99 },
      { name: 'actief', type: 'bool' },
      { name: 'volgorde', type: 'number', onlyInt: true, min: 0 },
    ],
  };
}

/// Namen zonder server (voor 101, 102 en de test).
export const B4_VELDNAMEN = Object.fromEntries(
  Object.entries(b4Velden({ hh_users: 'x' })).map(([c, v]) => [c, v.map((f) => f.name)]),
);

/// Wat de server met deze bestaande klustypes zou doen (puur, voor de test).
///   bestaand: [{ id, naam, min_leeftijd, actief, volgorde }]
/// Geeft { maak: [...categorieën], zet: [{ id, naam, min_leeftijd }], onbekend: [naam] }.
export function klustypePlan(bestaand) {
  const opNaam = new Map(bestaand.map((t) => [t.naam, t]));
  const maak = plaatsHulp.KLUS_CATEGORIEEN.filter((c) => !opNaam.has(c.naam)).map((c) => ({
    naam: c.naam,
    icoon: c.icoon,
    min_leeftijd: c.min_leeftijd,
    volgorde: c.volgorde,
    actief: true,
    richtduur: 60,
    richtvergoeding: 0,
  }));
  const nieuweNamen = new Set(plaatsHulp.KLUS_CATEGORIEEN.map((c) => c.naam));
  const zet = [];
  const onbekend = [];
  for (const t of bestaand) {
    if (nieuweNamen.has(t.naam)) continue;
    const min = plaatsHulp.OUDE_KLUSTYPES_MIN_LEEFTIJD[t.naam];
    if (min === undefined) {
      if (!t.min_leeftijd) onbekend.push(t.naam);
      continue;
    }
    if (t.min_leeftijd !== min) zet.push({ id: t.id, naam: t.naam, min_leeftijd: min });
  }
  return { maak, zet, onbekend };
}

async function velden(pb) {
  const users = await pb.collections.getOne(assertHh('hh_users'));
  let teDoen = 0;
  for (const [naam, gewenst] of Object.entries(b4Velden({ hh_users: users.id }))) {
    const col = await pb.collections.getOne(assertHh(naam));
    const bestaand = new Map(col.fields.map((f) => [f.name, f]));
    const ontbreekt = [];
    for (const f of gewenst) {
      const er = bestaand.get(f.name);
      if (er) {
        console.log(`  ✓ bestaat al: ${naam}.${f.name} (${er.type})${er.type === f.type ? '' : ` — LET OP: verwacht ${f.type}`}`);
        continue;
      }
      ontbreekt.push(f);
      const extra = f.values ? `: ${f.values.join(' | ')}` : f.protected ? ', protected' : '';
      console.log(`  ${APPLY ? '＋ voeg toe' : '+ ZOU toevoegen'}: ${naam}.${f.name} (${f.type}${extra})`);
    }
    teDoen += ontbreekt.length;
    if (!ontbreekt.length || !APPLY) continue;
    await pb.collections.update(col.id, { fields: [...col.fields, ...ontbreekt] });
    const na = new Set((await pb.collections.getOne(naam)).fields.map((f) => f.name));
    const mist = ontbreekt.filter((f) => !na.has(f.name)).map((f) => f.name);
    if (mist.length) throw new Error(`Na apply ontbreken nog op ${naam}: ${mist.join(', ')}`);
  }
  return teDoen;
}

async function klustypes(pb) {
  const bestaand = await pb.collection('hh_klustypes').getFullList({ sort: 'naam' });
  const plan = klustypePlan(bestaand);
  for (const c of plan.maak) {
    console.log(`  ${APPLY ? '＋ maak aan' : '+ ZOU aanmaken'}: klustype "${c.naam}" (vanaf ${c.min_leeftijd}, icoon ${c.icoon}, volgorde ${c.volgorde})`);
    if (APPLY) await pb.collection(assertHh('hh_klustypes')).create(c);
  }
  for (const z of plan.zet) {
    const aantal = (await pb.collection('hh_klussen').getList(1, 1, { filter: pb.filter('klustype = {:id}', { id: z.id }) })).totalItems;
    console.log(`  ${APPLY ? '↻ zet' : '~ ZOU zetten'}: oud klustype "${z.naam}" min_leeftijd = ${z.min_leeftijd} (blijft niet-actief; ${aantal} klus(sen) verwijzen ernaar, die blijven ongemoeid)`);
    if (APPLY) await pb.collection(assertHh('hh_klustypes')).update(z.id, { min_leeftijd: z.min_leeftijd });
  }
  for (const n of plan.onbekend) {
    console.log(`  ! onbekend klustype "${n}": niets aangepast; zonder min_leeftijd telt hij als 18. Vraag Ibrahim.`);
  }
  const al = bestaand.filter((t) => plaatsHulp.KLUS_CATEGORIEEN.some((c) => c.naam === t.naam));
  for (const t of al) console.log(`  ✓ categorie "${t.naam}" bestaat al`);
  return plan.maak.length + plan.zet.length;
}

async function main() {
  const pb = await superuserClient();
  logMode();
  const aantalVelden = await velden(pb);
  // In een dry-run bestaan min_leeftijd/actief/volgorde nog niet; het plan
  // leest ze dan als leeg (dat klopt: ze zijn ook leeg).
  const aantalTypes = await klustypes(pb);
  const totaal = aantalVelden + aantalTypes;
  if (!totaal) console.log('\nNiets te doen: alles staat er al.');
  else if (!APPLY) console.log(`\nDRY-RUN: ${aantalVelden} veld(en) en ${aantalTypes} klustype-wijziging(en). Draai met --apply.`);
  else console.log(`\n✓ ${aantalVelden} veld(en) en ${aantalTypes} klustype-wijziging(en). Daarna 103-hook-deploy.sh, dan 101.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
