// Schermteksten van het adres "zoals bol.com" (4 okt): postcode + huisnummer
// -> straat en plaats via PDOK. Je-vorm, korte zinnen.

abstract final class TekstenAdresNl {
  static const veldPostcode = 'Postcode';
  static const veldHuisnummer = 'Huisnummer';
  static const veldToevoeging = 'Toevoeging';
  static const veldToevoegingHulp = 'Mag leeg';
  static const uitleg =
      'Vul je postcode en huisnummer in. Straat en plaats vullen we zelf in.';

  static const zoeken = 'We zoeken je adres…';
  static const gevondenSemantiek = 'Adres gevonden';
  static const kiesKop =
      'Op dit huisnummer zijn meer adressen. Kies het jouwe:';
  static const kiesAnder = 'Ander adres kiezen';

  static const nietGevonden =
      'We vinden dit adres niet. Klopt de postcode en het huisnummer?';
  static const dienstWeg =
      'We kunnen je adres nu niet controleren. Je kunt gewoon verder; de '
      'meldkamer kijkt het later na.';

  static const validatiePostcode =
      'Een postcode is 4 cijfers en 2 letters, bijvoorbeeld 4001 MA.';
  static const validatieToevoeging =
      'Een toevoeging is hooguit 6 letters of cijfers, bijvoorbeeld A of 2.';
  static const validatieVerplicht =
      'Vul je postcode en huisnummer in. Kies daarna je adres.';
  static const validatieNietBevestigd =
      'Kies eerst een adres dat we kunnen vinden.';
  static const validatieWachten = 'Even wachten: we zoeken je adres nog.';

  // Gele balk voor bestaande accounts met een onvolledig adres.
  static const aanvullenKop = 'Vul je adres aan';
  static const aanvullenUitleg =
      'We missen je volledige postcode of je huisnummer. Vul het aan, dan '
      'weten we of HeitjeHulp in jouw buurt is.';
  static const aanvullenKnop = 'Adres aanvullen';

  // Helper: eigen scherm "Mijn adres".
  static const mijnAdresTitel = 'Mijn adres';
  static const mijnAdresUitleg =
      'Met je adres zoeken we klussen bij jou in de buurt. Bewoners zien je '
      'adres nooit.';
  static const opgeslagen = 'Je adres is opgeslagen.';
  static const nietsGewijzigd = 'Er is niets gewijzigd.';
}
