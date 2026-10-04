// HeitjeHulp ADRES — vaste, ECHTE adressen voor de checks (04, 62, 72, 82,
// 122) en de nep-PDOK van de lokale proef. Nagekeken bij PDOK op 4 okt 2026
// (BAG). Elk adres kost op prod hooguit één PDOK-verzoek per 10 minuten: de
// server onthoudt het antwoord (hh_adres_hulp.js, CACHE_MS).

/// Kerkstraat 1, 4001 MA Tiel: binnen het werkgebied (Tiel + 20 km).
export const TIEL = {
  postcode: '4001 MA',
  huisnummer: '1',
  straat: 'Kerkstraat',
  adres: 'Kerkstraat 1',
  plaats: 'Tiel',
  gemeente: 'Tiel',
  lat: 51.88761538,
  lon: 5.43597055,
};

/// Kerkstraat 2, 4051 AB Ochten: een dorp binnen 20 km (~9 km).
export const OCHTEN = {
  postcode: '4051 AB',
  huisnummer: '2',
  straat: 'Kerkstraat',
  adres: 'Kerkstraat 2',
  plaats: 'Ochten',
  gemeente: 'Neder-Betuwe',
  lat: 51.90834062,
  lon: 5.56531025,
};

/// Dam 1, 1012 JS Amsterdam: buiten het werkgebied.
export const AMSTERDAM = {
  postcode: '1012 JS',
  huisnummer: '1',
  straat: 'Dam',
  adres: 'Dam 1',
  plaats: 'Amsterdam',
  gemeente: 'Amsterdam',
  lat: 52.37329259,
  lon: 4.8937175,
};

/// Bestaat niet (postcode wel, huisnummer niet).
export const NIET_BESTAAND = { postcode: '4001 MA', huisnummer: '9999' };

/// Voor registreren/bijwerken: alleen wat de app stuurt.
export const invoer = (a, extra = {}) => ({ postcode: a.postcode, huisnummer: a.huisnummer, ...extra });

/// Liggen twee punten op een paar meter na op elkaar (afronding)?
export const zelfdePunt = (x, y) =>
  Math.abs(Number(x?.lat) - Number(y?.lat)) < 1e-6 && Math.abs(Number(x?.lon) - Number(y?.lon)) < 1e-6;

/// Afstand in km tussen twee punten (haversine), zoals de server rekent.
export function afstandKm(a, b) {
  const rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad;
  const dLon = (b.lon - a.lon) * rad;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLon / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.min(1, Math.sqrt(h)));
}
