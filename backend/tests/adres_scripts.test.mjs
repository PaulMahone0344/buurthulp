// HeitjeHulp ADRES — tests van de pure delen van de scripts 120 en 121
// (zonder server). Draaien: node --test backend/tests/*.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ADRES_VELDEN, ADRES_VELDNAMEN, ADRES_BRONNEN } from '../scripts/120-adres-velden.mjs';
import { beslis, netjesPostcode, nummerEnToevoeging } from '../scripts/121-adres-coordinaten.mjs';
import { TIEL, OCHTEN, AMSTERDAM, zelfdePunt } from '../scripts/_adressen.mjs';

test('120: precies de vier nieuwe velden, additief', () => {
  assert.deepEqual(ADRES_VELDNAMEN, ['toevoeging', 'lat', 'lon', 'adres_bron']);
  assert.deepEqual(ADRES_BRONNEN, ['pdok', 'handmatig', 'ongecontroleerd']);
  const toev = ADRES_VELDEN.find((f) => f.name === 'toevoeging');
  assert.equal(toev.max, 6);
  assert.equal(ADRES_VELDEN.find((f) => f.name === 'adres_bron').maxSelect, 1);
});

test('121: netjesPostcode en nummerEnToevoeging', () => {
  assert.equal(netjesPostcode('4001ma'), '4001 MA');
  assert.equal(netjesPostcode('4001'), null);
  assert.deepEqual(nummerEnToevoeging('12a', ''), { huisnummer: '12', toevoeging: 'a' });
  assert.deepEqual(nummerEnToevoeging('012', 'B'), { huisnummer: '12', toevoeging: 'B' });
  assert.equal(nummerEnToevoeging('', ''), null);
});

const pdok = (o) => ({ adres: 'Kerkstraat 1', toevoeging: '', weergave: 'Kerkstraat 1, 4001 MA Tiel', lat: 51.88, lon: 5.43, binnen_werkgebied: true, ...o });

test('121 beslis: één adres en dezelfde straat -> zet', () => {
  const b = beslis({ adres: 'kerkstraat 1' }, { gevonden: true, adressen: [pdok()] });
  assert.equal(b.actie, 'zet');
  assert.equal(beslis({ adres: '' }, { gevonden: true, adressen: [pdok()] }).actie, 'zet', 'helper zonder straat');
});

test('121 beslis: afwijkende straat, meerdere toevoegingen, niet gevonden, storing -> overslaan', () => {
  assert.match(beslis({ adres: 'Kerkstr 1' }, { gevonden: true, adressen: [pdok()] }).reden, /wijkt af/);
  assert.match(beslis({ adres: '' }, { gevonden: true, adressen: [pdok({ toevoeging: 'a' }), pdok({ toevoeging: 'b' })] }).reden, /2 adressen/);
  assert.equal(beslis({ adres: '' }, { gevonden: true, adressen: [pdok(), pdok({ toevoeging: 'a' })] }).actie, 'zet', 'kale nummer bestaat');
  assert.equal(beslis({}, { gevonden: false, reden: 'nietgevonden' }).reden, 'niet gevonden');
  assert.equal(beslis({}, { gevonden: false, reden: 'dienst' }).reden, 'PDOK onbereikbaar');
  assert.equal(beslis({}, null).reden, 'PDOK onbereikbaar');
});

test('_adressen: de vaste checkadressen liggen waar ze horen', () => {
  assert.ok(zelfdePunt(TIEL, { lat: 51.88761538, lon: 5.43597055 }));
  assert.ok(!zelfdePunt(TIEL, OCHTEN));
  assert.ok(AMSTERDAM.lat > 52.3);
});
