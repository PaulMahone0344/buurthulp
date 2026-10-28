// Alle schermteksten van de hulpvrager-stroom (M4: O1-O6, O12), in het
// Nederlands en in de je-vorm: de bewoner krijgt "je", net als iedereen.
// Nergens een losse string in een widget. De gedeelde teksten (Terug,
// Verder, foutmeldingen) blijven in teksten_nl.dart.

abstract final class TekstenHulpvragerNl {
  // O1 Home
  static const homeHulpVragen = 'Klus plaatsen';
  static const homeHulpVragenSemantiek =
      'Klus plaatsen, vraag een strijder om hulp';
  static const homeInstellingen = 'Instellingen';
  static const homeMijnGegevens = 'Mijn gegevens';

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
  // Feedbackronde 1: juridische stukken los van Hulp en uitleg.
  static const meerVoorwaardenTitel = 'Voorwaarden & privacy';
  static const meerVoorwaardenUitleg =
      'Algemene voorwaarden, privacy en veiligheidsregels';

  // "Mijn hulpvragen" is sinds M6 O8 (lib/features/hulpvrager/status);
  // de teksten daarvan staan in teksten_uitvoeren_nl.dart.

  // Klus plaatsen: categorieën (B4; de rest staat in teksten_klus_nl.dart)
  static const watKeuzerij = 'Soort klus';
  static String watKiesSemantiek(String naam) => 'Kies $naam';
  static const watGeenKlustypes =
      'Er zijn nu geen soorten klussen om uit te kiezen. Bel ons, dan helpen '
      'wij je verder.';
  static const watLaden = 'De soorten klussen worden geladen';

  // Klus plaatsen: de dag
  static const wanneerDagKeuzerij = 'Welke dag';
  static const dagVandaag = 'Vandaag';
  static const dagAndere = 'Kies een dag';
  static const dagVandaagSemantiek = 'Kies vandaag';
  static const dagAndereSemantiek = 'Kies een andere dag';
  static String dagGekozen(String dag) => 'Gekozen dag: $dag';
  static const dagKiezerTitel = 'Welke dag?';
  static String dagKiezerSemantiek(String dag) => 'Kies $dag';

  // Klus plaatsen: adres (alleen namens een oudere zonder bekend adres)
  static const veldAdres = 'Straat en huisnummer';
  static const veldPostcode = 'Postcode';
  static const veldPlaats = 'Plaats';
  static const waarGeenAdresTitel = 'We kennen je adres nog niet';
  static const waarGeenAdresUitleg =
      'Vul eerst je adres in bij Mijn gegevens. Daarna ga je verder.';
  static const waarGeenAdresKnop = 'Mijn gegevens invullen';
  static const waarLaden = 'Je gegevens worden geladen';
  static const validatieAdres = 'Vul je straat en huisnummer in.';
  static const validatiePostcode = 'Vul je postcode in.';
  static const validatiePlaats = 'Vul je plaats in.';
  static const bevestigenOnvolledig =
      'Je klus is nog niet compleet. Kijk wat er nog mist.';

  // O6 Verstuurd
  static const verstuurdTitel = 'Je klus is geplaatst';
  static const verstuurdUitleg =
      'De meldkamer kijkt je klus eerst na. Daarna zien strijders in je buurt '
      'hem. Je hoort van ons zodra een strijder hem aanneemt.';
  static const verstuurdNaarBegin = 'Naar het begin';
  static const verstuurdNaarBeginSemantiek = 'Ga naar het begin';

  // O12 Mijn gegevens
  static const gegevensTitel = 'Mijn gegevens';
  static const gegevensUitleg =
      'Deze gegevens gebruiken we om de strijder naar je toe te sturen en om '
      'iemand te bellen als dat nodig is.';
  static const gegevensKaartAdres = 'Je adres';
  static const gegevensKaartContact = 'Contactpersoon';
  static const gegevensContactUitleg =
      'Iemand die we mogen bellen als we jou niet bereiken, bijvoorbeeld '
      'een familielid of een buurvrouw.';
  // Feedbackronde 1 punt F: de woning.
  static const gegevensKaartWoning = 'Je woning';
  static const woningUitleg =
      'Zo weet de strijder wat hem wacht. Je hoeft niet alles in te vullen.';
  static const woningTypeVraag = 'Wat voor woning heb je?';
  static const woningHuis = 'Huis';
  static const woningAppartement = 'Appartement';
  static const woningAnders = 'Anders';
  static const veldVerdieping = 'Op welke verdieping woon je?';
  static const woningLiftVraag = 'Is er een lift?';
  static const woningTrapVraag = 'Moet je een trap op om bij je deur te komen?';
  static const ja = 'Ja';
  static const nee = 'Nee';
  static const woningHuisSemantiek = 'Kies huis';
  static const woningAppartementSemantiek = 'Kies appartement';
  static const woningAndersSemantiek = 'Kies anders';
  static String jaNeeSemantiek(String antwoord, String vraag) =>
      'Kies ${antwoord.toLowerCase()} bij: $vraag';
  static const veldBereikbaarheid = 'Hoe kom je bij je deur?';
  static const bereikbaarheidHint =
      'Bijvoorbeeld: bel aan bij de achterdeur, parkeren om de hoek.';
  static const veldContactNaam = 'Naam contactpersoon';
  static const veldContactTelefoon = 'Telefoon contactpersoon';
  static const gegevensOpgeslagen = 'Je gegevens zijn opgeslagen.';
  static const gegevensNietsGewijzigd = 'Er is niets gewijzigd.';
  static const gegevensLaden = 'Je gegevens worden geladen';
  static const gegevensNaamVerplicht = 'Vul je naam in.';

  // Stroom verlaten
  static const verlatenVraag = 'Weet je het zeker?';
  static const verlatenUitleg =
      'Je klus is nog niet geplaatst. Als je stopt, gaat je invoer '
      'verloren.';
  static const verlatenNee = 'Nee, verder gaan';
  static const verlatenJa = 'Ja, stoppen';

  // Dagen in gewone taal
  static const vandaag = 'vandaag';
  static const morgen = 'morgen';

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

  /// Mijn gegevens: na "Opslaan" met een fout (naam leeg of adres niet
  /// gecontroleerd). Staat boven de knop; het scherm scrolt naar het veld.
  static const gegevensNakijken =
      'Nog niet opgeslagen. Kijk het veld met de rode tekst na.';
}
