import '../klussen/paden_klussen.dart';

/// Het routepad van J17 (M7). Hangt onder het klusdetail van M5, net als J15
/// (M6), zodat de screening-guard hem al dekt (HhPadenKlussen.isKlussenPad
/// kijkt naar alles onder /jongere/klus/). J19 is de tab Profiel
/// (HhPadenKlussen.profiel) en heeft geen eigen pad.
abstract final class HhPadenReputatie {
  /// J17, met het klus-id erin: /jongere/klus/{id}/beoordelen.
  static const beoordelenPatroon = '${HhPadenKlussen.klusPatroon}/beoordelen';

  static String beoordelen(String klusId) =>
      '${HhPadenKlussen.klusDetail(klusId)}/beoordelen';
}
