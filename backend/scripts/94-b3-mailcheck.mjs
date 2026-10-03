// HeitjeHulp B3 — ALLEEN LEZEN: kan de server de ouder-mail versturen?
//
// De ouder-mail gaat via $app.newMailClient() met de GLOBALE SMTP-instelling
// van de gedeelde server (K4). Die instelling geldt voor alle apps op de
// server; B3 wijzigt hem NIET. Dit script kijkt alleen of hij aan staat en
// welke afzender de ouder te zien krijgt. Het verstuurt geen mail en kent
// geen --apply. Het wachtwoord van de SMTP-server wordt nooit getoond.
//
// AFZENDER (besluit Ibrahim 4 okt): de ouder-mail komt van "HeitjeHulp".
// Het adres komt uit HH_MAIL_AFZENDER in de omgeving van de PocketBase-
// dienst op de server (systemd). Dit script kan die server-omgeving NIET
// lezen (alleen REST): geef het adres dat op de server staat (of komt) zelf
// mee als HH_MAIL_AFZENDER bij het draaien. Leeg = het globale adres.
// Ligt dat adres op een ander domein dan de SMTP-gebruiker, dan waarschuwt
// het script: TransIP kan het weigeren of de mail komt in spam (SPF/DKIM).
//
// DRAAIEN:
//   set -a; . /Users/h/Desktop/qawayhabase/.env; set +a
//   node scripts/94-b3-mailcheck.mjs
//   HH_MAIL_AFZENDER=info@heitjehulp.nl node scripts/94-b3-mailcheck.mjs

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readFileSync } from 'node:fs';
import { superuserClient, fail, PB_URL } from './_lib.mjs';

const hier = path.dirname(fileURLToPath(import.meta.url));
const hulpModule = { exports: {} };
new Function('module', 'exports', readFileSync(path.join(hier, '..', 'pb_hooks', 'hh_ouder_hulp.js'), 'utf8'))(
  hulpModule,
  hulpModule.exports,
);
const { afzenderVoor } = hulpModule.exports;

const domein = (adres) => String(adres || '').trim().toLowerCase().split('@')[1] || '';

/// Wat de ouder als afzender ziet (precies zoals de hook het kiest) en of
/// het adres bij de SMTP-gebruiker past.
export function effectieveAfzender(instellingen, hhMailAfzender) {
  const a = afzenderVoor(hhMailAfzender, instellingen?.meta ?? {});
  const smtpGebruiker = String(instellingen?.smtp?.username ?? '');
  const ander = a.antwoordAan && domein(smtpGebruiker) && domein(a.van.address) !== domein(smtpGebruiker);
  return {
    adres: a.van.address,
    naam: a.van.name,
    antwoordAan: a.antwoordAan,
    waarschuwing: ander
      ? `HH_MAIL_AFZENDER is op ${domein(a.van.address)}, de SMTP-gebruiker op ${domein(smtpGebruiker)}: ` +
        'TransIP kan dit weigeren of de mail komt in spam. Eerst de mailbox en SMTP voor dat domein regelen (SPF/DKIM).'
      : '',
  };
}

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
  const instellingen = await pb.settings.getAll();
  const s = mailStand(instellingen);
  console.log(`  ${s.smtpAan ? '✓' : '✗'} SMTP staat ${s.smtpAan ? 'aan' : 'UIT'}${s.host ? ` (${s.host})` : ''}`);
  console.log(`  · globale afzender (alle apps, wordt NIET gewijzigd): "${s.afzenderNaam}" <${s.afzenderAdres}>`);
  const hh = process.env.HH_MAIL_AFZENDER || '';
  const a = effectieveAfzender(instellingen, hh);
  console.log(`  · HH_MAIL_AFZENDER (zoals meegegeven; de server-omgeving zelf is niet te lezen): ${hh || '(niet gezet)'}`);
  console.log(`  ✓ de ouder-mail komt van: "${a.naam}" <${a.adres}>${a.antwoordAan ? `, Reply-To ${a.antwoordAan}` : ', geen Reply-To'}`);
  if (a.waarschuwing) console.log(`  ! LET OP: ${a.waarschuwing}`);
  console.log(`  · appURL van de server: ${s.appUrl || '(leeg)'} — de link in de mail gebruikt https://heitjehulp.nl (hh_ouder_hulp.js BASIS_URL)`);
  if (!s.smtpAan) {
    console.log('\nZonder SMTP valt PocketBase terug op sendmail; NIET B3 laten uitrollen voordat dit is uitgezocht.');
    process.exitCode = 1;
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(fail);
