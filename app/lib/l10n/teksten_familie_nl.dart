// Schermteksten van de familie (M9: F1, F2, F3) en van het blok "Familie"
// op O12 bij de oudere. Eigen bestand; nergens een losse string in een
// widget. Het familielid en de oudere worden allebei met "u" aangesproken;
// de oudere-teksten in hele, gewone zinnen zonder cijfers.

abstract final class TekstenFamilieNl {
  // ---- F1 Gekoppelde oudere kiezen (/familie) --------------------------
  static const f1Titel = 'Familie';
  static const f1Uitleg = 'Kies voor wie u wilt meekijken of hulp vragen.';
  static const f1GekoppeldKop = 'Gekoppeld';
  static const f1Leeg = 'Nog niemand gekoppeld';
  static const f1LeegUitleg =
      'Vraag uw familielid om toestemming. Daarna kunt u meekijken en hulp '
      'voor hem of haar vragen.';
  static const f1AanvragenKop = 'Wacht op toestemming';
  static const f1AanvraagRegel = 'Uw vraag is verstuurd.';
  static const f1AanvraagUitleg =
      'Zodra uw familielid Ja zegt, staat hij of zij hierboven.';
  static const f1Koppelen = 'Familielid koppelen';
  static const f1Instellingen = 'Instellingen';
  static const f1LadenMislukt = 'Uw koppelingen konden niet worden geladen.';
  static String f1TegelSemantiek(String naam) => 'Kijk mee bij $naam';
  static const onbekendeNaam = 'Uw familielid';

  // ---- Aanvragen (/familie/koppelen) -----------------------------------
  static const aanvraagTitel = 'Familielid koppelen';
  static const aanvraagUitleg =
      'Vul het e-mailadres in waarmee uw familielid in HeitjeHulp is '
      'ingelogd. Uw familielid krijgt dan een vraag om toestemming.';
  static const aanvraagEmailLabel = 'E-mailadres van uw familielid';
  static const aanvraagVersturen = 'Vraag versturen';
  static const aanvraagEmailFout = 'Vul een geldig e-mailadres in.';
  static const aanvraagLimiet =
      'U heeft vandaag al vaak een aanvraag gedaan. Probeer het morgen opnieuw.';
  static const aanvraagGeenFamilie =
      'Alleen een familielid kan een koppeling aanvragen.';

  /// Terugval als de server geen tekst meegeeft; gelijk aan de hook.
  static const aanvraagVastBericht =
      'Als dit adres bij ons bekend is, krijgt uw familielid een vraag om '
      'toestemming.';
  static const aanvraagTerug = 'Terug naar het overzicht';

  // ---- F3 Meekijken (/familie/oudere/:id) ------------------------------
  static String f3Titel(String naam) => 'Bij $naam';
  static const f3TitelZonderNaam = 'Meekijken';
  static String f3HulpVragen(String naam) => 'Hulp vragen voor $naam';
  static const f3HulpVragenZonderNaam = 'Hulp vragen';
  static const f3GeenMeekijken =
      'U heeft geen toestemming om mee te kijken. U kunt wel hulp vragen.';
  static const f3GeenToegang =
      'Deze koppeling is niet (meer) actief. Ga terug naar het overzicht.';
  static const f3TabbladenLabel = 'Hulpvragen';
  static const f3LadenMislukt = 'De hulpvragen konden niet worden geladen.';
  static const f3MeldingenKop = 'Meldingen';
  static const f3MeldingenLeeg = 'Nog geen meldingen.';
  static const f3MeldingenMislukt = 'De meldingen laden niet.';
  static const f3AndereOudere = 'Terug naar het overzicht';

  // ---- F3 detail (/familie/oudere/:id/hulpvraag/:klusId) ----------------
  static const f3DetailTitel = 'Hulpvraag';
  static const f3DoorMij = 'Deze hulpvraag heeft u geplaatst.';
  static const f3Annuleren = 'Hulpvraag stoppen';
  static const f3AnnulerenSemantiek = 'Stop deze hulpvraag';
  static const f3Geannuleerd = 'De hulpvraag is gestopt.';

  // Statuszin op F3-detail en in de lijsten: de oudere wordt geholpen,
  // niet het familielid. Daarom de naam van de oudere, nooit "u" (M12).
  static const f3Helper = 'Helper';
  static const f3OudereZonderNaam = 'uw familielid';
  static String f3Aangenomen(String jongere, String oudere) =>
      '$jongere komt $oudere helpen.';
  static String f3Onderweg(String jongere, String oudere) =>
      '$jongere is onderweg naar $oudere.';
  static String f3Bezig(String jongere, String oudere) =>
      '$jongere is bij $oudere aan het werk.';
  static String f3GeenJongere(String oudere) =>
      'We zoeken iemand voor $oudere.';
  static String f3Probleem(String oudere) =>
      'Er is iets misgegaan. Wij nemen contact op met $oudere.';

  // ---- O12 bij de oudere: blok "Familie" -------------------------------
  static const o12Kop = 'Familie';
  static const o12Niemand = 'Er kijkt nog niemand van uw familie mee.';
  static String o12Vraag(String naam) =>
      '$naam wil met u meekijken en hulp voor u kunnen vragen. '
      'Vindt u dat goed?';
  static const o12Ja = 'Ja, dat is goed';
  static const o12Nee = 'Nee';
  static String o12Gekoppeld(String naam) => '$naam kijkt met u mee.';
  static const o12Ontkoppelen = 'Ontkoppelen';
  static String o12OntkoppelenSemantiek(String naam) =>
      'Stop het meekijken van $naam';
  static String o12OntkoppelVraag(String naam) =>
      'Wilt u dat $naam niet meer met u meekijkt?';
  static const o12OntkoppelJa = 'Ja, ontkoppelen';
  static const o12OntkoppelNee = 'Nee, laat maar';
  static const o12JaGelukt = 'Goed. Uw familielid kijkt nu met u mee.';
  static const o12NeeGelukt = 'De vraag is weg.';
  static const o12OntkoppeldGelukt = 'Uw familielid kijkt niet meer mee.';
  static const o12LadenMislukt = 'Uw familie kon niet worden geladen.';
}
