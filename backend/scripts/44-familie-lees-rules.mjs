// HeitjeHulp M9 stap 6 — twee leesrules, besluiten Ibrahim 30 sep 2026.
//
// 1. hh_meldingen: een familielid LEEST de meldingen van zijn oudere (F3
//    "Meldingen"): meekijken = ook de meldingen zien. Bijwerken
//    (gelezen_op) blijft alleen voor de ontvanger: het familielid zet een
//    melding van de oudere nooit op gelezen.
// 2. hh_koppelingen: een familielid ziet zijn eigen koppeling pas als die
//    ACTIEF is. Zo verraadt een aanvraag niet of een e-mailadres bij een
//    oudere hoort (OPEN-PUNTEN-M9 punt 4, optie a). De oudere en de
//    coordinator zien de aanvraag wel.
//
// Raakt ALLEEN listRule en viewRule van die twee collecties aan.
//
// De drie voorwaarden (familielid, status, rechten) staan op hetzelfde pad
// ontvanger.hh_koppelingen_via_oudere, dus ze gelden voor dezelfde rij (zie
// OPEN-PUNTEN-M9 punt 6).
//
// DRAAIEN (na 31-meldingen-rules.mjs EN 40-familie-velden.mjs; het veld
// hh_koppelingen.status moet bestaan; vóór 42-familiecheck):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/44-familie-lees-rules.mjs            (dry-run)
//   node scripts/44-familie-lees-rules.mjs --apply
//
// Terugdraaien: node scripts/31-meldingen-rules.mjs --apply (hh_meldingen)
// en de list/viewRule van hh_koppelingen uit de backup van stap 00.

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';
import { MELDINGEN_RULES } from './31-meldingen-rules.mjs';
import { COLLECTIE } from './30-meldingen-collectie.mjs';

const PAD = 'ontvanger.hh_koppelingen_via_oudere';
export const FAMILIE_MEEKIJKEN =
  `(@request.auth.rol = "familie" && ${PAD}.familielid ?= @request.auth.id && ` +
  `${PAD}.status ?= "actief" && ${PAD}.rechten ?= "meekijken")`;

const IK_BEN_ONTVANGER = 'ontvanger = @request.auth.id';

/// Puur: maakt van de M8-leesrule de M9-leesrule. Idempotent.
export function metFamilie(rule) {
  if (rule === null || rule === undefined || String(rule).trim() === '') {
    throw new Error('hh_meldingen leesrule is leeg of null — eerst 31 draaien.');
  }
  const r = String(rule);
  if (r.includes(FAMILIE_MEEKIJKEN)) return r;
  if (!r.includes(IK_BEN_ONTVANGER)) {
    throw new Error(`hh_meldingen leesrule onverwacht: ${r}`);
  }
  return r.replace(IK_BEN_ONTVANGER, `(${IK_BEN_ONTVANGER} || ${FAMILIE_MEEKIJKEN})`);
}

export const GEWENST = {
  listRule: metFamilie(MELDINGEN_RULES.listRule),
  viewRule: metFamilie(MELDINGEN_RULES.viewRule),
};

const FAMILIELID_ZELF = 'familielid = @request.auth.id';
export const FAMILIELID_ACTIEF = '(familielid = @request.auth.id && status = "actief")';

/// Puur: het familielid ziet zijn eigen koppeling alleen als die actief is.
/// Idempotent.
export function alleenActiefVoorFamilielid(rule) {
  if (rule === null || rule === undefined || String(rule).trim() === '') {
    throw new Error('hh_koppelingen leesrule is leeg of null.');
  }
  const r = String(rule);
  if (r.includes(FAMILIELID_ACTIEF)) return r;
  const delen = r.split(FAMILIELID_ZELF);
  if (delen.length !== 2) {
    throw new Error(`hh_koppelingen leesrule onverwacht: ${r}`);
  }
  return delen.join(FAMILIELID_ACTIEF);
}

async function zet(pb, naam, maak) {
  assertHh(naam);
  const current = await pb.collections.getOne(naam);
  const gewenst = { listRule: maak(current.listRule), viewRule: maak(current.viewRule) };
  const verschil = Object.keys(gewenst).filter((k) => current[k] !== gewenst[k]);
  if (!verschil.length) {
    console.log(`✓ ${naam}: al gezet`);
    return;
  }
  for (const k of verschil) {
    console.log(`  ${naam}.${k}:\n      was: ${JSON.stringify(current[k])}\n      wordt: ${JSON.stringify(gewenst[k])}`);
  }
  if (!APPLY) return;
  await pb.collections.update(current.id, gewenst);
  console.log(`↻ ${naam}: leesrules bijgewerkt`);
}

async function main() {
  const pb = await superuserClient();
  logMode();
  await zet(pb, COLLECTIE, metFamilie);
  await zet(pb, 'hh_koppelingen', alleenActiefVoorFamilielid);
  console.log(APPLY ? '\nKlaar.' : '\nDry-run klaar. Niets geschreven.');
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
