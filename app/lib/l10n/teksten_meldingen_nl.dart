// Schermteksten van meldingen en veiligheid (M8): het meldingen-overzicht,
// het belletje, de regel op O1, O10 Bel ons en O11 Probleem melden. Eigen
// bestand naast de andere teksten; nergens een losse string in een widget.
//
// De meldingen zelf (titel en tekst) maakt de server (hook
// hh_meldingen_hulp.js). De titels hieronder zijn alleen de terugval als een
// melding zonder titel binnenkomt. Voor de oudere met "u", voor de jongere
// met "je"; ouderenteksten in hele zinnen zonder cijfers.

abstract final class TekstenMeldingenNl {
  // ---- Terugval-titels per soort --------------------------------------
  static const soortNieuweKlus = 'Nieuwe klus in je buurt';
  static const soortToegewezenOudere = 'Er komt iemand u helpen';
  static const soortToegewezenJongere = 'Je staat op een klus';
  static const soortToegewezenAnder = 'Er komt iemand helpen';
  static const soortOnderwegOudere = 'Er is iemand onderweg naar u';
  static const soortOnderwegAnder = 'Er is iemand onderweg';
  static const soortAfgerondOudere = 'De hulp is klaar';
  static const soortAfgerondJongere = 'Klus afgerond';
  static const soortGeannuleerdOudere = 'Uw hulpvraag is gewijzigd';
  static const soortGeannuleerdJongere = 'Klus gaat niet door';
  static const soortIncident = 'Nieuwe melding';
  static const soortOnbekend = 'Melding';

  // ---- Meldingen-overzicht (/meldingen) -------------------------------
  static const overzichtTitel = 'Meldingen';
  static const overzichtLeeg = 'Nog geen meldingen';
  static const overzichtLeegUitleg =
      'Als er iets verandert aan een klus, zie je het hier.';
  static const overzichtLadenMislukt =
      'Je meldingen konden niet worden geladen.';
  static const ongelezen = 'ongelezen';
  static String tegelSemantiek(
    String titel,
    String tekst,
    String tijd,
    bool isNieuw,
  ) => '${isNieuw ? '$ongelezen, ' : ''}$titel. $tekst. $tijd';
  static String tijd(String dag, String klok) => '$dag $klok';

  // ---- Het belletje in de kop ------------------------------------------
  static const belLabel = 'Meldingen';
  static String belSemantiek(int ongelezen) => switch (ongelezen) {
    0 => 'Meldingen, niets nieuw',
    1 => 'Meldingen, 1 ongelezen',
    _ => 'Meldingen, $ongelezen ongelezen',
  };
  static String belTeller(int ongelezen) => ongelezen > 9 ? '9+' : '$ongelezen';

  // ---- O1: de laatste melding als rustige regel ------------------------
  static const o1LaatsteSemantiek = 'Laatste bericht';

  // ---- O10 Bel ons ------------------------------------------------------
  static const o10Titel = 'Bel ons';
  static const o10Uitleg =
      'De meldkamer van HeitjeHulp helpt u verder. Tik op de knop om te bellen.';
  static const o10Bellen = 'Bel de meldkamer';
  static String o10BellenSemantiek(String nummer) =>
      'Bel de meldkamer, $nummer';

  /// PLACEHOLDER tot Mozaiek de echte tijden geeft (OPEN-PUNTEN-M8).
  static const o10Openingstijden =
      'Wij zijn bereikbaar op werkdagen, van negen tot vijf uur.';
  static const o10ProbleemMelden = 'Probleem melden';
  static const o10ProbleemMeldenSemantiek =
      'Meld een probleem of vraag nu om hulp';

  // ---- O11 Probleem melden / noodknop ----------------------------------
  static const o11Titel = 'Probleem melden';
  static const o11Vraag = 'Wat is er aan de hand?';
  static const o11Nood = 'Ik heb nu hulp nodig';
  static const o11NoodSemantiek = 'Noodknop: ik heb nu hulp nodig';
  static const o11Probleem = 'Er is iets niet goed gegaan';

  static const o11NoodVraagU = 'Wilt u dat wij u nu bellen?';
  static const o11NoodVraagJe = 'Wil je dat wij je nu bellen?';
  static const o11NoodJa = 'Ja, bel mij';
  static const o11NoodNee = 'Nee, toch niet';
  static const o11NoodVerstuurdU = 'We bellen u zo snel mogelijk.';
  static const o11NoodVerstuurdJe = 'We bellen je zo snel mogelijk.';
  static const o11NoodVerstuurdUitleg =
      'De meldkamer heeft uw melding. Kan het niet wachten, bel dan zelf.';
  static const o11NoodVerstuurdUitlegJe =
      'De meldkamer heeft je melding. Kan het niet wachten, bel dan zelf.';

  static const o11ProbleemVraag = 'Wat ging er mis?';
  static const o11KeuzeNietGekomen = 'Er kwam niemand';
  static const o11KeuzeKapot = 'Er is iets kapot of kwijt';
  static const o11KeuzeNietPrettig = 'Ik voelde me niet prettig';
  static const o11KeuzeAnders = 'Iets anders';
  static const o11AndersLabel = 'Wat ging er mis?';
  static const o11AndersHulp = 'Schrijf het in een paar woorden.';
  static const o11AndersTeKort = 'Schrijf kort wat er mis ging.';
  static const o11AndersTeLang = 'Uw tekst is te lang. Maak hem wat korter.';
  static const o11Versturen = 'Versturen';
  static const o11ProbleemVerstuurdU =
      'Dank u wel. De meldkamer neemt contact met u op.';
  static const o11ProbleemVerstuurdJe =
      'Bedankt. De meldkamer neemt contact met je op.';
  static const o11MetKlus = 'We sturen de klus van nu mee.';
  static const o11Klaar = 'Klaar';
  static const o11Mislukt =
      'Het versturen lukte niet. Probeer het opnieuw of bel ons.';

  // ---- J15: dezelfde ingang voor de jongere -----------------------------
  static const j15ProbleemMelden = 'Probleem melden';
  static const j15ProbleemMeldenSemantiek =
      'Meld een probleem bij deze klus aan de meldkamer';
}
