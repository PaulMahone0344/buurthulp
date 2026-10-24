// Schermteksten van de kennismaking: de pagina's die iemand één keer ziet,
// direct na het installeren, vóór het welkomscherm (24 okt, wens Ibrahim
// na feedbackronde 1). Je-vorm, korte zinnen.

/// Eén pagina van de kennismaking.
class HhKennismaakPagina {
  const HhKennismaakPagina(this.titel, this.tekst);

  final String titel;
  final String tekst;
}

abstract final class TekstenKennismakenNl {
  static const paginas = [
    HhKennismaakPagina(
      'Hulp in je buurt',
      'HeitjeHulp brengt buren met een karweitje samen met Strijders uit de '
          'buurt.',
    ),
    HhKennismaakPagina(
      'Zo werkt het',
      'Plaats een karweitje. Strijders reageren en jij kiest wie het doet. '
          'Klaar? Dan betaal je in de app.',
    ),
    HhKennismaakPagina(
      'Veilig',
      'De meldkamer kijkt elke klus na. Strijders worden gecontroleerd en '
          'ouders geven toestemming.',
    ),
    HhKennismaakPagina(
      'Word Strijder',
      'Help mensen in je buurt en verdien zakgeld of misschien wel meer!',
    ),
  ];

  static const overslaan = 'Overslaan';
  static const opnieuwKnop = 'Bekijk de uitleg';
  static const overslaanSemantiek = 'Uitleg overslaan, naar het welkomscherm';
  static const volgende = 'Volgende';
  static const aanDeSlag = 'Aan de slag';
  static String paginaVan(int nummer, int totaal) =>
      'Pagina $nummer van $totaal';
}
