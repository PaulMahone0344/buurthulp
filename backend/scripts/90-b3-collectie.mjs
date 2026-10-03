// HeitjeHulp B3 stap 1 — collectie hh_ouder_toestemming (ouder-toestemming
// met een code). NIEUWE collectie, raakt geen enkele bestaande collectie of
// rij aan (hard-guard op hh_). Idempotent: bestaat hij al, dan alleen
// ontbrekende velden/indexen erbij en de rules gelijkgetrokken.
//
// WAAROM EEN EIGEN COLLECTIE (en geen velden op hh_users)
//   - code_hash, token_hash en de ouder-sessie mogen NOOIT via de API te
//     lezen zijn, ook niet door de helper zelf. Op hh_users leest de helper
//     zijn eigen rij; hier leest alleen de coordinator, en de hash-velden
//     zijn ook voor hem "hidden".
//   - IBAN, naam ouder en het AVP-vinkje horen bij de ouder, niet bij het
//     account van het kind; de onRecordEnrich van hh_users hoeft niets te
//     verbergen.
//   - Eén rij per helper (unieke index op helper). Opnieuw sturen schrijft
//     dezelfde rij over; intrekken laat hem staan als bewijs.
//   - Het RESULTAAT staat wel op hh_users (B1-velden ouder_toestemming_op en
//     ouder_iban_ok): de lijst-rule van hh_klussen (B2) en de accepteer-hook
//     kijken daar al naar. Intrekken wist dat veld = direct geen klussen.
//
// VELDEN
//   helper               relatie hh_users, verplicht, 1, cascade (verwijder
//                        je de helper, dan verdwijnt deze rij mee)
//   ouder_email          e-mail, verplicht
//   code_hash            tekst, HIDDEN  sha256("hh-ouder-code:<helper>:<code>")
//   code_verloopt_op     datum (24 uur na versturen)
//   pogingen             getal >= 0 (max 5 foute codes)
//   token_hash           tekst, HIDDEN  sha256 van de link-token
//   sessie_hash          tekst, HIDDEN  sha256 van de ouder-sessie
//   sessie_verloopt_op   datum (30 minuten)
//   status               keuze, verplicht: verstuurd | gegeven | ingetrokken |
//                        verlopen | vrijgegeven (de meldkamer gaf het kind na
//                        intrekken een nieuwe kans; daarna mag het weer mailen)
//   ouder_naam           tekst, max 100
//   iban                 tekst, max 34 (ouder vult in; mag rekening kind zijn)
//   avp_verklaard        ja/nee ("ik heb een aansprakelijkheidsverzekering")
//   verstuur_dag         tekst, max 10 (UTC-dag van de teller "3 per dag")
//   verstuur_aantal      getal >= 0
//   laatst_verstuurd_op  datum
//   gegeven_op           datum
//   ingetrokken_op       datum
//   vrijgegeven_op       datum   (meldkamer, na intrekken)
//   vrijgegeven_door     relatie hh_users (coordinator), geen cascade
//   created, updated
// INDEXEN  uniek op helper; token_hash; ouder_email
// RULES    lezen (list/view) alleen coordinator; aanmaken, bijwerken en
//          verwijderen NIEMAND (null): alles loopt via hh_ouder.pb.js ($app).
//
// DRAAIEN (eerst 00-backup.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/90-b3-collectie.mjs            (dry-run)
//   node scripts/90-b3-collectie.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';
import { COORD } from './61-beheer-rules.mjs';

export const COLLECTIE = 'hh_ouder_toestemming';
export const STATUSSEN = ['verstuurd', 'gegeven', 'ingetrokken', 'verlopen', 'vrijgegeven'];
/// Velden die nooit in een API-antwoord mogen staan (ook niet voor de coordinator).
export const GEHEIM = ['code_hash', 'token_hash', 'sessie_hash'];

export const ALLEEN_COORDINATOR = `@request.auth.id != "" && ${COORD}`;
export const B3_RULES = {
  listRule: ALLEEN_COORDINATOR,
  viewRule: ALLEEN_COORDINATOR,
  createRule: null,
  updateRule: null,
  deleteRule: null,
};

const AUTODATES = [
  { name: 'created', type: 'autodate', onCreate: true, onUpdate: false },
  { name: 'updated', type: 'autodate', onCreate: true, onUpdate: true },
];

export function toestemmingVelden(ids) {
  const geheim = (name) => ({ name, type: 'text', max: 200, hidden: true });
  return [
    { name: 'helper', type: 'relation', collectionId: ids.hh_users, maxSelect: 1, required: true, cascadeDelete: true },
    { name: 'ouder_email', type: 'email', required: true },
    geheim('code_hash'),
    { name: 'code_verloopt_op', type: 'date' },
    { name: 'pogingen', type: 'number', min: 0, onlyInt: true },
    geheim('token_hash'),
    geheim('sessie_hash'),
    { name: 'sessie_verloopt_op', type: 'date' },
    { name: 'status', type: 'select', values: STATUSSEN, maxSelect: 1, required: true },
    { name: 'ouder_naam', type: 'text', max: 100 },
    { name: 'iban', type: 'text', max: 34 },
    { name: 'avp_verklaard', type: 'bool' },
    { name: 'verstuur_dag', type: 'text', max: 10 },
    { name: 'verstuur_aantal', type: 'number', min: 0, onlyInt: true },
    { name: 'laatst_verstuurd_op', type: 'date' },
    { name: 'gegeven_op', type: 'date' },
    { name: 'ingetrokken_op', type: 'date' },
    // Na intrekken eerst de meldkamer (antwoord Ibrahim 4 okt).
    { name: 'vrijgegeven_op', type: 'date' },
    { name: 'vrijgegeven_door', type: 'relation', collectionId: ids.hh_users, maxSelect: 1, cascadeDelete: false },
    ...AUTODATES,
  ];
}

export const INDEXEN = [
  `CREATE UNIQUE INDEX idx_hh_ouder_toestemming_helper ON ${COLLECTIE} (helper)`,
  `CREATE INDEX idx_hh_ouder_toestemming_token ON ${COLLECTIE} (token_hash)`,
  `CREATE INDEX idx_hh_ouder_toestemming_email ON ${COLLECTIE} (ouder_email)`,
];

const zelfde = (a, b) => String(a).replace(/\s+/g, ' ') === String(b).replace(/\s+/g, ' ');

async function main() {
  assertHh(COLLECTIE);
  const pb = await superuserClient();
  logMode();

  const users = await pb.collections.getOne(assertHh('hh_users'));
  const nodig = ['ouder_email', 'ouder_toestemming_op', 'ouder_iban_ok', 'geboortedatum'];
  const mist = nodig.filter((v) => !users.fields.some((f) => f.name === v));
  if (mist.length) throw new Error(`hh_users mist ${mist.join(', ')} — eerst B1 (70-b1-velden.mjs).`);
  const gewenst = toestemmingVelden({ hh_users: users.id });

  let bestaand = null;
  try {
    bestaand = await pb.collections.getOne(COLLECTIE);
  } catch (_) {
    bestaand = null;
  }

  if (!bestaand) {
    console.log(`  ${APPLY ? '＋ maak aan' : '+ ZOU aanmaken'}: ${COLLECTIE} (base, ${gewenst.length} velden)`);
    for (const f of gewenst) console.log(`      ${f.name} (${f.type}${f.hidden ? ', hidden' : ''})`);
    for (const idx of INDEXEN) console.log(`      index: ${idx}`);
    for (const [k, v] of Object.entries(B3_RULES)) console.log(`      ${k}: ${JSON.stringify(v)}`);
    if (!APPLY) {
      console.log('\nDRY-RUN: de collectie zou worden aangemaakt. Draai met --apply.');
      return;
    }
    await pb.collections.create({ name: COLLECTIE, type: 'base', fields: gewenst, indexes: INDEXEN, ...B3_RULES });
    const na = await pb.collections.getOne(COLLECTIE);
    controleer(na, gewenst);
    console.log(`\n✓ ${COLLECTIE} aangemaakt met ${na.fields.length} velden, ${na.indexes.length} index(en) en de rules.`);
    return;
  }

  const aanwezig = new Set(bestaand.fields.map((f) => f.name));
  const ontbreekt = gewenst.filter((f) => !aanwezig.has(f.name));
  // Keuzewaarden alleen AANVULLEN (bv. status "vrijgegeven" erbij).
  let keuzesErbij = 0;
  const velden = bestaand.fields.map((f) => {
    const wens = gewenst.find((g) => g.name === f.name && g.type === 'select' && f.type === 'select');
    const mist = wens ? wens.values.filter((v) => !f.values.includes(v)) : [];
    if (!mist.length) return f;
    keuzesErbij += mist.length;
    console.log(`  ${APPLY ? '＋ keuze' : '+ ZOU keuze'}: ${COLLECTIE}.${f.name} + ${mist.join(', ')}`);
    return { ...f, values: [...f.values, ...mist] };
  });
  for (const f of gewenst) {
    if (aanwezig.has(f.name)) console.log(`  ✓ bestaat al: ${COLLECTIE}.${f.name}`);
    else console.log(`  ${APPLY ? '＋ voeg toe' : '+ ZOU toevoegen'}: ${COLLECTIE}.${f.name} (${f.type})`);
  }
  const huidig = bestaand.indexes || [];
  const nieuweIndexen = INDEXEN.filter((idx) => !huidig.some((h) => zelfde(h, idx)));
  for (const idx of nieuweIndexen) console.log(`  ${APPLY ? '＋ index' : '+ ZOU index'}: ${idx}`);
  const ruleWijzigingen = Object.fromEntries(Object.entries(B3_RULES).filter(([k, v]) => (bestaand[k] ?? null) !== v));
  for (const [k, v] of Object.entries(ruleWijzigingen)) {
    console.log(`  ${APPLY ? '↻' : '+ ZOU'} ${k}: ${JSON.stringify(bestaand[k] ?? null)} -> ${JSON.stringify(v)}`);
  }
  if (!ontbreekt.length && !keuzesErbij && !nieuweIndexen.length && !Object.keys(ruleWijzigingen).length) {
    console.log('\nNiets te doen: collectie, velden, indexen en rules staan er al.');
    return;
  }
  if (!APPLY) {
    console.log('\nDRY-RUN: zie hierboven. Draai met --apply.');
    return;
  }
  await pb.collections.update(bestaand.id, {
    fields: [...velden, ...ontbreekt],
    indexes: [...huidig, ...nieuweIndexen],
    ...ruleWijzigingen,
  });
  const na = await pb.collections.getOne(COLLECTIE);
  controleer(na, gewenst);
  console.log(`\n✓ ${COLLECTIE} bijgewerkt.`);
}

function controleer(na, gewenst) {
  const namen = new Map(na.fields.map((f) => [f.name, f]));
  const mist = gewenst.filter((f) => !namen.has(f.name)).map((f) => f.name);
  if (mist.length) throw new Error(`Na apply ontbreken: ${mist.join(', ')}`);
  const open = GEHEIM.filter((n) => namen.get(n)?.hidden !== true);
  if (open.length) throw new Error(`Na apply NIET hidden: ${open.join(', ')}`);
  for (const [k, v] of Object.entries(B3_RULES)) {
    if ((na[k] ?? null) !== v) throw new Error(`Na apply klopt ${k} niet`);
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
