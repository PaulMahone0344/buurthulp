// Alle schermteksten van de app, in het Nederlands. Nergens een losse
// string in een widget. Vertalingen (ar/tr/en) komen later; de taalkeuze
// in G7 wordt nu alleen opgeslagen.

/// Een vraag met antwoord voor het hulpscherm (G8).
class HhVraag {
  const HhVraag(this.vraag, this.antwoord);

  final String vraag;
  final String antwoord;
}

abstract final class TekstenNl {
  static const appNaam = 'HeitjeHulp';

  // Algemeen
  static const terug = 'Terug';
  static const verder = 'Verder';
  static const opnieuwProberen = 'Opnieuw proberen';
  static const annuleren = 'Annuleren';
  static const opslaan = 'Opslaan';
  static const evenGeduld = 'Even geduld';
  static const hulpNodig = 'Hulp nodig?';

  // Rollen
  static const rolHulpvrager = 'Bewoner';
  static const rolJongere = 'Helper';
  static const rolFamilie = 'Familie';
  static const rolCoordinator = 'Coordinator';

  // G1 Splash
  static const splashOndertitel = 'Heitje voor een karweitje, in jouw buurt.';
  static const splashBezig = 'De app wordt gestart';

  // G2 Welkom en rolkeuze
  static const welkomTitel = 'Welkom bij HeitjeHulp';
  static const welkomUitleg =
      'Heitje voor een karweitje, in jouw buurt. Bewoners plaatsen een '
      'klus, helpers uit de buurt helpen. Kies wat bij jou past.';
  static const keuzeZoekHulp = 'Ik zoek hulp';
  static const keuzeWilHelpen = 'Ik wil helpen';
  static const keuzeHelpFamilielid = 'Ik help een familielid';
  static const alEenAccount = 'Ik heb al een account';

  // G3 Inloggen
  static const inloggenTitel = 'Inloggen';
  static const inloggenKnop = 'Inloggen';
  static const wachtwoordVergetenLink = 'Wachtwoord vergeten?';
  static const geenAccountLink = 'Nog geen account? Maak er een';

  // G4 Registreren
  static const registrerenTitel = 'Account maken';
  static const registrerenKnop = 'Account maken';
  static const registrerenOnbekendeRol =
      'Kies eerst wat bij je past op het welkomscherm.';

  // Velden
  static const veldNaam = 'Je naam';
  static const veldEmail = 'E-mailadres';
  static const veldEmailHulp = 'Hiermee log je in.';
  static const veldTelefoon = 'Telefoonnummer';
  static const veldWachtwoord = 'Wachtwoord';
  static const veldWachtwoordHulp = 'Minstens 8 tekens.';

  // Validatie
  static const validatieNaamVerplicht = 'Vul je naam in.';
  static const validatieEmailVerplicht = 'Vul je e-mailadres in.';
  static const validatieEmailOngeldig =
      'Dit lijkt geen e-mailadres. Kijk of er een @ in staat.';
  static const validatieWachtwoordTeKort =
      'Het wachtwoord moet minstens 8 tekens hebben.';

  // G5 E-mail bevestigen
  static const bevestigEmailTitel = 'Bevestig je e-mailadres';
  static String bevestigEmailUitleg(String email) =>
      'We hebben een e-mail gestuurd naar $email. '
      'Klik op de link in die e-mail om je adres te bevestigen. '
      'Je kunt de app intussen al gebruiken.';
  static const bevestigEmailOpnieuw = 'E-mail opnieuw sturen';
  static const bevestigEmailVerstuurd = 'De e-mail is opnieuw verstuurd.';
  static const bevestigEmailBanner =
      'Je e-mailadres is nog niet bevestigd. Kijk in je e-mail.';
  static const bevestigEmailBannerKnop = 'Meer over bevestigen';

  // G6 Wachtwoord vergeten
  static const wachtwoordVergetenTitel = 'Wachtwoord vergeten';
  static const wachtwoordVergetenUitleg =
      'Vul je e-mailadres in. Je krijgt een e-mail met een link om een '
      'nieuw wachtwoord te kiezen.';
  static const wachtwoordVergetenKnop = 'Stuur e-mail';
  static const wachtwoordVergetenVerstuurd =
      'Als dit e-mailadres bij ons bekend is, ontvang je zo een e-mail.';

  // G7 Instellingen
  static const instellingenTitel = 'Instellingen';
  static const instellingenTaal = 'Taal';
  static const instellingenTaalHulp =
      'De app is nu alleen in het Nederlands. Je keuze wordt bewaard.';
  static const taalNederlands = 'Nederlands';
  static const taalArabisch = 'العربية';
  static const taalTurks = 'Türkçe';
  static const taalEngels = 'English';
  static const instellingenMeldingen = 'Meldingen';
  static const instellingenMeldingenSchakelaar = 'Meldingen ontvangen';
  static const instellingenMeldingenHulp =
      'Bijvoorbeeld als er nieuws is over een klus.';
  static const instellingenLetters = 'Lettergrootte';
  static const instellingenLettersSchakelaar = 'Grotere letters';
  static const instellingenLettersHulp =
      'Maakt tekst en knoppen in de hele app groter.';
  static const instellingenAccount = 'Account';
  static const instellingenOpgeslagen = 'Opgeslagen.';
  static const uitloggen = 'Uitloggen';
  static const accountWissen = 'Account wissen';
  static const accountWissenVraag = 'Je account wissen?';
  static const accountWissenUitleg =
      'Je account en je gegevens worden verwijderd. Dit kan niet '
      'ongedaan worden gemaakt.';
  static const accountWissenBevestig = 'Ja, wis mijn account';

  // G8 Hulp
  static const hulpTitel = 'Hulp';
  static const hulpBelMeldkamer = 'Bel de meldkamer';
  static String hulpBellenLuktNiet(String nummer) =>
      'Bellen lukt niet vanaf dit toestel. Het nummer is $nummer.';
  static const hulpVeelgesteld = 'Veelgestelde vragen';

  static const hulpVragenHulpvrager = [
    HhVraag(
      'Hoe vraag ik hulp?',
      'Kies in de app wat je nodig hebt, bijvoorbeeld boodschappen of de '
          'tuin. Een helper uit je buurt neemt de klus aan.',
    ),
    HhVraag(
      'Wie komt er bij mij thuis?',
      'Alleen helpers die door de meldkamer zijn gecontroleerd. Je ziet '
          'vooraf hun naam en foto.',
    ),
    HhVraag(
      'Wat kost het?',
      'Je ziet het bedrag voordat je een klus plaatst. Je betaalt pas als '
          'de klus klaar is.',
    ),
    HhVraag(
      'Kan iemand anders het voor mij regelen?',
      'Ja. Een familielid of mantelzorger kan met een eigen account '
          'klussen voor je plaatsen.',
    ),
    HhVraag(
      'Wat als er iets misgaat?',
      'Bel de meldkamer. Die is er voor jou en helpt meteen.',
    ),
  ];

  static const hulpVragenJongere = [
    HhVraag(
      'Wanneer kan ik beginnen?',
      'Eerst controleert de meldkamer je aanmelding. Daarna zie je klussen '
          'in je buurt.',
    ),
    HhVraag(
      'Wat verdien ik?',
      'Bij elke klus staat de vergoeding. Die wordt per periode aan je '
          'uitbetaald.',
    ),
    HhVraag(
      'Wat is een VOG?',
      'Een Verklaring Omtrent het Gedrag. Die laat zien dat je te '
          'vertrouwen bent bij mensen thuis. We helpen je met aanvragen.',
    ),
    HhVraag(
      'Kan ik een klus afzeggen?',
      'Ja, maar doe het op tijd en zeg waarom. Zo blijft de bewoner niet '
          'wachten.',
    ),
    HhVraag(
      'Wat als er iets misgaat tijdens een klus?',
      'Bel de meldkamer. Dat kan altijd, ook tijdens de klus.',
    ),
  ];

  static const hulpVragenFamilie = [
    HhVraag(
      'Hoe koppel ik mij aan mijn familielid?',
      'Je familielid nodigt je uit vanuit zijn of haar account. Daarna zie '
          'je de klussen mee.',
    ),
    HhVraag(
      'Kan ik klussen plaatsen voor mijn familielid?',
      'Ja. Je plaatst de klus op naam van je familielid en kijkt mee hoe '
          'het gaat.',
    ),
    HhVraag(
      'Zie ik wie er langskomt?',
      'Ja. Je ziet de naam van de helper en de status van de klus.',
    ),
    HhVraag(
      'Wie betaalt?',
      'De klus staat op naam van je familielid. Je ziet het bedrag vooraf.',
    ),
    HhVraag(
      'Wat als ik me zorgen maak?',
      'Bel de meldkamer. Die kent de situatie en kan ingrijpen.',
    ),
  ];

  static const hulpVragenCoordinator = [
    HhVraag(
      'Wat kan ik in de app?',
      'Het hoognodige: inloggen, klussen bekijken en telefonisch ingevoerde '
          'klussen. Het beheerwerk blijft op het webpaneel.',
    ),
    HhVraag(
      'Hoe maak ik een coordinator-account?',
      'Niet via de app. Een bestaande coordinator maakt het aan op het '
          'webpaneel.',
    ),
    HhVraag(
      'Waar staan de screeningen?',
      'Op het webpaneel onder Screening. De app toont alleen de status.',
    ),
    HhVraag(
      'Wie ziet welke gegevens?',
      'Elke rol ziet alleen wat bij hem hoort. De coordinator ziet alles '
          'binnen HeitjeHulp.',
    ),
    HhVraag(
      'Waar meld ik een storing?',
      'Bij systeembeheer via het webpaneel.',
    ),
  ];

  // Landing per rol (M0-stub, gevuld in M3-M10)
  static String landingWelkom(String naam) => 'Hallo $naam';
  static String landingRol(String rol) => 'Je bent ingelogd als $rol.';
  static const landingKomtLater =
      'Dit deel van de app komt in een latere opdracht.';
  static const landingInstellingen = 'Instellingen';

  // Meldingen bij fouten (HhFout.melding)
  static const foutGeenVerbinding =
      'Geen verbinding. Controleer je internet en probeer het opnieuw.';
  static const foutOngeldigeInlog =
      'E-mailadres of wachtwoord klopt niet. Probeer het opnieuw.';
  static const foutEmailBestaatAl =
      'Er bestaat al een account met dit e-mailadres. Log in of vraag een '
      'nieuw wachtwoord aan.';
  static const foutEmailNietBevestigd =
      'Bevestig eerst je e-mailadres. Kijk in je e-mail voor de link.';
  static const foutSessieVerlopen =
      'Je bent uitgelogd omdat je sessie is verlopen. Log opnieuw in.';
  static const foutGeenToegang = 'Dit mag je met dit account niet doen.';
  static const foutNietGevonden = 'Dit is niet gevonden.';
  static const foutOngeldigeInvoer =
      'Er klopt iets niet in de ingevulde gegevens. Controleer ze en '
      'probeer het opnieuw.';
  static const foutServer =
      'Er ging iets mis bij ons. Probeer het straks opnieuw.';
  static const foutOnbekend = 'Er ging iets mis. Probeer het opnieuw.';

  // Dev-scherm (alleen debug)
  static const devTitel = 'Dev (alleen debug)';
  static const devUitleg =
      'Ontwikkelscherm. Niet in release-builds; geen tekst hieruit hoort '
      'in de echte app.';
  static const devDichtheid = 'Dichtheid';
  static const devNormaal = 'Normaal';
  static const devGroot = 'Groot';
  static const devSchermen = 'Schermen';
}
