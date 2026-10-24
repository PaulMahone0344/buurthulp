/// Alle routepaden van de app op een plek, zodat de router, de rollen en
/// de schermen hetzelfde woord gebruiken.
abstract final class HhPaden {
  // Toegang (G1-G8)
  static const splash = '/';
  static const welkom = '/welkom';
  static const kennismaken = '/kennismaken';

  /// Dezelfde pagina's opnieuw, vanuit Hulp (ingelogd; terug = sluiten).
  static const uitleg = '/uitleg';
  static const inloggen = '/inloggen';
  static const registreren = '/registreren';
  static const bevestigEmail = '/bevestig-email';
  static const wachtwoordVergeten = '/wachtwoord-vergeten';
  static const instellingen = '/instellingen';
  static const hulp = '/hulp';

  // Landing per rol (M0-stubs; tabs komen in M3-M10)
  static const hulpvrager = '/hulpvrager';
  static const jongere = '/jongere';
  static const coordinator = '/coordinator';

  /// Alleen in debug-builds geregistreerd.
  static const dev = '/dev';

  /// Bereikbaar zonder in te loggen.
  static const zonderSessie = {
    kennismaken,
    welkom,
    inloggen,
    registreren,
    wachtwoordVergeten,
    hulp,
  };

  /// Toegangsschermen waar een ingelogde gebruiker niets te zoeken heeft.
  static const alleenUitgelogd = {
    splash,
    kennismaken,
    welkom,
    inloggen,
    registreren,
    wachtwoordVergeten,
  };

  static const rolPaden = {hulpvrager, jongere, coordinator};
}
