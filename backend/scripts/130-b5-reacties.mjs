// HeitjeHulp B5 stap 1 — reageren en kiezen: nieuwe collectie hh_reacties,
// plus drie additieve velden op bestaande collecties en de soort "reactie" op
// hh_meldingen.soort. Idempotent en additief: bestaat iets al, dan wordt
// alleen wat ontbreekt bijgemaakt; bestaande velden en keuzewaarden worden
// nooit gewijzigd of verwijderd. GEEN datamigratie (geen bestaande rij wordt
// aangeraakt). Raakt alleen hh_reacties, hh_profielen, hh_beoordelingen,
// hh_meldingen en hh_incidenten aan (hard-guard op hh_).
//
// API-rules van hh_reacties blijven hier op null (= alleen superuser). Die
// komen in 131-b5-rules.mjs.
//
// VELDEN hh_reacties (PROMPT-B5)
//   klus               relatie hh_klussen, verplicht; verdwijnt mee met de klus
//   helper             relatie hh_users, verplicht; verdwijnt mee met het account
//   bericht            tekst, max 200 (optioneel; zelfde filter als de chat:
//                      nummers/mail/links -> "•••")
//   bericht_gefilterd  ja/nee: de hook verving iets (markering meldkamer)
//   status             wacht_op_ouder | open | gekozen | afgewezen |
//                      ingetrokken | vervallen
//   ouder_akkoord_op   datum: de ouder koos "Goed" (helper < 18)
//   ouder_besluit      goed | liever_niet
//   ouder_gaat_mee     ja/nee: "Mijn ouder gaat mee bij deze eerste klus"
//                      (helper 10-12, eerste klus bij deze bewoner)
//   ouder_gemaild_op   datum: wanneer de ouder de vraag kreeg
//   token_hash         tekst, HIDDEN: sha256 van de link-token in de ouder-mail
//   klus_samenvatting  tekst, max 200: "Tuin, zaterdag 10 oktober om 10:00"
//                      (de helper ziet zo ook een reactie op een klus die hij
//                      niet meer mag openen)
//   gekozen_op         datum
//   created/updated    automatisch
// INDEXEN
//   idx_hh_reacties_uniek  UNIEK (klus, helper)  — één reactie per helper per klus
//   idx_hh_reacties_helper (helper)
//   idx_hh_reacties_token  (token_hash)
//
// EXTRA VELDEN (additief)
//   hh_profielen.beschikbaar_tot      datum: "Ik kan nu helpen" (nu + 3 uur);
//                                     zet alleen de route (hook weigert de body)
//   hh_beoordelingen.alles_in_orde    ja | nee: de geheime vraag (punt 11);
//                                     alleen gever + meldkamer zien hem
//   hh_beoordelingen.geheim_toelichting tekst, max 300
//   hh_meldingen.soort + "reactie"    de live keuzelijst wordt alleen aangevuld
//   hh_incidenten.soort + "signaal"   antwoord Ibrahim 4: "nee" op de geheime
//                                     vraag is een zachtere soort, geen probleem
//
// DRAAIEN (eerst 00-backup.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/130-b5-reacties.mjs            (dry-run)
//   node scripts/130-b5-reacties.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

export const COLLECTIE = 'hh_reacties';
export const MELDINGEN = 'hh_meldingen';
export const MELDING_SOORT_REACTIE = 'reactie';
export const REACTIE_STATUSSEN = ['wacht_op_ouder', 'open', 'gekozen', 'afgewezen', 'ingetrokken', 'vervallen'];
export const MAX_BERICHT = 200;

const AUTODATES = [
  { name: 'created', type: 'autodate', onCreate: true, onUpdate: false },
  { name: 'updated', type: 'autodate', onCreate: true, onUpdate: true },
];

export function reactieVelden(ids) {
  return [
    { name: 'klus', type: 'relation', collectionId: ids.hh_klussen, maxSelect: 1, required: true, cascadeDelete: true },
    { name: 'helper', type: 'relation', collectionId: ids.hh_users, maxSelect: 1, required: true, cascadeDelete: true },
    { name: 'bericht', type: 'text', required: false, min: 0, max: MAX_BERICHT },
    { name: 'bericht_gefilterd', type: 'bool' },
    { name: 'status', type: 'select', values: REACTIE_STATUSSEN, maxSelect: 1, required: true },
    { name: 'ouder_akkoord_op', type: 'date' },
    { name: 'ouder_besluit', type: 'select', values: ['goed', 'liever_niet'], maxSelect: 1 },
    { name: 'ouder_gaat_mee', type: 'bool' },
    { name: 'ouder_gemaild_op', type: 'date' },
    { name: 'token_hash', type: 'text', max: 100, hidden: true },
    { name: 'klus_samenvatting', type: 'text', max: 200 },
    { name: 'gekozen_op', type: 'date' },
    ...AUTODATES,
  ];
}

export const REACTIE_INDEXEN = [
  `CREATE UNIQUE INDEX idx_hh_reacties_uniek ON ${COLLECTIE} (klus, helper)`,
  `CREATE INDEX idx_hh_reacties_helper ON ${COLLECTIE} (helper)`,
  `CREATE INDEX idx_hh_reacties_token ON ${COLLECTIE} (token_hash)`,
];

export const EXTRA_VELDEN = {
  hh_profielen: [{ name: 'beschikbaar_tot', type: 'date' }],
  hh_beoordelingen: [
    { name: 'alles_in_orde', type: 'select', values: ['ja', 'nee'], maxSelect: 1 },
    { name: 'geheim_toelichting', type: 'text', max: 300 },
  ],
};

export const INCIDENT_SOORT_SIGNAAL = 'signaal';

/// Een live keuzelijst, aangevuld met [waarde]. Niets wordt weggehaald of
/// herschikt; staat hij er al, dan blijft de lijst gelijk.
export function metKeuze(live, waarde) {
  const lijst = Array.isArray(live) ? [...live] : [];
  return lijst.includes(waarde) ? lijst : [...lijst, waarde];
}

/// De live keuzelijst van hh_meldingen.soort, aangevuld met "reactie".
export function metSoortReactie(live) {
  return metKeuze(live, MELDING_SOORT_REACTIE);
}

function omschrijf(f) {
  if (f.type === 'select') return `select: ${f.values.join(' | ')}`;
  if (f.type === 'relation') return 'relation';
  return f.max ? `${f.type}, max ${f.max}${f.hidden ? ', hidden' : ''}` : f.type;
}

async function haalIds(pb) {
  const ids = {};
  for (const naam of ['hh_users', 'hh_klussen']) {
    assertHh(naam);
    ids[naam] = (await pb.collections.getOne(naam)).id;
  }
  return ids;
}

async function reacties(pb) {
  assertHh(COLLECTIE);
  const gewenst = reactieVelden(await haalIds(pb));
  let bestaand = null;
  try {
    bestaand = await pb.collections.getOne(COLLECTIE);
  } catch (_) {
    bestaand = null;
  }
  if (!bestaand) {
    console.log(`  ${APPLY ? '＋ maak aan' : '+ ZOU aanmaken'}: ${COLLECTIE} (base, ${gewenst.length} velden)`);
    for (const f of gewenst) console.log(`      ${f.name} (${omschrijf(f)})`);
    for (const idx of REACTIE_INDEXEN) console.log(`      index: ${idx}`);
    if (!APPLY) return 1;
    await pb.collections.create({
      name: COLLECTIE,
      type: 'base',
      fields: gewenst,
      indexes: REACTIE_INDEXEN,
      // Dicht tot 131-b5-rules.mjs draait.
      listRule: null,
      viewRule: null,
      createRule: null,
      updateRule: null,
      deleteRule: null,
    });
    const na = await pb.collections.getOne(COLLECTIE);
    console.log(`  ✓ ${COLLECTIE} aangemaakt met ${na.fields.length} velden en ${na.indexes.length} index(en).`);
    return 1;
  }
  const aanwezig = new Set(bestaand.fields.map((f) => f.name));
  const ontbreekt = gewenst.filter((f) => !aanwezig.has(f.name));
  for (const f of gewenst) {
    if (aanwezig.has(f.name)) console.log(`  ✓ bestaat al: ${COLLECTIE}.${f.name}`);
    else console.log(`  ${APPLY ? '＋ voeg toe' : '+ ZOU toevoegen'}: ${COLLECTIE}.${f.name} (${omschrijf(f)})`);
  }
  const huidig = bestaand.indexes || [];
  const norm = (s) => s.replace(/[`"]/g, '').replace(/\s+/g, ' ').trim();
  const nieuweIdx = REACTIE_INDEXEN.filter((idx) => !huidig.some((h) => norm(h) === norm(idx)));
  for (const idx of nieuweIdx) console.log(`  ${APPLY ? '＋ index' : '+ ZOU index'}: ${idx}`);
  if (!ontbreekt.length && !nieuweIdx.length) return 0;
  if (!APPLY) return ontbreekt.length + nieuweIdx.length;
  await pb.collections.update(bestaand.id, { fields: [...bestaand.fields, ...ontbreekt], indexes: [...huidig, ...nieuweIdx] });
  console.log(`  ✓ ${COLLECTIE} bijgewerkt.`);
  return ontbreekt.length + nieuweIdx.length;
}

async function extraVelden(pb) {
  let aantal = 0;
  for (const [naam, velden] of Object.entries(EXTRA_VELDEN)) {
    assertHh(naam);
    const col = await pb.collections.getOne(naam);
    const bestaand = new Map(col.fields.map((f) => [f.name, f]));
    const ontbreekt = [];
    for (const f of velden) {
      const er = bestaand.get(f.name);
      if (er) {
        console.log(`  ✓ bestaat al: ${naam}.${f.name} (${er.type})${er.type === f.type ? '' : ` — LET OP: verwacht ${f.type}, niet aangepast`}`);
        continue;
      }
      ontbreekt.push(f);
      console.log(`  ${APPLY ? '＋ voeg toe' : '+ ZOU toevoegen'}: ${naam}.${f.name} (${omschrijf(f)})`);
    }
    if (!ontbreekt.length) continue;
    aantal += ontbreekt.length;
    if (!APPLY) continue;
    await pb.collections.update(col.id, { fields: [...col.fields, ...ontbreekt] });
    const na = new Set((await pb.collections.getOne(naam)).fields.map((f) => f.name));
    const mist = ontbreekt.filter((f) => !na.has(f.name)).map((f) => f.name);
    if (mist.length) throw new Error(`Na apply ontbreken nog op ${naam}: ${mist.join(', ')}`);
    console.log(`  ✓ ${naam}: ${ontbreekt.length} veld(en) toegevoegd`);
  }
  return aantal;
}

/// Vult de keuzelijst van [naam].soort aan met [waarde] (de rest blijft
/// letterlijk staan).
async function soortErbij(pb, naam, waarde) {
  assertHh(naam);
  const col = await pb.collections.getOne(naam);
  const veld = col.fields.find((f) => f.name === 'soort');
  if (!veld) throw new Error(`${naam}.soort bestaat niet.`);
  const nieuw = metKeuze(veld.values, waarde);
  if (nieuw.length === veld.values.length) {
    console.log(`  ✓ ${naam}.soort kent "${waarde}" al`);
    return 0;
  }
  console.log(`  ${APPLY ? '＋ keuze' : '+ ZOU keuze toevoegen'}: ${naam}.soort "${waarde}"`);
  console.log(`      was:    ${veld.values.join(' | ')}`);
  console.log(`      wordt:  ${nieuw.join(' | ')}`);
  if (!APPLY) return 1;
  // Alleen de keuzelijst van dit ene veld; alle andere velden letterlijk terug.
  const velden = col.fields.map((f) => (f.name === 'soort' ? { ...f, values: nieuw } : f));
  await pb.collections.update(col.id, { fields: velden });
  const na = (await pb.collections.getOne(naam)).fields.find((f) => f.name === 'soort');
  if (!na.values.includes(waarde)) throw new Error(`Na apply ontbreekt "${waarde}" nog.`);
  console.log(`  ✓ ${naam}.soort: ${na.values.join(' | ')}`);
  return 1;
}

const meldingSoort = (pb) => soortErbij(pb, MELDINGEN, MELDING_SOORT_REACTIE);

/// Antwoord Ibrahim 4: "nee" op de geheime vraag = incident soort "signaal".
const incidentSoort = (pb) => soortErbij(pb, 'hh_incidenten', INCIDENT_SOORT_SIGNAAL);

async function main() {
  const pb = await superuserClient();
  logMode();
  const a = await reacties(pb);
  const b = await extraVelden(pb);
  const c = await meldingSoort(pb);
  const d = await incidentSoort(pb);
  const n = a + b + c + d;
  if (!n) console.log('\nNiets te doen: hh_reacties, de extra velden en de meldingsoort staan er al.');
  else if (!APPLY) console.log(`\nDRY-RUN: ${n} wijziging(en). Draai met --apply.`);
  else console.log('\nKlaar. Rules van hh_reacties: 131-b5-rules.mjs.');
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
