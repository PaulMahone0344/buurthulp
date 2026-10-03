// B4 — teksten van "Klus plaatsen" (bewoner), de meldkamer-keuring zoals
// de bewoner hem ziet en de klusfoto bij de helper. Je-vorm, gewone taal.
// Eigen bestand zodat B3 en B6 (parallel gebouwd) teksten_nl.dart en
// teksten_hulpvrager_nl.dart niet hoeven te delen.

abstract final class TekstenKlusNl {
  // Pagina
  static const paginaTitel = 'Klus plaatsen';
  static const plaatsen = 'Klus plaatsen';
  static const plaatsenSemantiek = 'Klus plaatsen en naar de meldkamer sturen';

  // Wat ontbreekt er nog (meldbalk bij "Klus plaatsen")
  static const ontbreektWat = 'Kies eerst wat er moet gebeuren.';
  static const ontbreektOmschrijving =
      'Vertel in een paar woorden wat je wilt (minstens 5 tekens).';
  static const ontbreektFoto = 'Voeg een foto van de klus toe.';
  static const ontbreektWanneer = 'Kies nog een dag.';
  static const ontbreektTijdVoorbij =
      'Deze tijd is al voorbij. Kies een later moment.';
  static const ontbreektTot = 'De eindtijd moet na de begintijd liggen.';
  static const ontbreektWaar = 'Vul eerst je adres in bij Mijn gegevens.';
  static const ontbreektNeeLijst =
      'Vink aan dat je klus niet op de lijst hieronder staat.';

  // Wat
  static const watTitel = 'Wat moet er gebeuren?';

  // Vertel wat je wilt
  static const omschrijvingTitel = 'Vertel wat je wilt';
  static const omschrijvingHulp =
      'Bijvoorbeeld: de heg aan de voorkant knippen, het afval mag in de '
      'groene bak. Geen telefoonnummer of e-mail: die deelt de meldkamer.';
  static const omschrijvingMax = 300;
  static String omschrijvingTeller(int aantal) => '$aantal / $omschrijvingMax';
  static String omschrijvingTellerSemantiek(int aantal) =>
      '$aantal van de $omschrijvingMax tekens gebruikt';

  // Foto
  static const fotoTitel = 'Foto van de klus';
  static const fotoVerplicht = 'verplicht';
  static const fotoUitleg =
      'Een foto van wat er moet gebeuren, zonder mensen erop. Alleen de '
      'meldkamer en helpers die de klus mogen doen zien hem.';
  static const fotoMaken = 'Maak een foto';
  static const fotoKiezen = 'Kies een foto';
  static const fotoVerwijderen = 'Foto verwijderen';
  static const fotoGekozen = 'Je foto is gekozen.';
  static const fotoVoorbeeldSemantiek = 'De foto van je klus';
  static const fotoLuktNiet =
      'Het maken of kiezen van een foto lukte niet. Probeer het nog eens.';

  // Wanneer (tijdwiel)
  static const wanneerTitel = 'Wanneer?';
  static const vanaf = 'Vanaf';
  static const tot = 'Tot';
  static String tijdGekozen(String welke, String tijd) => '$welke $tijd';
  static const eindtijd = 'Eindtijd';
  static const eindtijdOptioneel = 'Optioneel';
  static const eindtijdSemantiek = 'Eindtijd instellen';
  static String vanafSemantiek(String tijd) => 'Begintijd, nu $tijd';
  static String totSemantiek(String tijd) => 'Eindtijd, nu $tijd';
  static const alleen18Plus =
      'Let op: door deze tijd kunnen alleen helpers van 18 jaar en ouder '
      'deze klus doen. Voor jongere helpers: tussen 7:00 en 19:00 en '
      'hooguit 2 uur.';
  static String wanneerVanaf(String dag, String tijd) => '$dag vanaf $tijd';
  static String wanneerVanTot(String dag, String van, String tot) =>
      '$dag van $van tot $tot';

  // Herhalen
  static const herhalenTitel = 'Herhalen';
  static const eenmalig = 'Eenmalig';
  static const wekelijks = 'Wekelijks';
  static const tweewekelijks = 'Tweewekelijks';
  static const maandelijks = 'Maandelijks';
  static const plus = 'Plus';
  static String herhalenSlotSemantiek(String keuze) =>
      '$keuze, kan met HeitjeHulp Plus';
  static const herhalenUitleg = 'Herhalen kan met HeitjeHulp Plus.';

  // Waar
  static const waarTitel = 'Waar?';
  static String waarAdres(String adres) => 'Bij jou thuis: $adres';
  static const waarAnders =
      'Klopt het adres niet? Pas het aan bij Mijn gegevens.';
  static const waarUitleg = 'Vul het adres in waar de klus is.';

  // Nee-lijst (besluit punt 5)
  static const neeLijstTitel = 'Dit kan niet via HeitjeHulp';
  static const neeLijst = [
    'Alcohol of tabak kopen',
    'Werken op een ladder of met machines',
    'Zorg, zoals wassen of medicijnen geven',
    'Echt schoonmaakwerk voor een bedrijf',
    'Oppassen op kinderen',
  ];
  static const neeLijstAkkoord = 'Mijn klus valt hier niet onder';

  // Prijs (prijzen komen in B7)
  static const prijsJijBetaalt = 'Jij betaalt';
  static const prijsInclusief = 'inclusief servicekosten';
  static const prijsVoorbeeld = 'voorbeeld';
  static String prijsSemantiek(String bedrag) =>
      'Jij betaalt $bedrag, inclusief servicekosten. Dit is een voorbeeld.';

  // Status bij de bewoner (O7/O8)
  static const wordtNagekeken = 'Je klus wordt nagekeken';
  static const wordtNagekekenUitleg =
      'De meldkamer kijkt je klus na. Daarna zien helpers in je buurt hem.';
  static const afgekeurd = 'Je klus is afgekeurd';
  static String afgekeurdReden(String reden) =>
      'De meldkamer keurde je klus af: $reden';

  // Helper: de foto bij de klus
  static const helperFotoKop = 'Foto van de klus';
  static const helperFotoSemantiek = 'Foto die de bewoner bij de klus zette';
  static const helperFotoLuktNiet = 'De foto kon niet worden geladen.';
}
