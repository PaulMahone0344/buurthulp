// HeitjeHulp M1 — gedeelde helpers voor de backend-scripts.
//
// Alles hier draait via de REST-API van de GEDEELDE productie-PocketBase
// api.qawayahbase.com (v0.25.9, fields-API). Er staan 129 collecties van
// andere projecten op deze server. De hard-guard `assertHh` weigert elke
// collectienaam die niet met hh_ begint; elke schrijvende helper roept hem aan.
//
// Superuser-creds komen uit de omgeving: PB_SU_EMAIL / PB_SU_PASS (ObyCom-
// conventie) of, als terugval, PB_ADMIN_EMAIL / PB_ADMIN_PASSWORD (de namen in
// /Users/h/Desktop/qawayhabase/.env). Ze worden nergens gelogd of weggeschreven.

import PocketBase from 'pocketbase';

export const PB_URL = process.env.PB_URL || 'https://api.qawayahbase.com';
export const PREFIX = 'hh_';
export const APPLY = process.argv.includes('--apply');

const SU_EMAIL = process.env.PB_SU_EMAIL || process.env.PB_ADMIN_EMAIL;
const SU_PASS = process.env.PB_SU_PASS || process.env.PB_ADMIN_PASSWORD;

// Hard-guard: gooit bij elke naam die niet met hh_ begint. Wordt aangeroepen
// vóór elke create/update/delete op een collectie of record.
export function assertHh(name) {
  if (typeof name !== 'string' || !name.startsWith(PREFIX)) {
    throw new Error(`HARD-GUARD: "${name}" begint niet met ${PREFIX} — geweigerd.`);
  }
  return name;
}

export function isHh(name) {
  return typeof name === 'string' && name.startsWith(PREFIX);
}

export function requireCreds() {
  if (!SU_EMAIL || !SU_PASS) {
    throw new Error(
      'Zet PB_SU_EMAIL/PB_SU_PASS (of PB_ADMIN_EMAIL/PB_ADMIN_PASSWORD) in de omgeving: ' +
        'set -a; . /Users/h/Desktop/qawayhabase/.env; set +a',
    );
  }
}

// Nieuwe client, ingelogd als superuser.
export async function superuserClient() {
  requireCreds();
  const pb = new PocketBase(PB_URL);
  pb.autoCancellation(false);
  await pb.collection('_superusers').authWithPassword(SU_EMAIL, SU_PASS);
  return pb;
}

// Nieuwe client zonder login (anoniem) — voor de rulecheck.
export function anonClient() {
  const pb = new PocketBase(PB_URL);
  pb.autoCancellation(false);
  return pb;
}

// Nieuwe client, ingelogd als gewone hh_users-gebruiker — voor de rulecheck.
export async function userClient(email, password) {
  const pb = new PocketBase(PB_URL);
  pb.autoCancellation(false);
  await pb.collection('hh_users').authWithPassword(email, password);
  return pb;
}

export function logMode() {
  console.log('Verbonden met', PB_URL, APPLY ? '(APPLY)' : '(DRY-RUN)', '\n');
}

export function fail(e) {
  // Nooit de creds loggen; alleen de foutrespons.
  console.error('FOUT:', e?.response?.data ? JSON.stringify(e.response, null, 2) : e?.message || e);
  process.exit(1);
}

// Datumstempel voor bestandsnamen: 2026-09-12T14-05-33
export function stamp(d = new Date()) {
  return d.toISOString().replace(/\.\d{3}Z$/, '').replace(/:/g, '-');
}
