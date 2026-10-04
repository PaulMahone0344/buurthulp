import '../../app/paden.dart';

/// Routepaden van het aanmelden van de helper (M3, ingekort in B2). Eigen
/// klasse naast [HhPaden]; de landing /jongere blijft in [HhPaden.jongere].
abstract final class HhPadenJongere {
  static const screening = '${HhPaden.jongere}/screening';

  static const identiteit = '$screening/identiteit'; // J2 ID-foto
  static const vog = '$screening/vog'; // J4 VOG (18+)
  static const overMij = '$screening/over-mij'; // Over mij (mag leeg)
  static const overzicht = '$screening/overzicht'; // J9 Je aanmelding
  static const binnen = '$screening/binnen'; // H6b Aanmelding binnen

  /// ADRES (4 okt): "Mijn adres" (gele balk "Vul je adres aan"). Onder
  /// /jongere/screening, zodat ook een wachtende helper erbij kan.
  static const adres = '$screening/adres';

  /// Elk pad onder /jongere/screening.
  static bool isScreeningPad(String locatie) => locatie.startsWith(screening);
}

/// B3: de stap "Ouder" (helper onder 18): mail met code naar de ouder,
/// opnieuw sturen, adres wijzigen. Onder /jongere/screening, zodat de guard
/// andere rollen er net zo weghoudt.
abstract final class HhPadenOuder {
  static const ouder = '${HhPadenJongere.screening}/ouder';
}
