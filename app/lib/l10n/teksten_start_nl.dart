// Schermteksten van B10: de Start van de helper (mockup StartHelper) en van
// de bewoner (mockup Main). Nergens een losse string in een widget.

abstract final class TekstenStartNl {
  // ---- Helper -------------------------------------------------------
  static String hoi(String voornaam) =>
      voornaam.isEmpty ? 'Hoi!' : 'Hoi $voornaam!';
  static const niveauKop = 'Jouw niveau';
  static String volgende(String niveau) => 'Volgende: $niveau';
  static const hoogste = 'Hoogste niveau';
  static const badgesNaarProfiel = 'Bekijk al je badges';
  static const volgendeKlusKop = 'Je volgende klus';
  static const inDeBuurtKop = 'Klussen bij jou in de buurt';
  static const alle = 'Alle';
  static const alleSemantiek = 'Alle klussen in de buurt';
  static const geenInDeBuurt =
      'Nu geen klussen in je buurt. Zet "Ik kan nu helpen" aan, dan hoor je '
      'het als er een bijkomt.';
  static const ladenMislukt = 'De klussen konden niet worden geladen.';
  static const instellingen = 'Instellingen';

  // ---- Bewoner ------------------------------------------------------
  static const aankomendTegel = 'Aankomend';
  static String klussenWoord(int n) => n == 1 ? 'klus' : 'klussen';
  static String aankomendSemantiek(int n) =>
      n == 1 ? '1 aankomende klus' : '$n aankomende klussen';
  static const reactiesTegel = 'Nieuwe reacties';
  static String reactiesSemantiek(int n) =>
      n == 1 ? '1 nieuwe reactie' : '$n nieuwe reacties';
  static const aankomendKop = 'Aankomende klussen';
  static const periodeLabel = 'Periode';
  static const dag = 'Dag';
  static const week = 'Week';
  static const maand = 'Maand';
  static const weekstripLabel = 'Deze week';
  static String dagSemantiek(String dag, int aantal) =>
      aantal == 0 ? dag : '$dag, ${aantal == 1 ? '1 klus' : '$aantal klussen'}';
  static const geenAankomend = 'Geen klussen in deze periode.';
  static const statusBevestigd = 'Bevestigd';
  static const statusZoekt = 'Zoekt helper';
  static const statusNagekeken = 'Wordt nagekeken';
  static const statusBezig = 'Bezig';
  static const weekdagenKort = ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'];
}
