import '../../app/paden.dart';

/// Routepaden van de jongere (M3: screening J1-J9). Eigen klasse naast
/// [HhPaden]; de landing /jongere blijft in [HhPaden.jongere].
abstract final class HhPadenJongere {
  static const screening = '${HhPaden.jongere}/screening';

  static const profiel = '$screening/profiel'; // J1
  static const identiteit = '$screening/identiteit'; // J2
  static const selfie = '$screening/selfie'; // J3
  static const vog = '$screening/vog'; // J4
  static const iban = '$screening/iban'; // J5
  static const werkgebied = '$screening/werkgebied'; // J6
  static const beschikbaarheid = '$screening/beschikbaarheid'; // J7
  static const klussoorten = '$screening/klussoorten'; // J8
  static const overzicht = '$screening/overzicht'; // J9

  /// Elk pad onder /jongere/screening.
  static bool isScreeningPad(String locatie) => locatie.startsWith(screening);
}
