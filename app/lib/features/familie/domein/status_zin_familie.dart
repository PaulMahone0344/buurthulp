import '../../../l10n/teksten_familie_nl.dart';
import '../../../l10n/teksten_uitvoeren_nl.dart';
import '../../../theme.dart';
import '../../jongere/klussen/model/hh_klus.dart';

/// De statuszin zoals het familielid hem leest (F3). Zelfde momenten als
/// statusZin van de oudere (O7), maar met de naam van de oudere: het
/// familielid wordt niet zelf geholpen.
String statusZinVoorFamilie(HhKlus klus) {
  final jongere = klus.jongereVoornaam;
  final oudere = klus.oudereNaam.trim().isEmpty
      ? TekstenFamilieNl.f3OudereZonderNaam
      : klus.oudereNaam.trim();
  if (jongere.isEmpty) {
    return switch (klus.status) {
      HhKlusStatus.concept => TekstenUitvoerenNl.o7Concept,
      HhKlusStatus.geannuleerd => TekstenUitvoerenNl.o7Geannuleerd,
      HhKlusStatus.probleem => TekstenFamilieNl.f3Probleem(oudere),
      _ => TekstenFamilieNl.f3GeenJongere(oudere),
    };
  }
  return switch (klus.status) {
    HhKlusStatus.geaccepteerd => TekstenFamilieNl.f3Aangenomen(jongere, oudere),
    HhKlusStatus.onderweg => TekstenFamilieNl.f3Onderweg(jongere, oudere),
    HhKlusStatus.bezig => TekstenFamilieNl.f3Bezig(jongere, oudere),
    HhKlusStatus.afgerond => TekstenUitvoerenNl.o7Afgerond(jongere),
    HhKlusStatus.geannuleerd => TekstenUitvoerenNl.o7Geannuleerd,
    HhKlusStatus.probleem => TekstenFamilieNl.f3Probleem(oudere),
    HhKlusStatus.concept => TekstenUitvoerenNl.o7Concept,
    HhKlusStatus.open => TekstenFamilieNl.f3GeenJongere(oudere),
  };
}
