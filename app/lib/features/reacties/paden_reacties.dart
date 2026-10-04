import '../../app/paden.dart';
import '../jongere/klussen/paden_klussen.dart';

/// De routepaden van B5 (reageren en kiezen). "Reactie verstuurd" hangt
/// onder het klus-pad van de helper (zo geldt de screening-guard van M5 ook
/// hier); KiesHelper onder /hulpvrager.
abstract final class HhPadenReacties {
  /// HReactieVerstuurd: /jongere/klus/[id]/verstuurd(?ouder=1).
  static const verstuurdPatroon = '${HhPadenKlussen.klus}/:id/verstuurd';
  static String verstuurd(String klusId, {bool ouder = false}) =>
      '${HhPadenKlussen.klus}/$klusId/verstuurd${ouder ? '?ouder=1' : ''}';

  /// KiesHelper: /hulpvrager/kies/[id].
  static const kiesPatroon = '${HhPaden.hulpvrager}/kies/:id';
  static String kies(String klusId) => '${HhPaden.hulpvrager}/kies/$klusId';
}
