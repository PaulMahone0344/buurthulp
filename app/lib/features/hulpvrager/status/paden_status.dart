import '../../../app/paden.dart';

/// De routepaden van M6 aan de kant van de oudere: O8 (de lijst) en O7 (één
/// hulpvraag). Eigen bestand naast paden_hulpvrager.dart (M4), zodat dat
/// bestand ongemoeid blijft.
abstract final class HhPadenStatus {
  static const _basis = HhPaden.hulpvrager;

  /// O8.
  static const hulpvragen = '$_basis/hulpvragen';

  /// O7, met het klus-id erachter.
  static const hulpvraagPatroon = '$hulpvragen/:id';
  static String hulpvraag(String klusId) => '$hulpvragen/$klusId';
}
