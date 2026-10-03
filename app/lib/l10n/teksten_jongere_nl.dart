// Schermteksten van de screeningstroom van de helper (M3, J1-J9). Eigen
// bestand naast teksten_nl.dart; nergens een losse string in een widget.

abstract final class TekstenJongereNl {
  // Statussen (hh_profielen.verificatiestatus en vog_status)
  static const statusNieuw = 'Nog niet ingediend';
  static const statusInBehandeling = 'In behandeling';
  static const statusGoedgekeurd = 'Goedgekeurd';
  static const statusAfgewezen = 'Afgewezen';
  static String statusLabel(String naam) => 'Status: $naam';

  // Gedeeld in de stappen
  static const stapAf = 'Af';
  static const stapOpen = 'Nog doen';
  static const opslaanEnVerder = 'Opslaan en verder';
  static const opgeslagen = 'Opgeslagen.';
  static const ladenMislukt = 'Je gegevens konden niet worden geladen.';
  static const fotoMaken = 'Foto maken';
  static const fotoKiezen = 'Kies uit galerij';
  static const fotoOpnieuw = 'Opnieuw';
  static const fotoStaatKlaar = 'Je foto is opgeslagen.';
  static const fotoNogGeen = 'Nog geen foto.';
  static const fotoBezig = 'Foto wordt verstuurd';
  static const fotoCameraLuktNiet =
      'De camera is op dit toestel niet beschikbaar.';
  static const fotoKiezenLuktNiet = 'Het kiezen van een foto is mislukt.';
  static String stapTitel(int stap, String titel) => 'Stap $stap: $titel';

  // Landing /jongere
  static const landingScreening = 'Screening';
  static const landingScreeningKnop = 'Bekijk je aanmelding';

  // J1 Profiel
  static const j1Titel = 'Je profiel';
  static const j1Uitleg =
      'Bewoners zien je foto en een korte tekst over jou voordat ze je '
      'binnenlaten. Maak het persoonlijk.';
  static const j1FotoKop = 'Je foto';
  static const j1FotoHulp = 'Een duidelijke foto van je gezicht.';
  static const j1Geboortedatum = 'Geboortedatum';
  static const j1GeboortedatumHulp = 'Dag-maand-jaar, bijvoorbeeld 14-05-2008.';
  static const j1OverMij = 'Over mij';
  static const j1OverMijHulp =
      'Wie ben je en waar help je graag mee? Maximaal 500 tekens.';
  static const validatieGeboortedatumOngeldig =
      'Dit is geen geldige datum. Gebruik dag-maand-jaar.';
  static const validatieGeboortedatumToekomst =
      'Deze datum ligt in de toekomst.';
  static const validatieOverMijVerplicht = 'Schrijf iets over jezelf.';
  static const validatieOverMijTeLang = 'Maximaal 500 tekens.';

  // J2 Identiteitscontrole
  static const j2Titel = 'Identiteitscontrole';
  static const j2Uitleg =
      'Maak een foto van je identiteitskaart, paspoort of rijbewijs. '
      'De meldkamer controleert je naam en geboortedatum.';
  static const j2WelZichtbaar =
      'Wel zichtbaar: je naam, je geboortedatum en je pasfoto.';
  static const j2NietZichtbaar =
      'Niet zichtbaar: je BSN. Dek het af met je vinger of een stukje '
      'papier voordat je de foto maakt.';
  static const j2Vertrouwelijk =
      'Alleen jij en de meldkamer kunnen deze foto zien.';

  // J3 Selfie
  static const j3Titel = 'Selfie';
  static const j3Uitleg =
      'Maak nu een selfie met de camera. Zo weet de meldkamer dat jij het '
      'bent op het document. Kijk recht in de camera, zonder zonnebril of pet.';
  static const j3Knop = 'Selfie maken';

  // J4 VOG
  static const j4Titel = 'VOG';
  static const j4Uitleg =
      'Een Verklaring Omtrent het Gedrag (VOG) laat zien dat je te '
      'vertrouwen bent bij mensen thuis. Je vraagt hem aan bij Justis; de '
      'meldkamer zet daarna de status op goedgekeurd.';
  static const j4Aanvragen = 'VOG aanvragen';
  static const j4AanvragenLuktNiet =
      'De website kon niet worden geopend. Ga zelf naar justis.nl.';
  static const j4HebAangevraagd = 'Ik heb aangevraagd';
  static String j4AangevraagdOp(String datum) => 'Aangevraagd op $datum.';
  static const j4StatusKop = 'Status van je VOG';

  // J5 IBAN
  static const j5Titel = 'Bankrekening';
  static const j5Uitleg =
      'Op deze rekening ontvang je je vergoeding. De meldkamer controleert '
      'of de rekening op jouw naam staat.';
  static const j5Iban = 'IBAN';
  static const j5IbanHulp = 'Bijvoorbeeld NL91 ABNA 0417 1643 00.';
  static const j5Geverifieerd = 'Je rekening is gecontroleerd.';
  static const j5NogNietGeverifieerd = 'Je rekening is nog niet gecontroleerd.';
  static const validatieIbanVerplicht = 'Vul je IBAN in.';
  static const validatieIbanOngeldig =
      'Dit is geen geldige Nederlandse IBAN. Controleer de cijfers.';

  // J6 Werkgebied
  static const j6Titel = 'Werkgebied';
  static const j6Uitleg = 'In welke wijk woon je, en hoe ver wil je reizen?';
  static const j6WijkKop = 'Je wijk';
  static const j6GeenWijken = 'Er zijn nog geen wijken beschikbaar.';
  static const j6StraalKop = 'Hoe ver wil je reizen?';
  static String j6StraalLabel(int km) => '$km km';
  static const validatieWijkVerplicht = 'Kies je wijk.';

  // J7 Beschikbaarheid
  static const j7Titel = 'Beschikbaarheid';
  static const j7Uitleg =
      'Wanneer kun je meestal? Je kunt dit later altijd aanpassen.';
  static const dagMa = 'Maandag';
  static const dagDi = 'Dinsdag';
  static const dagWo = 'Woensdag';
  static const dagDo = 'Donderdag';
  static const dagVr = 'Vrijdag';
  static const dagZa = 'Zaterdag';
  static const dagZo = 'Zondag';
  static const dagdeelOchtend = 'Ochtend';
  static const dagdeelMiddag = 'Middag';
  static const dagdeelAvond = 'Avond';
  static const validatieBeschikbaarheidLeeg = 'Kies minstens een dagdeel.';

  // J8 Klussoorten
  static const j8Titel = 'Klussoorten';
  static const j8Uitleg = 'Waar wil je mee helpen? Kies er zoveel als je wilt.';
  static const j8GeenKlustypes = 'Er zijn nog geen klussoorten beschikbaar.';
  static const validatieKlustypesLeeg = 'Kies minstens een klussoort.';

  // J9 Overzicht
  static const j9Titel = 'Je aanmelding';
  static const j9StappenKop = 'Je stappen';
  static const j9StatusKop = 'Status';
  static const j9Indienen = 'Ter controle aanbieden';
  static const j9IndienenHulp =
      'Als alle stappen af zijn, kun je je aanmelding ter controle '
      'aanbieden.';
  static const j9Ingediend = 'Je aanmelding is ingediend.';
  static const j9WachtTekst =
      'De meldkamer bekijkt je aanmelding. Dat duurt meestal een paar '
      'dagen. Je krijgt bericht zodra je kunt beginnen.';
  static const j9AfgewezenTekst =
      'Je aanmelding is helaas niet goedgekeurd. Bel ons als je wilt weten '
      'waarom, of als je denkt dat er iets misgaat.';
  static const j9BelOns = 'Bel ons';
  static const j9GoedgekeurdTekst =
      'Je bent goedgekeurd. Je kunt nu klussen in je buurt bekijken.';
  static const j9NaarKlussen = 'Naar klussen';
  static const j9Vernieuwen = 'Status vernieuwen';
  static const j9VogLabel = 'VOG';
  static const j9VerificatieLabel = 'Aanmelding';
}
