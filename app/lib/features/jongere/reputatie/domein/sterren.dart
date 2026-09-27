import '../../../../l10n/teksten_beoordelen_nl.dart';

/// Hooguit zoveel tekens bij een beoordeling (prompt M7).
const maxTekstBeoordeling = 500;

/// Het gemiddelde zoals de app het TOONT: begrensd op 0-5 en op één decimaal,
/// .5 naar boven. Dit spiegelt alleen de afronding van de hook
/// (backend/pb_hooks/hh_reputatie.js, Math.round(x * 10) / 10) zodat een
/// waarde met meer decimalen er nooit anders uitziet dan op de server. De app
/// rekent nooit zelf een gemiddelde uit; dat doet de server.
double gemiddeldVoorWeergave(double gemiddeld) {
  if (gemiddeld.isNaN || gemiddeld <= 0) return 0;
  if (gemiddeld >= 5) return 5;
  return (gemiddeld * 10).round() / 10;
}

/// "4,3": met een komma en altijd één decimaal.
String sterrenTekst(double gemiddeld) =>
    gemiddeldVoorWeergave(gemiddeld).toStringAsFixed(1).replaceAll('.', ',');

/// De duim van O9 is alleen een opstapje: hij vult de sterren voor. Wat de
/// server krijgt, zijn alleen sterren en tekst.
enum Duim { omhoog, omlaag }

int sterrenVoorDuim(Duim duim) => switch (duim) {
  Duim.omhoog => 5,
  Duim.omlaag => 2,
};

bool isGeldigAantalSterren(int? sterren) =>
    sterren != null && sterren >= 1 && sterren <= 5;

bool isGeldigeBeoordelingTekst(String tekst) =>
    tekst.trim().length <= maxTekstBeoordeling;

/// Het aantal sterren in gewone woorden, voor de oudere en de schermlezer.
String sterrenWoord(int sterren) => switch (sterren) {
  <= 1 => TekstenBeoordelenNl.woordSlecht,
  2 => TekstenBeoordelenNl.woordNietGoed,
  3 => TekstenBeoordelenNl.woordGaatWel,
  4 => TekstenBeoordelenNl.woordGoed,
  _ => TekstenBeoordelenNl.woordHeelGoed,
};
