// HeitjeHulp M3 stap 1 — voegt de screeningvelden ADDITIEF toe aan
// hh_profielen. Bestaande velden, indexen, rules en rijen blijven staan;
// geen enkele andere collectie wordt aangeraakt.
//
// Nieuw op hh_profielen:
//   over_mij            tekst, max 500
//   document_foto       1 bestand, alleen afbeeldingen, max 10 MB, protected
//   selfie              1 bestand, alleen afbeeldingen, max 10 MB, protected
//   iban                tekst, max 34
//   vog_aangevraagd_op  datum
//
// "protected" betekent: het bestand is alleen op te halen met een
// bestandstoken van iemand die het record mag zien (eigenaar of coordinator).
// 07-screeningcheck.mjs bewijst dat een oudere er niet bij kan.
//
// Idempotent: velden die al bestaan worden overgeslagen (op naam), nooit
// gewijzigd. Draai eerst 00-backup.mjs.
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/05-screening-velden.mjs            (dry-run)
//   node scripts/05-screening-velden.mjs --apply

import { superuserClient, assertHh, APPLY, logMode, fail } from './_lib.mjs';

const COLLECTIE = 'hh_profielen';
const AFBEELDING_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif', 'image/gif'];
const MB = 1024 * 1024;

const beschermdeFoto = (name) => ({
  name,
  type: 'file',
  maxSelect: 1,
  maxSize: 10 * MB,
  mimeTypes: AFBEELDING_TYPES,
  protected: true,
});

export const SCREENING_VELDEN = [
  { name: 'over_mij', type: 'text', max: 500 },
  beschermdeFoto('document_foto'),
  beschermdeFoto('selfie'),
  { name: 'iban', type: 'text', max: 34 },
  { name: 'vog_aangevraagd_op', type: 'date' },
];

function beschrijf(f) {
  const extra = f.type === 'file' ? ` (${f.maxSize / MB} MB, protected)` : f.max ? ` (max ${f.max})` : '';
  return `${f.name}:${f.type}${extra}`;
}

async function main() {
  const pb = await superuserClient();
  logMode();

  assertHh(COLLECTIE);
  const bestaand = await pb.collections.getOne(COLLECTIE);
  const heeft = new Set(bestaand.fields.map((f) => f.name));
  const ontbreekt = SCREENING_VELDEN.filter((f) => !heeft.has(f.name));

  for (const f of SCREENING_VELDEN) {
    console.log(`  ${heeft.has(f.name) ? '✓ bestaat al' : APPLY ? '＋ toevoegen ' : '+ ZOU toevoegen'}: ${COLLECTIE}.${beschrijf(f)}`);
  }
  if (!ontbreekt.length) {
    console.log('\nAlle screeningvelden staan er al. Niets te doen.');
    return;
  }
  if (!APPLY) {
    console.log(`\nDry-run klaar. Niets geschreven. ${ontbreekt.length} veld(en) zouden worden toegevoegd; draai met --apply.`);
    return;
  }

  // Alleen fields meesturen: rules en indexen blijven zoals ze zijn.
  const bijgewerkt = await pb.collections.update(bestaand.id, {
    fields: [...bestaand.fields, ...ontbreekt],
  });
  const nu = new Set(bijgewerkt.fields.map((f) => f.name));
  const mist = SCREENING_VELDEN.filter((f) => !nu.has(f.name));
  if (mist.length) throw new Error(`Na update ontbreken nog: ${mist.map((f) => f.name).join(', ')}`);
  console.log(`\nKlaar. ${COLLECTIE} heeft nu ${bijgewerkt.fields.length} velden (was ${bestaand.fields.length}).`);
}

main().catch(fail);
