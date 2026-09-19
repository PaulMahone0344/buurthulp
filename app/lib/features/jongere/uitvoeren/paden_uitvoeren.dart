import '../klussen/paden_klussen.dart';

/// Het routepad van J15 (M6). Hangt onder het klusdetail van M5, zodat
/// "terug" vanzelf weer bij J13 uitkomt en de screening-guard hem al dekt
/// (HhPadenKlussen.isKlussenPad kijkt naar alles onder /jongere/klus/).
abstract final class HhPadenUitvoeren {
  /// J15, met het klus-id erin: /jongere/klus/{id}/uitvoeren.
  static const uitvoerenPatroon = '${HhPadenKlussen.klusPatroon}/uitvoeren';

  static String uitvoeren(String klusId) =>
      '${HhPadenKlussen.klusDetail(klusId)}/uitvoeren';
}
