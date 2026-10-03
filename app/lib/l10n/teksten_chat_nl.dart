// Schermteksten van de chat (B6). Eigen bestand per milestone (regel
// _GEDEELD-B3-B4-B6); nergens een losse string in een widget. Iedereen
// krijgt "je".

abstract final class TekstenChatNl {
  // ---- Knoppen naar de chat --------------------------------------------
  static const chat = 'Chat';
  static String chatMet(String naam) => naam.isEmpty ? chat : 'Chat met $naam';
  static const openDeChat = 'Open de chat';
  static String knopSemantiek(String naam, int ongelezen) {
    final wie = naam.isEmpty ? 'Chat' : 'Chat met $naam';
    return switch (ongelezen) {
      0 => wie,
      1 => '$wie, 1 nieuw bericht',
      _ => '$wie, $ongelezen nieuwe berichten',
    };
  }

  static String teller(int ongelezen) => ongelezen > 9 ? '9+' : '$ongelezen';

  // ---- Kop van het chatscherm --------------------------------------------
  static const titelZonderNaam = 'Chat';
  static const meldProbleem = 'Meld een probleem';
  static const verborgen = 'Je telefoonnummer blijft verborgen';

  // ---- Berichten --------------------------------------------------------
  static const vandaag = 'Vandaag';
  static const gisteren = 'Gisteren';
  static const gelezen = 'Gelezen';
  static const filterUitleg = 'Nummer, mail of link verborgen';
  static const ik = 'Jij';
  static String bubbelSemantiek(
    String wie,
    String tijd,
    String tekst, {
    required bool isGelezen,
  }) => '$wie, $tijd: $tekst${isGelezen ? '. $gelezen' : ''}';
  static const leeg = 'Nog geen berichten';
  static String leegUitleg(String naam) => naam.isEmpty
      ? 'Stuur een bericht of tik op een snelle knop.'
      : 'Stuur $naam een bericht of tik op een snelle knop.';

  // ---- Invoer ---------------------------------------------------------------
  static const invoerLabel = 'Bericht';
  static const invoerHint = 'Typ een bericht';
  static const verstuur = 'Verstuur';
  static const snelleBerichten = 'Snelle berichten';
  static const gesloten = 'Deze chat is gesloten.';
  static const geslotenUitleg = 'Je kunt de berichten nog wel lezen.';
  static const verstuurMislukt =
      'Je bericht is niet verstuurd. Probeer het opnieuw.';
  static const ladenMislukt = 'De chat kon niet worden geladen.';

  // ---- Snelknoppen ---------------------------------------------------------
  static const snelHelper = ['Ik ben onderweg', 'Ik ben er', 'Klaar'];
  static const snelBewoner = ['Prima!', 'Ik ben thuis', 'Bel even aan'];

  // ---- Gesprek verwijderen en AVG (integratie, antwoorden Ibrahim 4 okt) --
  static const gesprekVerwijderen = 'Gesprek verwijderen';
  static const verwijderVraag = 'Gesprek verwijderen?';
  static String verwijderUitleg(String naam) =>
      'Het gesprek verdwijnt alleen bij jou. '
      '${naam.isEmpty ? 'De ander' : naam} houdt de berichten. '
      'Een nieuw bericht zie je wel weer.';
  static const verwijderNee = 'Niet verwijderen';
  static const verwijderJa = 'Verwijderen';
  static const gesprekVerwijderd = 'Het gesprek is verwijderd.';
  static const verwijderIncident =
      'Er loopt een melding over deze klus. Je kunt het gesprek verwijderen '
      'zodra de meldkamer die heeft afgehandeld.';
  static const verwijderMislukt =
      'Het gesprek is niet verwijderd. Probeer het opnieuw.';
  static const berichtVerwijderd = 'Bericht verwijderd';

  // ---- Melding (terugval-titel; de server geeft er altijd een mee) --------
  static const meldingTitel = 'Nieuw bericht';
}
