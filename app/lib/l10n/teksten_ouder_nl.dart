/// B3: teksten van de ouder-toestemming in de helper-app (je-vorm). De
/// ouder zelf ziet de website (website/src/ouder).
abstract final class TekstenOuderNl {
  static const titel = 'Aanmelden';
  static const kop = 'Toestemming van je ouder';
  static const intro =
      'Je bent onder de 18. Je ouder moet één keer toestemming geven.';

  static const verstuurdKop = 'We hebben je ouder een mail gestuurd.';
  static const verstuurdUitleg =
      'Wacht op toestemming. Je ouder vult de code uit de mail in op de '
      'website van HeitjeHulp.';
  static String naarAdres(String email) => 'De mail ging naar $email.';
  static String verstuurdOm(String tijd) => 'Verstuurd om $tijd';

  static const opnieuw = 'Stuur opnieuw';
  static String nogVandaag(int n) =>
      'Je kunt vandaag nog $n keer een mail sturen.';
  static const geenMeerVandaag =
      'Je kunt vandaag geen mail meer sturen. Probeer het morgen opnieuw.';
  static const gelukt = 'De mail is verstuurd.';

  static const wijzig = 'E-mailadres van je ouder wijzigen';
  static const emailLabel = 'E-mailadres van je ouder';
  static const emailHulp = 'Het adres van je ouder, niet je eigen adres.';
  static const emailOngeldig = 'Vul een geldig e-mailadres in.';
  static const stuurNaarNieuw = 'Stuur naar dit adres';
  static const annuleren = 'Annuleren';

  /// K1: bij aanmelden alleen een telefoonnummer opgegeven.
  static const alleenTelefoonKop = 'Vul ook het e-mailadres van je ouder in';
  static const alleenTelefoonUitleg =
      'We sturen je ouder een mail met een code. Een sms sturen kan nog niet.';
  static const stuur = 'Stuur mail naar mijn ouder';
  static const bezig = 'De mail wordt verstuurd…';

  static const verlopenKop = 'De code werkt niet meer';
  static const verlopenUitleg =
      'De code was 24 uur geldig, of er is te vaak een verkeerde code '
      'ingevuld. Stuur je ouder een nieuwe mail.';

  static const gegevenKop = 'Je ouder heeft toestemming gegeven.';
  static const gegevenUitleg = 'Daarna kijkt de meldkamer je aanmelding na.';

  static const ingetrokkenKop = 'Je ouder heeft de toestemming ingetrokken.';
  static const ingetrokkenUitleg =
      'Je kunt nu geen klussen aannemen. Praat erover met je ouder. Wil je '
      'ouder het opnieuw bekijken? Stuur dan een nieuwe mail.';

  static const verderAanmelding = 'Verder met je aanmelding';
  static const naarStart = 'Naar de start';
  static const laden = 'Laden…';

  // Gele balk op Start
  static const balkIngetrokkenUitleg =
      'Je kunt geen klussen aannemen. Praat erover met je ouder.';
  static const balkKnop = 'Mail aan je ouder';
}
