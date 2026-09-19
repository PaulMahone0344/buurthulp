// Alle schermteksten van de coordinator in de app (M10: C1 en C2), in het
// Nederlands. Nergens een losse string in een widget.

abstract final class TekstenCoordinatorNl {
  // Tabbalk
  static const tabbalkLabel = 'Tabbladen';
  static const tabIncidenten = 'Incidenten';
  static const tabKlussen = 'Klussen';
  static const tabInstellingen = 'Instellingen';

  /// Het aantal openstaande incidenten naast het tabblad.
  static String tabIncidentenTeller(int aantal) => '$aantal open';
  static String tabIncidentenSemantiek(int aantal) => aantal == 1
      ? 'Incidenten, 1 open melding'
      : 'Incidenten, $aantal open meldingen';

  // ---- C1 Incidenten ----------------------------------------------------
  static const c1Titel = 'Incidenten';
  static const c1FilterLabel = 'Welke meldingen';
  static const c1FilterOpen = 'Open';
  static const c1FilterAfgehandeld = 'Afgehandeld';
  static const c1LegeOpenTitel = 'Geen open meldingen';
  static const c1LegeOpenUitleg =
      'Zodra iemand een melding doet, verschijnt die hier meteen bovenaan.';
  static const c1LegeAfgehandeldTitel = 'Nog niets afgehandeld';
  static const c1LegeAfgehandeldUitleg =
      'Meldingen die je hebt afgehandeld, bewaren we hier.';
  static const c1LadenMislukt = 'De meldingen konden niet worden geladen';
  static const c1NieuweMelding = 'Nieuwe melding binnengekomen';

  static const soortNood = 'Noodmelding';
  static const soortProbleem = 'Probleem';
  static const soortOverig = 'Overig';

  /// Het label van een rij in de lijst, voor de schermlezer.
  static String c1RijSemantiek(String soort, String melder, String wanneer) =>
      '$soort van $melder, $wanneer';

  // ---- C1 detail --------------------------------------------------------
  static const c1DetailTitel = 'Melding';
  static const c1MelderKop = 'Wie meldde het';
  static const c1GeenTelefoon = 'Geen telefoonnummer bekend';
  static const c1Bellen = 'Bellen';
  static String c1BellenSemantiek(String naam, String nummer) =>
      'Bel $naam, $nummer';
  static String c1BellenLuktNiet(String nummer) =>
      'Bellen lukt niet op dit toestel. Bel zelf $nummer.';
  static const c1KlusKop = 'Bij welke klus';
  static const c1GeenKlus = 'Geen klus: dit kwam van de noodknop.';
  static const c1NaarKlus = 'Bekijk de klus';
  static const c1OmschrijvingKop = 'Wat is er gemeld';
  static const c1GeenOmschrijving = 'Geen omschrijving meegestuurd.';
  static const c1AfhandelingKop = 'Afhandeling';
  static const c1AfhandelingLabel = 'Wat heb je gedaan';
  static const c1AfhandelingHulp =
      'Kort en feitelijk; dit blijft bij de melding staan.';
  static const c1AfhandelingLeeg = 'Vul eerst in wat je hebt gedaan.';
  static const c1Afhandelen = 'Afgehandeld';
  static const c1Afgehandeld = 'Deze melding is afgehandeld.';
  static const c1DetailLadenMislukt = 'Deze melding kon niet worden geladen';

  // ---- C2 Klussen -------------------------------------------------------
  static const c2Titel = 'Klussen';
  static const c2LegeTitel = 'Geen open klussen';
  static const c2LegeUitleg =
      'Alle klussen zijn gekoppeld. Nieuwe open klussen komen hier vanzelf bij.';
  static const c2LadenMislukt = 'De klussen konden niet worden geladen';

  /// "Open sinds 3 dagen" onder een klus in de lijst.
  static String c2OpenSinds(String duur) => 'Open sinds $duur';
  static const c2OpenSindsNet = 'zojuist geplaatst';
  static String c2OpenSindsMinuten(int minuten) =>
      minuten == 1 ? '1 minuut' : '$minuten minuten';
  static String c2OpenSindsUren(int uren) => uren == 1 ? '1 uur' : '$uren uur';
  static String c2OpenSindsDagen(int dagen) =>
      dagen == 1 ? '1 dag' : '$dagen dagen';

  // ---- C2 detail --------------------------------------------------------
  static const c2DetailTitel = 'Klus';
  static const c2VoorWieKop = 'Voor wie';
  static const c2WaarKop = 'Waar';
  static const c2WanneerKop = 'Wanneer';
  static const c2ToelichtingKop = 'Toelichting';
  static const c2GeenToelichting = 'Geen toelichting meegegeven.';
  static const c2GeenAdres = 'Geen adres bekend.';
  static const c2GeenWijk = 'Geen wijk';
  static const c2ToegewezenKop = 'Toegewezen aan';
  static const c2DetailLadenMislukt = 'Deze klus kon niet worden geladen';

  // Koppelen
  static const c2Koppelen = 'Koppelen';
  static const c2KoppelenTitel = 'Wie doet deze klus';
  static const c2ZoekLabel = 'Zoek op naam';
  static const c2GeenKandidaten = 'Geen goedgekeurde jongeren gevonden';
  static const c2GeenKandidatenUitleg =
      'Pas het zoekwoord aan, of keur eerst een jongere goed in het beheerpaneel.';
  static const c2KandidatenLadenMislukt =
      'De jongeren konden niet worden geladen';
  static String c2KandidaatKlussen(int aantal) =>
      aantal == 1 ? '1 klus gedaan' : '$aantal klussen gedaan';
  static const c2KandidaatGeenWijk = 'Geen werkgebied ingesteld';
  static const c2BevestigTitel = 'Koppelen bevestigen';
  static String c2BevestigVraag(String naam) =>
      'Zet deze klus op naam van $naam?';
  static String c2AndereWijkWaarschuwing(String jongereWijk, String klusWijk) =>
      'Let op: $jongereWijk is een andere wijk dan $klusWijk. '
      'Handmatig koppelen mag over de wijkgrens, maar de jongere moet er wel heen kunnen.';
  static const c2AndereWijkKort = 'Andere wijk';
  static const c2BevestigKoppelen = 'Ja, koppelen';
  static String c2Gekoppeld(String naam) => 'De klus staat nu op naam van $naam.';
  static const c2KoppelenMislukt = 'Koppelen lukte niet';
  static const c2KoppelenBezet =
      'Deze klus is niet meer open; iemand anders was eerder.';
  static const c2KoppelenNietGoedgekeurd =
      'Deze jongere is nog niet goedgekeurd en kan geen klussen doen.';
  static const c2KoppelenGeenJongere = 'Deze gebruiker is geen jongere.';
  static const c2KoppelenGeenToegang =
      'Alleen een coordinator kan een klus koppelen.';
  static const c2KoppelenNietGevonden = 'Deze klus bestaat niet meer.';

  // Vrijgeven
  static const c2Vrijgeven = 'Vrijgeven';
  static const c2VrijgevenTitel = 'Klus vrijgeven';
  static String c2VrijgevenVraag(String naam) =>
      'Haal $naam van deze klus? De klus komt dan weer op open te staan.';
  static const c2VrijgevenRedenLabel = 'Reden';
  static const c2VrijgevenRedenHulp =
      'Waarom gaat deze klus terug naar open? Dit komt in het logboek.';
  static const c2VrijgevenRedenLeeg = 'Vul eerst een reden in.';
  static const c2BevestigVrijgeven = 'Ja, vrijgeven';
  static const c2Vrijgegeven =
      'De klus staat weer open. Je kunt hem nu opnieuw koppelen.';
  static const c2VrijgevenMislukt = 'Vrijgeven lukte niet';
  static const c2VrijgevenNietMogelijk =
      'Deze klus staat niet op geaccepteerd of onderweg en kan niet worden vrijgegeven.';
}
