/// B4 besluit punt 7 (voorstel; exacte grenzen volgen van de jurist): een
/// klus die vóór 07:00 begint, na 19:00 eindigt, zonder eindtijd na 17:00
/// begint of langer dan 2 uur duurt, is alleen voor helpers van 18+.
///
/// Antwoord Ibrahim 4 okt: helpers van 10 t/m 14 moeten om 18:00 klaar zijn
/// (zonder eindtijd: uiterlijk 16:00 begonnen); anders pas vanaf 15.
///
/// De SERVER beslist (backend/pb_hooks/hh_klusplaatsen_hulp.js); de app
/// rekent hetzelfde uit om de bewoner vooraf te waarschuwen. Minuten na
/// middernacht, lokale (Nederlandse) tijd, op één dag.
const vroegsteStartMinuten = 7 * 60;
const laatsteEindMinuten = 19 * 60;
const laatsteStartZonderEindMinuten = 17 * 60;
const maxDuurMinuten = 2 * 60;
const jongTotEnMet = 14;
const laatsteEindJongMinuten = 18 * 60;
const laatsteStartZonderEindJongMinuten = 16 * 60;

bool isAlleenVoor18Plus({required int vanaf, int? tot}) {
  final eind = tot != null && tot > vanaf ? tot : null;
  if (vanaf < vroegsteStartMinuten) return true;
  if (eind == null) return vanaf > laatsteStartZonderEindMinuten;
  if (eind - vanaf > maxDuurMinuten) return true;
  return eind > laatsteEindMinuten;
}

/// Hoe oud moet een helper zijn door de TIJD van de klus? 0 = geen grens,
/// 15 = eindigt na 18:00 (of zonder eindtijd na 16:00), 18 = buiten het
/// venster voor onder 18. Zelfde als tijdMinLeeftijd op de server.
int tijdMinLeeftijd({required int vanaf, int? tot}) {
  if (isAlleenVoor18Plus(vanaf: vanaf, tot: tot)) return 18;
  final eind = tot != null && tot > vanaf ? tot : null;
  final isLaat = eind == null
      ? vanaf > laatsteStartZonderEindJongMinuten
      : eind > laatsteEindJongMinuten;
  return isLaat ? jongTotEnMet + 1 : 0;
}
