/// B4 besluit punt 7 (voorstel; exacte grenzen volgen van de jurist): een
/// klus die vóór 07:00 begint, na 19:00 eindigt, zonder eindtijd na 17:00
/// begint of langer dan 2 uur duurt, is alleen voor helpers van 18+.
///
/// De SERVER beslist (backend/pb_hooks/hh_klusplaatsen_hulp.js); de app
/// rekent hetzelfde uit om de bewoner vooraf te waarschuwen. Minuten na
/// middernacht, lokale (Nederlandse) tijd, op één dag.
const vroegsteStartMinuten = 7 * 60;
const laatsteEindMinuten = 19 * 60;
const laatsteStartZonderEindMinuten = 17 * 60;
const maxDuurMinuten = 2 * 60;

bool isAlleenVoor18Plus({required int vanaf, int? tot}) {
  final eind = tot != null && tot > vanaf ? tot : null;
  if (vanaf < vroegsteStartMinuten) return true;
  if (eind == null) return vanaf > laatsteStartZonderEindMinuten;
  if (eind - vanaf > maxDuurMinuten) return true;
  return eind > laatsteEindMinuten;
}
