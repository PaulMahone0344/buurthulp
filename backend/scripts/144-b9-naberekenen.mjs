// HeitjeHulp B9 stap 6 (APART, eigen JA) — XP en badges voor klussen die al
// VÓÓR B9 afgerond waren. Dit is de enige "datamigratie" van B9: er komen
// NIEUWE rijen in hh_xp en hh_badges en xp_totaal/niveau op hh_profielen
// (de B9-velden); er wordt GEEN bestaande rij of bestaand veld van vóór B9
// gewijzigd. Zonder dit script krijgen helpers hun oude klussen pas bij hun
// eerstvolgende afgeronde klus of beoordeling erbij (werkXpBij rekent altijd
// alles opnieuw uit) — dan komt het als één grote "+N XP"-melding.
// Dit script stuurt GEEN meldingen.
//
// Werkt via de route POST /api/hh/xp/naberekenen (alleen superuser), zodat
// precies dezelfde rekenregel draait als in de hooks (hh_xp_hulp.js).
//
// DRAAIEN (na 140, 141, 143 en 142 groen):
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/144-b9-naberekenen.mjs            (droog: wie, hoeveel XP)
//   node scripts/144-b9-naberekenen.mjs --apply    (echt boeken)
//   node scripts/144-b9-naberekenen.mjs            (daarna: "niets te doen")

import { superuserClient, APPLY, logMode, fail, PB_URL } from './_lib.mjs';

async function main() {
  const su = await superuserClient();
  console.log('Verbonden met', PB_URL);
  logMode();
  const uit = await su.send('/api/hh/xp/naberekenen', { method: 'POST', body: { droog: !APPLY } });
  const lijst = uit.helpers || [];
  if (!lijst.length) {
    console.log('\nNiets te doen: alle helpers zijn bijgewerkt.');
    return;
  }
  const namen = new Map();
  for (const rij of lijst) {
    try {
      const u = await su.collection('hh_users').getOne(rij.helper, { fields: 'id,naam,email' });
      namen.set(rij.helper, `${u.naam} <${u.email}>`);
    } catch (_) {
      namen.set(rij.helper, rij.helper);
    }
  }
  let punten = 0;
  for (const rij of lijst) {
    const erbij = rij.boekingen.reduce((s, b) => s + b.punten, 0);
    punten += erbij;
    console.log(`  ${APPLY ? '↻' : '+ ZOU'} ${namen.get(rij.helper)}: ${rij.boekingen.length} boeking(en), ${erbij >= 0 ? '+' : ''}${erbij} XP -> totaal ${rij.totaal}, niveau ${rij.niveau}${rij.nieuwe_badges.length ? `, badges ${rij.nieuwe_badges.join(', ')}` : ''}`);
  }
  console.log(`\n${APPLY ? 'Geboekt' : 'DRY-RUN'}: ${lijst.length} helper(s), samen ${punten} XP.${APPLY ? '' : ' Draai met --apply.'}`);
}

main().catch(fail);
