// HeitjeHulp M9 — test van de pure rule-wikkel in 44-familie-lees-rules.mjs.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { metFamilie, FAMILIE_MEEKIJKEN, GEWENST, alleenActiefVoorFamilielid, FAMILIELID_ACTIEF } from '../scripts/44-familie-lees-rules.mjs';

const M8 = '@request.auth.id != "" && @request.auth.collectionName = "hh_users" && ontvanger = @request.auth.id';

test('voegt de familie-tak toe als OF naast de ontvanger', () => {
  const uit = metFamilie(M8);
  assert.ok(uit.includes(`(ontvanger = @request.auth.id || ${FAMILIE_MEEKIJKEN})`));
  assert.ok(uit.startsWith('@request.auth.id != ""'));
});

test('idempotent: twee keer wikkelen = een keer', () => {
  assert.equal(metFamilie(metFamilie(M8)), metFamilie(M8));
});

test('familie-tak vraagt actief EN meekijken op hetzelfde pad', () => {
  assert.match(FAMILIE_MEEKIJKEN, /ontvanger\.hh_koppelingen_via_oudere\.status \?= "actief"/);
  assert.match(FAMILIE_MEEKIJKEN, /ontvanger\.hh_koppelingen_via_oudere\.rechten \?~ "meekijken"/);
});

test('weigert lege of onbekende rule', () => {
  assert.throws(() => metFamilie(''));
  assert.throws(() => metFamilie(null));
  assert.throws(() => metFamilie('@request.auth.id != ""'));
});

test('alleen lezen verandert, bijwerken niet', () => {
  assert.deepEqual(Object.keys(GEWENST).sort(), ['listRule', 'viewRule']);
});

const KOPPEL_M1 =
  '@request.auth.id != "" && (oudere = @request.auth.id || familielid = @request.auth.id || @request.auth.rol = "coordinator")';

test('hh_koppelingen: familielid alleen bij actief, oudere en coordinator ongemoeid', () => {
  const uit = alleenActiefVoorFamilielid(KOPPEL_M1);
  assert.ok(uit.includes(`oudere = @request.auth.id || ${FAMILIELID_ACTIEF} ||`));
  assert.ok(uit.includes('@request.auth.rol = "coordinator"'));
  assert.equal(alleenActiefVoorFamilielid(uit), uit);
  assert.throws(() => alleenActiefVoorFamilielid('oudere = @request.auth.id'));
});
