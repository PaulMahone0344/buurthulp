/// De routepaden van O10 en O11 (M8). Niet onder /hulpvrager: de jongere
/// komt vanaf J15 op hetzelfde O11-scherm ("Probleem melden").
abstract final class HhPadenVeiligheid {
  static const _basis = '/veiligheid';

  /// O10.
  static const belOns = '$_basis/bel-ons';

  /// O11. Met ?klus=(id) gaat de klus mee in de melding.
  static const probleem = '$_basis/probleem';
  static const klusParameter = 'klus';

  static String probleemBij(String klusId) =>
      klusId.isEmpty ? probleem : '$probleem?$klusParameter=$klusId';
}
