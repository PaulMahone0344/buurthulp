// Schermteksten van beoordelen en reputatie (M7: J17, J19, O9) en van de
// aanhaakpunten in J14, J15, O7 en O8. Eigen bestand naast
// teksten_uitvoeren_nl.dart; nergens een losse string in een widget.
//
// De ouderenteksten (O9) staan in gewone, hele zinnen met "u": geen cijfers,
// geen gemiddelden, geen aantallen (ouderenregel). De jongere krijgt "je".

abstract final class TekstenBeoordelenNl {
  // ---- Sterren in woorden (O9, J17): nooit een cijfer ----------------
  static const woordSlecht = 'Slecht';
  static const woordNietGoed = 'Niet goed';
  static const woordGaatWel = 'Gaat wel';
  static const woordGoed = 'Goed';
  static const woordHeelGoed = 'Heel goed';
  static const sterrenKiezerLabel = 'Aantal sterren';

  /// Voor de schermlezer bij de jongere: "4 sterren, Goed".
  static String sterrenSemantiek(int sterren, String woord) =>
      sterren == 1 ? '1 ster, $woord' : '$sterren sterren, $woord';

  // ---- J17 Beoordeling geven (jongere) ------------------------------
  static const j17Titel = 'Beoordeling geven';
  static String j17Vraag(String naam) => 'Hoe was het om $naam te helpen?';
  static const j17VraagZonderNaam = 'Hoe was het om te helpen?';
  static const j17SterrenKop = 'Sterren';
  static const j17TekstLabel = 'Wil je nog iets kwijt? (mag leeg blijven)';
  static const j17TekstHulp = 'Hooguit 500 tekens. De oudere kan dit lezen.';
  static const j17Versturen = 'Versturen';
  static const j17Opslaan = 'Wijziging opslaan';
  static const j17BestaandUitleg =
      'Je hebt deze klus al beoordeeld. Je kunt je beoordeling hier '
      'aanpassen.';
  static const j17Gelukt = 'Bedankt voor je beoordeling.';
  static const j17Gewijzigd = 'Je beoordeling is aangepast.';
  static const j17AlGegeven = 'Je hebt al een beoordeling gegeven.';
  static const j17NaarMijnKlussen = 'Naar mijn klussen';
  static const j17LadenMislukt = 'Deze klus kon niet worden geladen.';

  // ---- Gedeeld: invoer en weigeringen -------------------------------
  static const kiesSterren = 'Kies eerst hoeveel sterren je geeft.';
  static const tekstTeLang = 'Je tekst is langer dan 500 tekens.';
  static const nietAfgerond = 'Beoordelen kan pas als de klus klaar is.';
  static const nietAfgerondUitleg =
      'Staat de klus op afgerond, dan kun je hier sterren geven.';
  static const nietToegestaan = 'Deze beoordeling kan niet worden opgeslagen.';
  static const nietGevonden = 'Deze beoordeling bestaat niet meer.';

  // ---- J19 Mijn profiel en reputatie (jongere) ----------------------
  static const j19Titel = 'Mijn profiel';
  static const j19ReputatieKop = 'Mijn reputatie';
  static String j19Gemiddeld(String sterren) => '$sterren van de 5 sterren';
  static const j19GemiddeldUitleg = 'Het gemiddelde van al je beoordelingen.';
  static const j19NogGeenSterren = 'Nog geen beoordelingen';
  static const j19NogGeenSterrenUitleg =
      'Na je eerste afgeronde klus kan de oudere je sterren geven.';
  static String j19Klussen(int aantal) =>
      aantal == 1 ? '1 klus gedaan' : '$aantal klussen gedaan';
  static const j19LaatsteKop = 'Laatste beoordelingen';
  static const j19GeenTeksten = 'Nog geen beoordelingen met tekst.';
  static const j19Screening = 'Mijn screening';
  static const j19LadenMislukt = 'Je reputatie kon niet worden geladen.';

  // ---- Aanhaakpunten jongere (J14, J15) ------------------------------
  static const j14NogBeoordelen = 'Nog beoordelen';
  static const j15Beoordelen = 'Beoordeling geven';
  static const j15BeoordelingWijzigen = 'Beoordeling wijzigen';

  // ---- O9 Beoordeling geven (oudere) --------------------------------
  static const o9Titel = 'Hoe ging het?';
  static String o9DuimVraag(String naam) => 'Hoe ging het met $naam?';
  static const o9DuimVraagZonderNaam = 'Hoe ging het?';
  static const o9DuimOmhoog = 'Goed';
  static const o9DuimOmhoogSemantiek = 'Het ging goed';
  static const o9DuimOmlaag = 'Niet goed';
  static const o9DuimOmlaagSemantiek = 'Het ging niet goed';
  static String o9SterrenVraag(String naam) => 'Hoeveel sterren geeft u $naam?';
  static const o9SterrenVraagZonderNaam = 'Hoeveel sterren geeft u?';
  static const o9SterrenUitleg = 'Tik op een ster om het te veranderen.';
  static const o9TekstLabel = 'Wilt u nog iets zeggen? (mag leeg blijven)';
  static const o9Versturen = 'Versturen';
  static const o9Opslaan = 'Opslaan';
  static const o9BestaandUitleg =
      'U heeft al een beoordeling gegeven. U kunt die hier aanpassen.';
  static const o9Bedankt = 'Dank u wel!';
  static const o9BedanktUitleg = 'Uw beoordeling is bewaard.';
  static const o9NaarHulpvragen = 'Naar mijn hulpvragen';
  static const o9AlGegeven = 'U heeft al een beoordeling gegeven.';
  static const o9KiesSterren = 'Tik eerst op een ster.';
  static const o9TekstTeLang = 'Uw tekst is te lang. Maak hem wat korter.';
  static const o9NietAfgerond = 'U kunt pas iets zeggen als de hulp klaar is.';
  static const o9NietAfgerondUitleg =
      'Als de hulp klaar is, kunt u hier zeggen hoe het ging.';
  static const o9LadenMislukt = 'Deze hulpvraag kon niet worden geladen.';

  // ---- Aanhaakpunten oudere (O7, O8) --------------------------------
  static const o7HoeGingHet = 'Hoe ging het?';
  static String o7HoeGingHetSemantiek(String naam) =>
      'Vertel hoe het ging met $naam';
}
