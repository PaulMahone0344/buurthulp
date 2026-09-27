import '../../app/paden.dart';

/// De routepaden van M9 aan de kant van het familielid. F1 is de rolroute
/// /familie (HhPaden.familie); F2 is de M4-stroom onder /hulpvrager
/// (namens de oudere, zie HulpvraagNamens).
abstract final class HhPadenFamilie {
  static const _basis = HhPaden.familie;

  /// F1 zonder "meteen door naar F3" (vanaf F3 terug naar het overzicht).
  static const lijstParameter = 'lijst';
  static const lijst = '$_basis?$lijstParameter=1';

  /// Aanvragen met het e-mailadres van de oudere.
  static const koppelen = '$_basis/koppelen';

  /// F3.
  static const ouderePatroon = '$_basis/oudere/:id';
  static String oudere(String oudereId) => '$_basis/oudere/$oudereId';

  /// F3-detail: één hulpvraag, zoals O7 maar alleen-lezen.
  static const hulpvraagPatroon = '$ouderePatroon/hulpvraag/:klusId';
  static String hulpvraag(String oudereId, String klusId) =>
      '${oudere(oudereId)}/hulpvraag/$klusId';
}
