// Schermteksten van reageren en kiezen (B5): HKlusBekijken ("Ik wil
// helpen"), HReactieVerstuurd, HMijnKlussen (Gereageerd), "Ik kan nu
// helpen", KiesHelper, Match en de geheime vraag bij het beoordelen. Eigen
// bestand per milestone; nergens een losse string in een widget.

abstract final class TekstenReactiesNl {
  // HKlusBekijken: reageren
  static const reageerKop = 'Stuur een kort berichtje mee (mag ook niet)';
  static const reageerHint = 'Bijvoorbeeld: Ik heb al vaker tuinen gedaan.';
  static const reageerKnop = 'Ik wil helpen';
  static const reageerUitleg =
      'De bewoner kiest zelf een helper. Je nummer en adres blijven verborgen.';
  static String alReacties(int n) =>
      n == 1 ? '1 helper reageerde al' : '$n helpers reageerden al';
  static const ouderMeeVinkje = 'Mijn ouder gaat mee bij deze eerste klus';
  static const ouderMeeUitleg =
      'Dit is je eerste klus bij deze bewoner. Tot en met 12 jaar gaat je '
      'ouder de eerste keer mee.';
  static const ouderMeeNodig = 'Zet eerst het vinkje: je ouder gaat mee.';
  static const ouderMeeTip =
      'Tip: je eerste klus bij een nieuwe bewoner? Vertel thuis waar je '
      'naartoe gaat. Je ouder mag altijd mee.';
  static const berichtTeLang = 'Je berichtje mag hooguit 200 tekens zijn.';
  static String berichtTeller(int n) => '$n van 200 tekens';

  // HKlusBekijken: al gereageerd
  static const gereageerdKop = 'Je hebt gereageerd';
  static const gereageerdWacht =
      'De bewoner kiest zelf een helper. Je krijgt een melding.';
  static const gereageerdOuder =
      'Eerst kijkt je ouder of het goed is. Daarna ziet de bewoner je reactie.';
  static const intrekken = 'Reactie intrekken';
  static const intrekkenVraag = 'Reactie intrekken?';
  static const intrekkenUitleg =
      'De bewoner ziet je reactie dan niet meer. Je kunt later opnieuw reageren.';
  static const intrekkenJa = 'Ja, intrekken';
  static const intrekkenNee = 'Nee, laten staan';
  static const ingetrokken = 'Je reactie is ingetrokken.';

  // HReactieVerstuurd
  static const verstuurdTitel = 'Reactie verstuurd';
  static const verstuurdKop = 'Je reactie is verstuurd';
  static const verstuurdUitleg =
      'De bewoner kiest zelf een helper. Je krijgt een melding.';
  static const verstuurdOuderUitleg =
      'We hebben je ouder gemaild. Als je ouder "Goed" kiest, ziet de bewoner '
      'je reactie. Je krijgt een melding.';
  static const pilWacht = 'Wacht';
  static const pilOuder = 'Wacht op je ouder';
  static const meerKlussen = 'Meer klussen bekijken';
  static const naarMijnKlussen = 'Naar mijn klussen';

  // HMijnKlussen: tabbladen
  static const tabGereageerd = 'Gereageerd';
  static const tabGepland = 'Gepland';
  static const tabKlaar = 'Klaar';
  static const leegGereageerd = 'Nog nergens op gereageerd';
  static const leegGereageerdUitleg =
      'Zie je een klus die je wilt doen? Tik op "Ik wil helpen". De bewoner '
      'kiest zelf.';
  static const leegGepland = 'Nog geen klussen gepland';
  static const leegGeplandUitleg =
      'Kiest een bewoner jou, dan staat de klus hier.';
  static const leegKlaar = 'Nog geen klussen klaar';
  static const leegKlaarUitleg = 'Afgeronde klussen staan hier.';
  static const reactiesLadenMislukt = 'Je reacties konden niet worden geladen.';
  static const standWachtBewoner = 'Wacht op de bewoner';
  static const standWachtOuder = 'Wacht op je ouder';
  static const standNietGekozen = 'De bewoner koos iemand anders';
  static const standOuderNee = 'Je ouder koos "liever niet"';
  static const standVervallen = 'Gaat niet door';
  static const onbekendeKlus = 'Klus';

  // Ik kan nu helpen (Start helper)
  static const nuHelpenTitel = 'Ik kan nu helpen';
  static const nuHelpenUit =
      'Zet aan als je de komende uren tijd hebt. Je krijgt dan meldingen van '
      'nieuwe klussen.';
  static String nuHelpenAan(String tijd) =>
      'Aan tot $tijd. Daarna gaat hij vanzelf uit.';
  static const nuHelpenMislukt = 'Dat lukte niet. Probeer het opnieuw.';

  // Start bewoner
  static String helpersWillen(int n) =>
      n == 1 ? '1 helper wil je helpen' : '$n helpers willen je helpen';
  static String helpersWillenBij(String klus) => 'Bij: $klus';
  static const bekijkReacties = 'Kies je helper';

  // Klus plaatsen
  static String helpersKunnenNu(int n) =>
      n == 1 ? '1 helper kan nu helpen' : '$n helpers kunnen nu helpen';

  // KiesHelper
  static const kiesTitel = 'Kies je helper';
  static String aantalReacties(int n) => n == 1 ? '1 reactie' : '$n reacties';
  static String voornaamLeeftijd(String naam, int? leeftijd) =>
      leeftijd == null ? naam : '$naam, $leeftijd';
  static String sterrenAantal(String sterren, int n) => '$sterren ($n)';
  static const nogGeenBeoordeling = 'Nog geen beoordeling';
  static const idGecontroleerd = 'ID gecontroleerd';
  static const ouderGaatMee = 'Ouder gaat mee';
  static String kies(String naam) => 'Kies $naam';
  static String kiesVraag(String naam) => '$naam kiezen?';
  static String kiesUitleg(String naam) =>
      'Andere helpers krijgen een bericht dat je iemand anders koos. '
      '$naam ziet daarna je adres en jullie kunnen chatten.';
  static const kiesJa = 'Ja, kiezen';
  static const kiesNee = 'Nog niet';
  static const geenReacties = 'Nog geen reacties';
  static const geenReactiesUitleg =
      'Zodra een helper wil helpen, zie je hem hier. Je krijgt een melding.';
  static const reactiesMislukt = 'De reacties konden niet worden geladen.';
  static String helperSemantiek({
    required String naam,
    required String leeftijd,
    required String sterren,
    required bool id,
  }) => '$naam, $leeftijd. $sterren.${id ? ' ID gecontroleerd.' : ''}';

  // Match
  static const matchTitel = 'Het is een match!';
  static String matchTekst(String naam, String klus) =>
      '$naam helpt je met $klus.';
  static const matchUitleg =
      'Jullie chatten in de app. Je nummer blijft verborgen.';
  static const openDeChat = 'Open de chat';
  static const later = 'Later';

  // Geheime vraag (beoordelen, punt 11)
  static const geheimVraagBewoner = 'Was alles in orde?';
  static const geheimVraagHelper = 'Voelde je je veilig?';
  static const geheimUitleg =
      'Alleen de meldkamer ziet dit antwoord. De ander niet.';
  static const ja = 'Ja';
  static const nee = 'Nee';
  static const geheimToelichtingLabel =
      'Wil je vertellen wat er was? (mag ook niet)';
  static const geheimKies = 'Kies eerst Ja of Nee.';
  static const geheimNeeBedankt =
      'Dank je. De meldkamer neemt contact met je op.';

  // ---- B9 -----------------------------------------------------------
  /// Pil op KiesHelper bij een helper die nog geen klus klaar heeft.
  static const nieuwInDeBuurt = 'Nieuw in de buurt';
}
