// HeitjeHulp feedbackronde 1 punt F — het pure deel van script 160 (zonder
// server). Draaien: node --test backend/tests/*.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { WONING_VELDEN, WONING_VELDNAMEN, WONING_TYPES, JA_NEE } from '../scripts/160-woning-velden.mjs';

test('160: precies de vijf woonvelden, additief', () => {
  assert.deepEqual(WONING_VELDNAMEN, ['woning_type', 'verdieping', 'lift', 'trap', 'bereikbaarheid']);
  assert.deepEqual(WONING_TYPES, ['huis', 'appartement', 'anders']);
  assert.deepEqual(JA_NEE, ['ja', 'nee']);
  for (const f of WONING_VELDEN.filter((v) => v.type === 'select')) {
    assert.equal(f.maxSelect, 1, f.name);
  }
  assert.equal(WONING_VELDEN.find((f) => f.name === 'bereikbaarheid').max, 300);
});

test('160: dezelfde waarden als de app (hh_gegevens.dart)', async () => {
  const { readFile } = await import('node:fs/promises');
  const bron = await readFile(new URL('../../app/lib/features/hulpvrager/model/hh_gegevens.dart', import.meta.url), 'utf8');
  for (const w of [...WONING_TYPES, ...JA_NEE, ...WONING_VELDNAMEN]) {
    assert.match(bron, new RegExp(`'${w}'`), w);
  }
});
