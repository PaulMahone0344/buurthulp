// Alle schermteksten van de hulpvrager-stroom (M4: O1-O6, O12), in het
// Nederlands en in de je-vorm: de bewoner krijgt "je", net als iedereen.
// Nergens een losse string in een widget. De gedeelde teksten (Terug,
// Verder, foutmeldingen) blijven in teksten_nl.dart.

abstract final class TekstenHulpvragerNl {
  // O1 Home
  static const homeHulpVragen = 'Hulp vragen';
  static const homeHulpVragenSemantiek =
      'Hulp vragen, begin een nieuwe hulpvraag';
  static const homeInstellingen = 'Instellingen';
  static const homeMijnGegevens = 'Mijn gegevens';

  // Hulp vragen op één pagina (3 okt, indeling naar BuurtHeld).
  static const paginaTitel = 'Hulp vragen';
  static const paginaKiesWat = 'Kies eerst wat je nodig hebt.';
  static const paginaKiesWanneer = 'Kies nog een dag en een deel van de dag.';
  static const paginaVulWaarIn = 'Vul je adres helemaal in.';

  // Tabbalk van de bewoner (3 okt, indeling naar BuurtHeld).
  static const tabStart = 'Start';
  static const tabMijnHulpvragen = 'Hulpvragen';
  static const tabMijnHulpvragenSemantiek = 'Mijn hulpvragen';
  static const tabBelOns = 'Bel ons';
  static const tabMeer = 'Meer';
  static const tabbalkLabel = 'Hoofdmenu';

  // Meer
  static const meerTitel = 'Meer';
  static const meerGegevensUitleg = 'Je naam, adres en contactpersoon';
  static const meerInstellingenUitleg = 'Taal, meldingen en account';
  static const meerHulpTitel = 'Hulp en uitleg';
  static const meerHulpUitleg = 'Hoe HeitjeHulp werkt';

  // "Mijn hulpvragen" is sinds M6 O8 (lib/features/hulpvrager/status);
  // de teksten daarvan staan in teksten_uitvoeren_nl.dart.

  // O2 Wat
  static const watTitel = 'Wat heb je nodig?';
  static const watUitleg = 'Kies een soort hulp.';
  static const watKeuzerij = 'Soort hulp';
  static String watKiesSemantiek(String naam) => 'Kies $naam';
  static const watMeer = 'Meer soorten hulp';
  static const watMeerSemantiek = 'Toon meer soorten hulp';
  static const watMinder = 'Minder soorten hulp';
  static const watMinderSemantiek = 'Verberg de extra soorten hulp';
  static const watGeenKlustypes =
      'Er zijn nu geen soorten hulp om uit te kiezen. Bel ons, dan helpen '
      'wij je verder.';
  static const watLaden = 'De soorten hulp worden geladen';

  // O3 Wanneer
  static const wanneerTitel = 'Wanneer wil je hulp?';
  static const wanneerDagKeuzerij = 'Welke dag';
  static const dagVandaag = 'Vandaag';
  static const dagMorgen = 'Morgen';
  static const dagAndere = 'Kies een dag';
  static const dagVandaagSemantiek = 'Kies vandaag';
  static const dagMorgenSemantiek = 'Kies morgen';
  static const dagAndereSemantiek = 'Kies een andere dag';
  static String dagGekozen(String dag) => 'Gekozen dag: $dag';
  static const dagKiezerTitel = 'Welke dag?';
  static String dagKiezerSemantiek(String dag) => 'Kies $dag';
  static const wanneerDagdeel = 'Welk deel van de dag?';
  static const wanneerDagdeelKeuzerij = 'Deel van de dag';
  static const dagdeelOchtend = 'Ochtend';
  static const dagdeelMiddag = 'Middag';
  static const dagdeelAvond = 'Avond';
  static const dagdeelOchtendSemantiek = 'Kies de ochtend, van 9 tot 12 uur';
  static const dagdeelMiddagSemantiek = 'Kies de middag, van 13 tot 17 uur';
  static const dagdeelAvondSemantiek = 'Kies de avond, van 18 tot 20 uur';
  static const dagdeelUitleg =
      'Ochtend is van 9 tot 12 uur, middag van 13 tot 17 uur, avond van '
      '18 tot 20 uur.';
  static const wanneerVoorbij =
      'Dit moment is al voorbij. Kies een ander moment.';

  // O4 Waar
  static const waarTitel = 'Waar en wat nog meer?';
  static const waarUitleg = 'Controleer je adres en vertel kort wat je wilt.';
  static const waarBekendUitleg =
      'Vertel kort wat je wilt. Wij komen naar het adres uit Mijn gegevens.';
  static const veldAdres = 'Straat en huisnummer';
  static const veldPostcode = 'Postcode';
  static const veldPlaats = 'Plaats';
  static const veldToelichting = 'Toelichting';
  static const veldToelichtingHulp =
      'Bijvoorbeeld: twee tassen boodschappen, ik heb een lijstje klaar.';
  static const waarInspreken = 'Inspreken';
  static const waarInsprekenSemantiek = 'Spraakinvoer komt later';
  static const waarGeenAdresTitel = 'We kennen je adres nog niet';
  static const waarGeenAdresUitleg =
      'Vul eerst je adres in bij Mijn gegevens. Daarna ga je verder.';
  static const waarGeenAdresKnop = 'Mijn gegevens invullen';
  static const waarLaden = 'Je gegevens worden geladen';
  static const validatieAdres = 'Vul je straat en huisnummer in.';
  static const validatiePostcode = 'Vul je postcode in.';
  static const validatiePlaats = 'Vul je plaats in.';

  // O5 Bevestigen
  static const bevestigenKaart = 'Jouw hulpvraag';
  static const overzichtWat = 'Wat';
  static const overzichtWanneer = 'Wanneer';
  static const overzichtWaar = 'Waar';
  static const overzichtDuur = 'Duurt';
  static const overzichtKosten = 'Kosten';
  static const overzichtToelichting = 'Toelichting';
  static const bevestigenAkkoord = 'Ja, plaats mijn hulpvraag';
  static const bevestigenAkkoordSemantiek =
      'Ja, plaats mijn hulpvraag en stuur hem naar de helpers';
  static const bevestigenOnvolledig =
      'De hulpvraag is nog niet compleet. Ga terug en kijk wat er mist.';

  // O6 Verstuurd
  static const verstuurdTitel = 'Je hulpvraag is verstuurd';
  static const verstuurdUitleg =
      'Wij zoeken iemand voor je. Je hoort van ons zodra een helper de '
      'hulpvraag heeft aangenomen.';
  static const verstuurdNaarBegin = 'Naar het begin';
  static const verstuurdNaarBeginSemantiek = 'Ga naar het begin';

  // O12 Mijn gegevens
  static const gegevensTitel = 'Mijn gegevens';
  static const gegevensUitleg =
      'Deze gegevens gebruiken we om de helper naar je toe te sturen en om '
      'iemand te bellen als dat nodig is.';
  static const gegevensKaartAdres = 'Je adres';
  static const gegevensKaartContact = 'Contactpersoon';
  static const gegevensContactUitleg =
      'Iemand die we mogen bellen als we jou niet bereiken, bijvoorbeeld '
      'een familielid of een buurvrouw.';
  static const veldContactNaam = 'Naam contactpersoon';
  static const veldContactTelefoon = 'Telefoon contactpersoon';
  static const gegevensOpgeslagen = 'Je gegevens zijn opgeslagen.';
  static const gegevensNietsGewijzigd = 'Er is niets gewijzigd.';
  static const gegevensLaden = 'Je gegevens worden geladen';
  static const gegevensNaamVerplicht = 'Vul je naam in.';

  // Stroom verlaten
  static const verlatenVraag = 'Weet je het zeker?';
  static const verlatenUitleg =
      'Je hulpvraag is nog niet verstuurd. Als je stopt, gaat je invoer '
      'verloren.';
  static const verlatenNee = 'Nee, verder gaan';
  static const verlatenJa = 'Ja, stoppen';

  // Tijd en duur in gewone taal
  static const vandaag = 'vandaag';
  static const morgen = 'morgen';
  static const ongeveer = 'ongeveer';
  static const minuten = 'minuten';
  static const uur = 'uur';
  static const kwartier = 'een kwartier';
  static const halfUur = 'een half uur';
  static const anderhalfUur = 'anderhalf uur';
  static const inDeOchtend = 'in de ochtend';
  static const inDeMiddag = 'in de middag';
  static const inDeAvond = 'in de avond';
  static String vanTotUur(int van, int tot) => 'van $van tot $tot uur';
  static const duurOnbekend = 'wordt afgesproken met de helper';

  static const weekdagen = [
    'maandag',
    'dinsdag',
    'woensdag',
    'donderdag',
    'vrijdag',
    'zaterdag',
    'zondag',
  ];

  static const maanden = [
    'januari',
    'februari',
    'maart',
    'april',
    'mei',
    'juni',
    'juli',
    'augustus',
    'september',
    'oktober',
    'november',
    'december',
  ];
}
