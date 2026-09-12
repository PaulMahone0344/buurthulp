// HeitjeHulp M1 stap 2 — schema-export van ALLE collecties op de gedeelde
// PocketBase naar backend/backups/<datum>.json. Alleen-lezen: dit script
// schrijft nooit naar de server.
//
// Twee standen:
//   node scripts/00-backup.mjs
//       exporteert alle collecties (naam, type, velden, indexen, rules,
//       created/updated) naar backups/<datum>.json en print het pad.
//   node scripts/00-backup.mjs --vergelijk backups/<datum>.json
//       vergelijkt de huidige server met een eerdere export: telt de
//       collecties, meldt elke NIET-hh_-collectie waarvan `updated` (of het
//       bestaan) afwijkt, en somt de hh_-collecties op. Exit 1 bij afwijking.
//
// De hard-guard geldt ook hier: in de vergelijking telt élke wijziging aan een
// collectie zonder hh_-prefix als fout, ongeacht wie hem veroorzaakte.

import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, isHh, stamp, fail, PB_URL } from './_lib.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BACKUP_DIR = path.resolve(__dirname, '..', 'backups');

const vergelijkIdx = process.argv.indexOf('--vergelijk');
const VERGELIJK = vergelijkIdx > -1 ? process.argv[vergelijkIdx + 1] : null;

function snapshot(cols) {
  return cols
    .map((c) => ({
      id: c.id,
      name: c.name,
      type: c.type,
      system: c.system,
      created: c.created,
      updated: c.updated,
      fields: c.fields,
      indexes: c.indexes,
      listRule: c.listRule,
      viewRule: c.viewRule,
      createRule: c.createRule,
      updateRule: c.updateRule,
      deleteRule: c.deleteRule,
    }))
    .sort((a, b) => a.name.localeCompare(b.name));
}

async function main() {
  const pb = await superuserClient();
  const cols = snapshot(await pb.collections.getFullList());
  console.log(`Verbonden met ${PB_URL} — ${cols.length} collecties gelezen.`);

  if (!VERGELIJK) {
    mkdirSync(BACKUP_DIR, { recursive: true });
    const file = path.join(BACKUP_DIR, `${stamp()}.json`);
    writeFileSync(file, JSON.stringify({ exportedAt: new Date().toISOString(), url: PB_URL, count: cols.length, collections: cols }, null, 2));
    const hh = cols.filter((c) => isHh(c.name)).map((c) => c.name);
    console.log(`Backup geschreven: ${file}`);
    console.log(`Niet-hh_: ${cols.length - hh.length}, hh_: ${hh.length}${hh.length ? ' (' + hh.join(', ') + ')' : ''}`);
    return;
  }

  const oud = JSON.parse(readFileSync(path.resolve(VERGELIJK), 'utf8'));
  const oudMap = new Map(oud.collections.map((c) => [c.name, c]));
  const nuMap = new Map(cols.map((c) => [c.name, c]));

  const oudNietHh = oud.collections.filter((c) => !isHh(c.name));
  const nuNietHh = cols.filter((c) => !isHh(c.name));
  const nuHh = cols.filter((c) => isHh(c.name));

  const problemen = [];
  for (const c of oudNietHh) {
    const n = nuMap.get(c.name);
    if (!n) problemen.push(`VERDWENEN: ${c.name}`);
    else if (n.updated !== c.updated) problemen.push(`GEWIJZIGD: ${c.name} (updated ${c.updated} → ${n.updated})`);
    else if (JSON.stringify(n.fields) !== JSON.stringify(c.fields)) problemen.push(`VELDEN AFWIJKEND: ${c.name}`);
  }
  for (const c of nuNietHh) {
    if (!oudMap.has(c.name)) problemen.push(`NIEUW ZONDER hh_-PREFIX: ${c.name}`);
  }

  console.log(`Backup ${path.basename(VERGELIJK)}: ${oud.collections.length} collecties (${oudNietHh.length} niet-hh_).`);
  console.log(`Nu op server: ${cols.length} collecties = ${nuNietHh.length} niet-hh_ + ${nuHh.length} hh_.`);
  console.log(`Verwacht: ${oudNietHh.length} + ${nuHh.length} = ${oudNietHh.length + nuHh.length} → ${cols.length === oudNietHh.length + nuHh.length ? 'KLOPT' : 'KLOPT NIET'}`);
  console.log('hh_-collecties:', nuHh.map((c) => `${c.name} (${c.fields.length} velden)`).join(', ') || '(geen)');

  if (problemen.length) {
    console.log('\nAFWIJKINGEN IN NIET-hh_-COLLECTIES:');
    for (const p of problemen) console.log('  ✗', p);
    process.exit(1);
  }
  console.log('\n✓ Geen enkele niet-hh_-collectie gewijzigd.');
}

main().catch(fail);
