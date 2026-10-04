// B11: schermteksten van het tabblad "Te doen" van de meldkamer in de app.
// Nederlands, gewone taal. Nergens een losse string in een widget.

abstract final class TekstenMeldkamerNl {
  // Tab
  static const tabTeDoen = 'Te doen';
  static String tabTeller(int aantal) => '$aantal';
  static String tabSemantiek(int aantal) =>
      aantal == 1 ? 'Te doen, 1 ding' : 'Te doen, $aantal dingen';

  // Scherm
  static const titel = 'Te doen';
  static const legeTitel = 'Niets te doen';
  static const legeUitleg =
      'Alles is afgehandeld. Lange lijsten en instellingen vind je in het '
      'beheerpaneel op de website.';
  static const ladenMislukt = 'Te doen kon niet worden geladen';

  // Bellen (kennismaking)
  static const bellenKop = 'Nieuwe bewoners bellen';
  static const bellenUitleg =
      'Bel even (5 minuten) om kennis te maken. Je mag iemand weigeren.';
  static const bel = 'Bel';
  static String belSemantiek(String naam) => 'Bel $naam';
  static const geenTelefoon = 'Geen telefoonnummer';
  static const gesproken = 'Gesproken';
  static const weigeren = 'Weigeren';
  static String gesprokenTitel(String naam) => 'Gesproken met $naam';
  static String weigerenTitel(String naam) => '$naam weigeren';
  static const weigerenUitleg =
      'Het account wordt geblokkeerd en open klussen zonder helper worden '
      'geannuleerd. Schrijf kort waarom.';
  static const notitieOptioneel = 'Notitie (optioneel)';
  static const notitieVerplicht = 'Notitie';
  static const notitieHulp = 'Alleen de meldkamer ziet dit.';
  static String gesprokenGelukt(String naam) =>
      'Kennismaking met $naam staat erin.';
  static String geweigerdGelukt(String naam, int geannuleerd) =>
      geannuleerd == 0
      ? '$naam is geweigerd.'
      : '$naam is geweigerd. $geannuleerd open '
            '${geannuleerd == 1 ? 'klus' : 'klussen'} geannuleerd.';

  // Helpers keuren
  static const helpersKop = 'Helpers keuren';
  static String helperLeeftijd(int jaren) => '$jaren jaar';
  static const goedkeuren = 'Goedkeuren';
  static const afwijzen = 'Afwijzen';
  static String goedkeurenTitel(String naam) => '$naam goedkeuren';
  static String afwijzenTitel(String naam) => '$naam afwijzen';
  static const goedkeurenStandaardNotitie = 'Goedgekeurd in de app.';
  static const afwijzenUitleg =
      'Schrijf waarom; wie later kijkt, moet het kunnen zien.';
  static String helperGelukt(String naam, {required bool goedgekeurd}) =>
      goedgekeurd ? '$naam is goedgekeurd.' : '$naam is afgewezen.';

  // Ouder
  static const oudersKop = 'Ouder trok toestemming in';
  static const oudersUitleg =
      'Vrijgeven betekent: de helper mag zijn ouder opnieuw mailen.';
  static const vrijgeven = 'Vrijgeven';
  static String vrijgevenTitel(String naam) => 'Ouder van $naam vrijgeven';
  static String vrijgevenGelukt(String naam) =>
      '$naam kan de ouder opnieuw mailen.';

  // Klussen keuren
  static const klussenKop = 'Klussen keuren';
  static const klussenUitleg = 'Helpers zien een klus pas na je goedkeuring.';
  static const afkeuren = 'Afkeuren';
  static const eerstBellen = 'Bel eerst de bewoner (zie hierboven).';
  static String afkeurenTitel(String soort) => 'Klus "$soort" afkeuren';
  static const afkeurenUitleg =
      'De bewoner krijgt deze reden te zien. Schrijf hem in gewone taal.';
  static const reden = 'Reden';
  static const klusGoedgekeurd =
      'Klus goedgekeurd. Helpers in de buurt zien hem nu.';
  static const klusAfgekeurd = 'Klus afgekeurd. De bewoner ziet de reden.';

  // Dialoog
  static const annuleren = 'Annuleren';
}
