import '../klussen/paden_klussen.dart';

/// De routepaden van B9. De beloning hangt onder de klus (zoals J15/J17);
/// verdiensten en verklaring onder het Profiel. Zo geldt de screening-guard
/// (HhPadenKlussen.isKlussenPad) ook hier.
abstract final class HhPadenXp {
  /// HBeloning na "Klaar": /jongere/klus/[id]/beloning (beloning als extra).
  static const beloningPatroon = '${HhPadenKlussen.klusPatroon}/beloning';
  static String beloning(String klusId) =>
      '${HhPadenKlussen.klusDetail(klusId)}/beloning';

  static const verdiensten = '${HhPadenKlussen.profiel}/verdiensten';
  static const verklaring = '${HhPadenKlussen.profiel}/verklaring';
}
