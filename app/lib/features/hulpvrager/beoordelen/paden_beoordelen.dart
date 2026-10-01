import '../status/paden_status.dart';

/// Het routepad van O9 (M7), onder O7: "terug" komt vanzelf weer bij de
/// hulpvraag uit.
abstract final class HhPadenBeoordelen {
  /// O9, met het klus-id erin: /hulpvrager/hulpvragen/{id}/beoordelen.
  static const beoordelenPatroon =
      '${HhPadenStatus.hulpvraagPatroon}/beoordelen';

  static String beoordelen(String klusId) =>
      '${HhPadenStatus.hulpvraag(klusId)}/beoordelen';
}
