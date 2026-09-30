// HeitjeHulp M9 fix (30 sep 2026) — rechten-check in de rules repareren.
//
// PROBLEEM (gemeten op prod na 41): `@collection.hh_koppelingen.rechten ?=
// "meekijken"` is op een MEERKEUZEVELD (select, maxSelect 2) nooit waar. Het
// familielid zag daardoor niets meer (04-rulecheck: 8 rood). Met `?~` werkt
// het wel (gemeten: 0 -> 9 klussen zichtbaar).
//
// `~` is "bevat" (substring). Veilig hier: de enige waarden zijn "meekijken"
// en "plaatsen", die komen niet in elkaar voor.
//
// Wat het doet: in list/view/create/update/deleteRule van elke hh_-collectie
// wordt `.rechten ?= "` vervangen door `.rechten ?~ "`. Verder niets.
// Idempotent. 41 en 44 gebruiken sindsdien zelf `?~`.
//
// DRAAIEN (na 41 en 44):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/45-rechten-operator.mjs            (dry-run)
//   node scripts/45-rechten-operator.mjs --apply
// Terugdraaien: de backup van stap 00.

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

const RULE_KEYS = ['listRule', 'viewRule', 'createRule', 'updateRule', 'deleteRule'];
const FOUT = /\.rechten \?= "/g;

/// Puur: de gerepareerde rule, en hoeveel plekken er veranderden.
export function repareer(rule) {
  if (rule === null || rule === undefined) return { rule, aantal: 0 };
  const r = String(rule);
  const aantal = (r.match(FOUT) || []).length;
  return { rule: r.replace(FOUT, '.rechten ?~ "'), aantal };
}

async function main() {
  const pb = await superuserClient();
  logMode();
  const alle = await pb.collections.getFullList();
  let totaal = 0;
  for (const col of alle.filter((c) => c.name.startsWith('hh_'))) {
    const gewijzigd = {};
    for (const k of RULE_KEYS) {
      const { rule, aantal } = repareer(col[k]);
      if (aantal > 0) {
        gewijzigd[k] = rule;
        totaal += aantal;
        console.log(`  ${col.name}.${k}: ${aantal} plek(ken)`);
      }
    }
    if (!Object.keys(gewijzigd).length || !APPLY) continue;
    assertHh(col.name);
    await pb.collections.update(col.id, gewijzigd);
    console.log(`↻ ${col.name}: bijgewerkt`);
  }
  console.log(totaal ? `\n${totaal} plek(ken)${APPLY ? ' gerepareerd' : ' — dry-run, niets geschreven'}.` : '\n✓ niets te repareren.');
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
