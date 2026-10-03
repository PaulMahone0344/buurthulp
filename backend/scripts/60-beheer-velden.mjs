// HeitjeHulp M14 stap 1 — velden en collecties voor het beheerpaneel.
// ADDITIEF en idempotent: wat er al staat wordt overgeslagen, bestaande velden
// worden nooit gewijzigd of verwijderd. Alleen hh_-collecties (hard-guard).
//
//   hh_profielen  + screening_notitie  tekst, max 1000 (D2: notitie bij
//                                      goedkeuren/afkeuren; alleen de
//                                      coordinator schrijft, zie 61)
//                 + vog_geldig_tot     datum (D2: signaal "VOG verloopt
//                                      binnen 60 dagen"; alleen coordinator)
//                 + intake_op          datum (D2: intakegesprek gehad op;
//                                      leeg = nog niet; alleen coordinator.
//                                      Besluit Ibrahim 2 okt)
//   hh_users      + geblokkeerd        ja/nee (D4: account blokkeren; de hook
//                                      hh_beheer.pb.js weigert dan inloggen en
//                                      elke hh-aanroep; alleen coordinator)
//   hh_instellingen  NIEUW  sleutel (tekst, verplicht, uniek), waarde (json)
//                    commissiepercentage, straal_km, annuleertermijn_uren.
//                    Alleen opslaan; er hangt nog geen gedrag aan.
//   hh_auditlog      NIEUW  door (hh_users), actie (aanmaken|wijzigen|
//                    verwijderen), doel_collectie, doel_id, detail (json).
//                    Schrijven doet alleen de hook (via $app).
//
// De rules van de twee nieuwe collecties blijven hier null (alleen superuser);
// die zet 61-beheer-rules.mjs.
//
// DRAAIEN (eerst 00-backup.mjs):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/60-beheer-velden.mjs            (dry-run)
//   node scripts/60-beheer-velden.mjs --apply

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

export const AUDIT_ACTIES = ['aanmaken', 'wijzigen', 'verwijderen'];

const AUTODATES = [
  { name: 'created', type: 'autodate', onCreate: true, onUpdate: false },
  { name: 'updated', type: 'autodate', onCreate: true, onUpdate: true },
];

/// Nieuwe velden op bestaande collecties.
export const EXTRA_VELDEN = {
  hh_profielen: [
    { name: 'screening_notitie', type: 'text', max: 1000 },
    { name: 'vog_geldig_tot', type: 'date' },
    { name: 'intake_op', type: 'date' },
  ],
  hh_users: [{ name: 'geblokkeerd', type: 'bool' }],
};

/// De twee nieuwe collecties. ids = { hh_users: '<collectie-id>' }.
export function nieuweCollecties(ids) {
  return {
    hh_instellingen: {
      fields: [
        { name: 'sleutel', type: 'text', required: true, max: 100 },
        { name: 'waarde', type: 'json', maxSize: 10000 },
        ...AUTODATES,
      ],
      indexes: ['CREATE UNIQUE INDEX idx_hh_instellingen_sleutel ON hh_instellingen (sleutel)'],
    },
    hh_auditlog: {
      fields: [
        // Niet verplicht en geen cascade: een regel blijft staan, ook als de
        // coordinator later verwijderd wordt.
        { name: 'door', type: 'relation', collectionId: ids.hh_users, maxSelect: 1, cascadeDelete: false },
        { name: 'actie', type: 'select', values: AUDIT_ACTIES, maxSelect: 1, required: true },
        { name: 'doel_collectie', type: 'text', required: true, max: 100 },
        { name: 'doel_id', type: 'text', max: 100 },
        { name: 'detail', type: 'json', maxSize: 20000 },
        ...AUTODATES,
      ],
      indexes: [
        'CREATE INDEX idx_hh_auditlog_door ON hh_auditlog (door)',
        'CREATE INDEX idx_hh_auditlog_created ON hh_auditlog (created)',
      ],
    },
  };
}

async function velden(pb) {
  let teDoen = 0;
  for (const [naam, gewenst] of Object.entries(EXTRA_VELDEN)) {
    assertHh(naam);
    const col = await pb.collections.getOne(naam);
    const bestaand = new Set(col.fields.map((f) => f.name));
    const ontbreekt = gewenst.filter((f) => !bestaand.has(f.name));
    for (const f of gewenst) {
      if (bestaand.has(f.name)) console.log(`  ✓ bestaat al: ${naam}.${f.name}`);
      else console.log(`  ${APPLY ? '＋ voeg toe' : '+ ZOU toevoegen'}: ${naam}.${f.name} (${f.type})`);
    }
    if (!ontbreekt.length) continue;
    teDoen += ontbreekt.length;
    if (!APPLY) continue;
    await pb.collections.update(col.id, { fields: [...col.fields, ...ontbreekt] });
    const na = await pb.collections.getOne(naam);
    const naNamen = new Set(na.fields.map((f) => f.name));
    const mist = ontbreekt.filter((f) => !naNamen.has(f.name)).map((f) => f.name);
    if (mist.length) throw new Error(`Na apply ontbreken nog op ${naam}: ${mist.join(', ')}`);
  }
  return teDoen;
}

async function collecties(pb) {
  const users = await pb.collections.getOne('hh_users');
  let teDoen = 0;
  for (const [naam, def] of Object.entries(nieuweCollecties({ hh_users: users.id }))) {
    assertHh(naam);
    let bestaand = null;
    try {
      bestaand = await pb.collections.getOne(naam);
    } catch (_) {
      bestaand = null;
    }
    if (!bestaand) {
      teDoen++;
      console.log(`  ${APPLY ? '＋ maak aan' : '+ ZOU aanmaken'}: ${naam} (base, ${def.fields.length} velden)`);
      for (const f of def.fields) console.log(`      ${f.name} (${f.type})`);
      if (!APPLY) continue;
      await pb.collections.create({
        name: naam,
        type: 'base',
        fields: def.fields,
        indexes: def.indexes,
        listRule: null,
        viewRule: null,
        createRule: null,
        updateRule: null,
        deleteRule: null,
      });
      console.log(`  ✓ ${naam} aangemaakt`);
      continue;
    }
    const aanwezig = new Set(bestaand.fields.map((f) => f.name));
    const ontbreekt = def.fields.filter((f) => !aanwezig.has(f.name));
    const huidigeIndexen = bestaand.indexes || [];
    const nieuweIndexen = def.indexes.filter(
      (idx) => !huidigeIndexen.some((h) => h.replace(/\s+/g, ' ') === idx.replace(/\s+/g, ' ')),
    );
    if (!ontbreekt.length && !nieuweIndexen.length) {
      console.log(`  ✓ bestaat al: ${naam}`);
      continue;
    }
    teDoen += ontbreekt.length + nieuweIndexen.length;
    for (const f of ontbreekt) console.log(`  ${APPLY ? '＋ voeg toe' : '+ ZOU toevoegen'}: ${naam}.${f.name}`);
    for (const i of nieuweIndexen) console.log(`  ${APPLY ? '＋ index' : '+ ZOU index'}: ${i}`);
    if (!APPLY) continue;
    await pb.collections.update(bestaand.id, {
      fields: [...bestaand.fields, ...ontbreekt],
      indexes: [...huidigeIndexen, ...nieuweIndexen],
    });
  }
  return teDoen;
}

async function main() {
  const pb = await superuserClient();
  logMode();
  const a = await velden(pb);
  const b = await collecties(pb);
  if (!a && !b) console.log('\nNiets te doen: alles staat er al.');
  else if (!APPLY) console.log(`\nDRY-RUN: ${a + b} wijziging(en) zouden worden doorgevoerd. Draai met --apply.`);
  else console.log(`\n✓ ${a + b} wijziging(en) doorgevoerd. Draai nu 61-beheer-rules.mjs.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
