import 'package:flutter/foundation.dart';

import '../../../../l10n/teksten_klussen_nl.dart';
import '../../../../l10n/teksten_uitvoeren_nl.dart';
import '../../../../theme.dart';
import '../../../jongere/klussen/domein/wanneer_tekst.dart';
import '../../../jongere/uitvoeren/provider/uitvoeren_providers.dart';

/// Eén regel van het overzicht: een kop ("Hoelang") en een waarde.
@immutable
class OverzichtRegel {
  const OverzichtRegel(this.kop, this.waarde);

  final String kop;
  final String waarde;
}

/// Feedbackronde 1 punt C: wat, wanneer klaar, waar, wie, hoelang, bedrag
/// en betaling van een afgeronde klus. Wat er niet is, valt weg in plaats
/// van een lege regel; alleen de betaling staat er altijd (B7 volgt).
List<OverzichtRegel> afgerondOverzicht(KlusMetGeschiedenis k, DateTime nu) {
  final klus = k.klus;
  final klaar = k.tijdVan(HhKlusStatus.afgerond);
  final begonnen = k.tijdVan(HhKlusStatus.bezig);
  final bedrag = klus.bedragBrutoCenten > 0
      ? klus.bedragBrutoCenten
      : klus.vergoedingJongereCenten;

  return [
    OverzichtRegel(
      TekstenUitvoerenNl.o7WatKop,
      klus.omschrijving.isEmpty
          ? metHoofdletter(klus.klustypeNaam)
          : klus.omschrijving,
    ),
    if (klaar != null)
      OverzichtRegel(
        TekstenUitvoerenNl.o7KlaarKop,
        TekstenKlussenNl.wanneerZonderEind(
          dagTekst(klaar, nu),
          tijdTekst(klaar),
        ),
      ),
    if (klus.adres.isNotEmpty)
      OverzichtRegel(TekstenUitvoerenNl.o7WaarKop, klus.adres),
    if (klus.jongereVoornaam.isNotEmpty)
      OverzichtRegel(TekstenUitvoerenNl.o7WieKop, klus.jongereVoornaam),
    if (klaar != null && begonnen != null && !klaar.isBefore(begonnen))
      OverzichtRegel(
        TekstenUitvoerenNl.o7HoelangKop,
        duurTekst(klaar.difference(begonnen)),
      ),
    if (bedrag > 0)
      OverzichtRegel(
        TekstenUitvoerenNl.o7BedragKop,
        TekstenUitvoerenNl.o7BedragVoorbeeld(euroTekst(bedrag)),
      ),
    const OverzichtRegel(
      TekstenUitvoerenNl.o7BetalingKop,
      TekstenUitvoerenNl.o7BetalingLater,
    ),
  ];
}

/// "45 minuten", "1 uur", "1 uur en 20 minuten"; afgerond op hele minuten
/// naar beneden.
String duurTekst(Duration duur) {
  final minuten = duur.inMinutes;
  if (minuten < 1) return TekstenUitvoerenNl.duurMinderDanMinuut;
  final uren = minuten ~/ Duration.minutesPerHour;
  final rest = minuten % Duration.minutesPerHour;
  if (uren == 0) return TekstenUitvoerenNl.duurMinuten(rest);
  if (rest == 0) return TekstenUitvoerenNl.duurUren(uren);
  return TekstenUitvoerenNl.duurUrenMinuten(uren, rest);
}
