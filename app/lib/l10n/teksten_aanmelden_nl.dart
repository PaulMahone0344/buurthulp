// Schermteksten van aanmelden (B2): registreren als bewoner of helper, de
// stappen "Jij - Ouder - Klaar", de wachtbalk van de helper en het vinkje
// "ID gecontroleerd". Je-vorm, korte zinnen.

abstract final class TekstenAanmeldenNl {
  // Welkom (mockup AWelkom)
  static const welkomZoekHulpUitleg =
      'Plaats een klus. Een helper uit je buurt helpt je.';
  static const welkomWilHelpenUitleg =
      'Help mensen in je buurt en verdien zakgeld. Vanaf 10 jaar.';

  // Registreren bewoner (mockup AAanmeldenBewoner)
  static const bewonerTitel = 'Aanmelden';
  static const bewonerUitleg =
      'Je zoekt hulp in je buurt? Maak hier je account.';
  static const veldNaam = 'Naam';
  static const veldStraat = 'Straat';
  static const veldHuisnummer = 'Huisnummer';
  static const veldPostcode = 'Postcode';
  static const veldPostcodeHulp = 'Bijvoorbeeld 4003 AB.';
  static const veldPlaats = 'Plaats';
  static const adresUitleg =
      'Je adres ziet alleen de helper die jij kiest, na de match.';
  static const akkoordTekst =
      'Ik ga akkoord met de voorwaarden en de privacyverklaring.';
  static const akkoordLinks = 'Lees de voorwaarden en de privacyverklaring';
  static const wachtwoordTonen = 'Wachtwoord tonen';
  static const wachtwoordVerbergen = 'Wachtwoord verbergen';

  // Registreren helper (mockup H6, stap 1)
  static const helperTitel = 'Aanmelden';
  static const helperUitleg = 'Fijn dat je wilt helpen. Vul je gegevens in.';
  static const veldVoornaam = 'Voornaam';
  static const veldVoornaamHulp = 'Bewoners zien alleen je voornaam.';
  static const veldGeboortedatum = 'Geboortedatum';
  static const veldGeboortedatumHulp =
      'Dag-maand-jaar, bijvoorbeeld 14-05-2012.';
  static const veldOuder = 'E-mailadres van je ouder';
  static const veldOuderHulp =
      'Je bent onder de 18. Je ouder krijgt een mail en geeft één keer '
      'toestemming.';
  static const postcodeUitleg =
      'Met je postcode zoeken we klussen bij jou in de buurt.';

  // Stappen "1 Jij - 2 Ouder - 3 Klaar"
  static const stapJij = 'Jij';
  static const stapOuder = 'Ouder';
  static const stapKlaar = 'Klaar';
  static String stappenZin(int stap, int totaal, String naam) =>
      'Stap $stap van $totaal: $naam';

  // Validatie
  static const validatieVoornaamVerplicht = 'Vul je voornaam in.';
  static const validatieStraatVerplicht = 'Vul je straat in.';
  static const validatieHuisnummerVerplicht = 'Vul je huisnummer in.';
  static const validatieHuisnummerOngeldig =
      'Een huisnummer begint met een cijfer, bijvoorbeeld 12 of 12a.';
  static const validatiePostcodeVerplicht = 'Vul je postcode in.';
  static const validatiePostcodeOngeldig =
      'Een postcode is 4 cijfers en 2 letters, bijvoorbeeld 4003 AB.';
  static const validatiePlaatsVerplicht = 'Vul je plaats in.';
  static const validatieGeboortedatumVerplicht = 'Vul je geboortedatum in.';
  static const validatieGeboortedatumOngeldig =
      'Dit is geen geldige datum. Gebruik dag-maand-jaar.';
  static const validatieGeboortedatumToekomst =
      'Deze datum ligt in de toekomst.';
  static const validatieTeJong =
      'Je moet minstens 10 jaar zijn om helper te worden. Kom terug als je '
      '10 bent.';
  static const validatieOuderVerplicht = 'Vul het e-mailadres van je ouder in.';
  static const validatieOuderOngeldig = 'Vul een geldig e-mailadres in.';
  static const validatieOuderEigen =
      'Vul het e-mailadres van je ouder in, niet je eigen adres.';
  static const validatieAkkoord =
      'Zet het vinkje om akkoord te gaan met de voorwaarden.';

  // Na het indienen (mockup H6b)
  static const binnenTitel = 'Aanmelding binnen';
  static const binnenKop = 'Je aanmelding is binnen';
  static const binnenUitleg =
      'De meldkamer kijkt hem na, meestal binnen 1 dag.';
  static const binnenMelding = 'Je krijgt een melding als je kunt beginnen.';
  static const naarStart = 'Naar de start';

  // Wachtbalk bovenaan Start (helper)
  static const wachtNagekeken = 'Je aanmelding wordt nagekeken';
  static const wachtNagekekenUitleg =
      'De meldkamer kijkt je aanmelding na. Daarna kun je beginnen.';
  static const wachtOuder = 'Wacht op toestemming van je ouder';
  static const wachtOuderUitleg =
      'Je ouder moet één keer toestemming geven. Daarna kun je beginnen.';
  static const wachtVog = 'Regel je VOG';
  static const wachtVogUitleg =
      'Je bent 18 of ouder. Vraag je VOG aan via Justis. De meldkamer kijkt '
      'hem na.';
  static const wachtVogKnop = 'Over je VOG';
  static const wachtGeenKlussenKop = 'Nog even geduld';
  static const wachtGeenKlussen = 'Je ziet hier klussen zodra alles rond is.';
  static const wachtVernieuwen = 'Opnieuw kijken';

  // Aanmelding afronden (J9, ingekort)
  static const overzichtUitleg =
      'Nog één ding: een foto van je ID. Daarna kijkt de meldkamer je '
      'aanmelding na.';
  static const overzichtUitlegVog =
      'Nog twee dingen: een foto van je ID en je VOG. Daarna kijkt de '
      'meldkamer je aanmelding na.';
  static const overzichtVersturen = 'Aanmelding versturen';
  static const overzichtVersturenHulp =
      'Je kunt versturen als je ID-foto er staat.';
  static const overMijTitel = 'Over mij';
  static const overMijNietVerplicht = 'Over mij (mag leeg)';
  static const overMijUitleg =
      'Een paar zinnen over jezelf. Bewoners zien dit als ze een helper '
      'kiezen. Dit mag ook leeg blijven.';
  static const overMijHulp = 'Waar help je graag mee? Maximaal 500 tekens.';
  static const validatieOverMijTeLang = 'Maximaal 500 tekens.';
  static const opslaan = 'Opslaan';

  // ID-foto (J2)
  static const idTipKopieId =
      'Tip: met de app KopieID van de Rijksoverheid dek je je BSN makkelijk '
      'af en zet je er een watermerk op.';
  static const idNaGoedkeuring =
      'Je ID is gecontroleerd. De foto is gewist. Je hoeft niets meer te '
      'doen.';

  // VOG (alleen 18+)
  static const vogUitleg =
      'Je bent 18 of ouder. Dan heb je een VOG nodig: een Verklaring '
      'Omtrent het Gedrag. Vraag je VOG aan via Justis. De meldkamer kijkt '
      'hem na.';
  static String vogGezienOp(String datum) =>
      'De meldkamer zag je VOG op $datum.';
  static const vogNogNietGezien = 'De meldkamer heeft je VOG nog niet gezien.';

  // Werkgebied (Tiel + 20 km)
  static const nietInBuurt =
      'HeitjeHulp is nog niet in jouw buurt. We laten het je weten zodra we '
      'er zijn.';
  static const nietInBuurtKop = 'Nog niet in jouw buurt';
  static const adresOnbekend =
      'We konden je adres nog niet vinden. De meldkamer kijkt ernaar.';
  static const adresOnbekendKop = 'We zoeken je adres nog';

  // Bewoner ziet bij zijn helper
  static const idGecontroleerd = 'ID gecontroleerd';
}
