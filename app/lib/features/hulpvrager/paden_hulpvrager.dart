import '../../app/paden.dart';

/// De routepaden van de hulpvrager-stroom (M4). O1 is HhPaden.hulpvrager
/// (de rolroute uit M2); alles hieronder hangt daaronder als eigen
/// top-level route, zodat lib/app/paden.dart ongemoeid blijft.
abstract final class HhPadenHulpvrager {
  static const _basis = HhPaden.hulpvrager;
  static const _hulpVragen = '$_basis/hulp-vragen';

  /// O2 stap 1 van 4.
  static const hulpVragenWat = '$_hulpVragen/wat';

  /// O3 stap 2 van 4.
  static const hulpVragenWanneer = '$_hulpVragen/wanneer';

  /// O4 stap 3 van 4.
  static const hulpVragenWaar = '$_hulpVragen/waar';

  /// O5 stap 4 van 4.
  static const hulpVragenBevestigen = '$_hulpVragen/bevestigen';

  /// O6.
  static const hulpVragenVerstuurd = '$_hulpVragen/verstuurd';

  /// O12.
  static const gegevens = '$_basis/gegevens';

  /// Tab "Bel ons" (3 okt): O10 met de tabbalk eronder.
  static const belOnsTab = '$_basis/bel-ons';

  /// Tab "Meer" (3 okt).
  static const meer = '$_basis/meer';
}
