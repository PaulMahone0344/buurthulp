// HeitjeHulp B3 — ALLEEN LEZEN: kan de server de ouder-mail versturen?
//
// De ouder-mail gaat via $app.newMailClient() met de GLOBALE SMTP-instelling
// van de gedeelde server (K4). Die instelling geldt voor alle apps op de
// server; B3 wijzigt hem NIET. Dit script kijkt alleen of hij aan staat en
// welke afzender de ouder te zien krijgt. Het verstuurt geen mail en kent
// geen --apply. Het wachtwoord van de SMTP-server wordt nooit getoond.
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/94-b3-mailcheck.mjs

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { superuserClient, fail, PB_URL } from './_lib.mjs';

/// Wat de ouder ziet en of er mail uit kan; nooit geheimen.
export function mailStand(instellingen) {
  const smtp = instellingen?.smtp ?? {};
  const meta = instellingen?.meta ?? {};
  return {
    smtpAan: smtp.enabled === true,
    host: smtp.host ? `${smtp.host}:${smtp.port ?? ''}` : '',
    afzenderAdres: meta.senderAddress ?? '',
    afzenderNaam: meta.senderName ?? '',
    appUrl: meta.appURL ?? '',
  };
}

async function main() {
  if (process.argv.includes('--apply')) throw new Error('94 schrijft nooit; --apply bestaat hier niet.');
  const pb = await superuserClient();
  console.log('Verbonden met', PB_URL, '(ALLEEN LEZEN)\n');
  const s = mailStand(await pb.settings.getAll());
  console.log(`  ${s.smtpAan ? '✓' : '✗'} SMTP staat ${s.smtpAan ? 'aan' : 'UIT'}${s.host ? ` (${s.host})` : ''}`);
  console.log(`  · afzender: "${s.afzenderNaam}" <${s.afzenderAdres}>`);
  console.log(`  · appURL van de server: ${s.appUrl || '(leeg)'} — de link in de mail gebruikt https://heitjehulp.nl (hh_ouder_hulp.js BASIS_URL)`);
  if (!s.smtpAan) {
    console.log('\nZonder SMTP valt PocketBase terug op sendmail; NIET B3 laten uitrollen voordat dit is uitgezocht.');
    process.exitCode = 1;
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
