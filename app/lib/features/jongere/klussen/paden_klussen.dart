import '../../../app/paden.dart';

/// Routepaden van klussen vinden en accepteren (M5, J11-J14) en de tabbalk
/// van de jongere. J11/J12 zitten op de landing /jongere (HhPaden.jongere).
abstract final class HhPadenKlussen {
  /// J14.
  static const mijnKlussen = '${HhPaden.jongere}/mijn-klussen';

  /// Tab Profiel: J9 (M3-overzicht) als tijdelijke inhoud, met tabbalk.
  static const profiel = '${HhPaden.jongere}/profiel';

  /// Tab Instellingen: G7 met tabbalk.
  static const instellingen = '${HhPaden.jongere}/instellingen';

  /// J13, met het klus-id erachter.
  static const klus = '${HhPaden.jongere}/klus';
  static const klusPatroon = '$klus/:id';
  static String klusDetail(String id) => '$klus/$id';

  /// Elk M5-pad: hoort bij een goedgekeurde jongere (guard).
  static bool isKlussenPad(String locatie) =>
      locatie == mijnKlussen ||
      locatie == profiel ||
      // B9: verdiensten en verklaring hangen onder het Profiel.
      locatie.startsWith('$profiel/') ||
      locatie == instellingen ||
      locatie.startsWith('$klus/');
}
