// Schermteksten van klus uitvoeren (M6: J15, J16) en van de bewoner die
// zijn hulpvraag volgt (O7, O8). Eigen bestand naast teksten_nl.dart,
// teksten_klussen_nl.dart en teksten_hulpvrager_nl.dart; nergens een losse
// string in een widget.
//
// De bewonerteksten (O7, O8) staan bewust in gewone, hele zinnen: geen
// cijfers, geen statistiek, geen jargon. Iedereen krijgt "je".

abstract final class TekstenUitvoerenNl {
  // ---- J13 aannemen: bevestigen en doorgaan (M5 OPEN-PUNT 80 en 81) --
  static const j13BevestigVraag = 'Deze klus aannemen?';
  static const j13BevestigUitleg =
      'Je spreekt af dat je komt. Lukt het toch niet, dan kun je de klus '
      'teruggeven met een reden.';
  static const j13BevestigJa = 'Ja, ik neem hem aan';
  static const j13Uitvoeren = 'Klus uitvoeren';

  // ---- J15 Klus uitvoeren -------------------------------------------
  static const j15Titel = 'Klus uitvoeren';
  static const j15StapbalkTitel = 'Zo ver ben je';
  static const j15StapOnderweg = 'Onderweg';
  static const j15StapAangekomen = 'Aangekomen';
  static const j15StapAfgerond = 'Afgerond';

  static const j15KnopOnderweg = 'Ik ga op weg';
  static const j15KnopAangekomen = 'Ik ben er';
  static const j15KnopAfgerond = 'Klus is klaar';

  static const j15WaarKop = 'Waar';
  static const j15VoorWieKop = 'Voor wie';
  static const j15WanneerKop = 'Wanneer';
  static const j15ContactKop = 'Contactpersoon';
  static const j15GeenAdres = 'Het adres is nog niet bekend.';

  static const j15Bellen = 'Bellen';
  static String j15BellenSemantiek(String naam) => 'Bel $naam';

  static const j15Annuleren = 'Ik kan toch niet';
  static const j15AnnulerenSemantiek =
      'Ik kan deze klus toch niet doen, geef hem terug';

  static const j15Afgerond = 'Deze klus is afgerond. Bedankt!';
  static const j15AfgerondUitleg =
      'De bewoner ziet dat je klaar bent. Je vergoeding wordt verwerkt.';
  static const j15Geannuleerd = 'Deze klus staat niet meer op jouw naam.';
  static const j15GeannuleerdUitleg =
      'Hij staat weer open voor de buurt. Kijk gerust of er een andere klus is.';
  static const j15NaarMijnKlussen = 'Naar mijn klussen';
  static const j15NaarKlussen = 'Klussen in de buurt';

  static const j15LadenMislukt = 'De klus kon niet worden geladen.';
  static const j15Vernieuwen = 'Vernieuwen';
  static const j15Vernieuwd = 'Het scherm is bijgewerkt.';
  static const j15NietVanJou = 'Deze klus staat niet op jouw naam.';
  static const j15StapNietMeer =
      'Deze stap kan nu niet meer. Het scherm is bijgewerkt.';

  static String j15Gezet(String stap) => 'Gezet op: $stap.';

  // ---- Annuleren door de helper ------------------------------------
  static const annuleerTitelJongere = 'Klus teruggeven';
  static const annuleerUitlegJongere =
      'Vertel kort waarom het niet lukt. De klus komt daarna weer vrij voor '
      'een andere strijder in de buurt.';
  static const annuleerLabelReden = 'Waarom lukt het niet?';
  static const annuleerHintReden = 'Bijvoorbeeld: ik ben ziek geworden';
  static const annuleerBevestigJongere = 'Klus teruggeven';
  static const annuleerAfbreken = 'Nee, toch niet';
  static String annuleerRedenTeKort(int min) => 'Schrijf minstens $min tekens.';
  static String annuleerRedenTeLang(int max) =>
      'Schrijf hoogstens $max tekens.';
  static const annuleerMislukt = 'Het annuleren is niet gelukt.';

  // ---- J16 Bellen ---------------------------------------------------
  static String belBevestiging(String naam) => 'Je belt $naam.';
  static const belGeenNummer =
      'Er is geen telefoonnummer bekend. Bel de meldkamer als het dringend is.';
  static const belNogNiet = 'Bellen kan zodra de klus is aangenomen.';
  static const belLuktNiet =
      'Bellen lukt niet op dit toestel. Probeer het via je telefoonapp.';

  // ---- O7 Status hulpvraag (de bewoner) ------------------------------
  static const o7Titel = 'Jouw hulpvraag';
  static const o7GeenJongere = 'We zoeken iemand voor je.';
  static const o7GeenJongereUitleg =
      'Zodra iemand je hulpvraag aanneemt, zie je hier wie er komt.';
  static String o7Aangenomen(String naam) => '$naam komt je helpen.';
  static String o7Onderweg(String naam) => '$naam is onderweg naar je.';
  static String o7Bezig(String naam) => '$naam is bij je aan het werk.';
  static String o7Afgerond(String naam) => '$naam heeft de klus gedaan.';
  static const o7Geannuleerd = 'Deze hulpvraag is gestopt.';
  static const o7GeannuleerdUitleg = 'Je kunt altijd opnieuw om hulp vragen.';
  static const o7Concept = 'Deze hulpvraag is nog niet verstuurd.';
  static const o7Probleem = 'Er is iets misgegaan. Wij bellen je.';

  static const o7WanneerKop = 'Wanneer';
  static const o7WatKop = 'Wat';
  static const o7GeenTijd = 'Nog geen tijd afgesproken.';
  static const o7Bellen = 'Bellen';
  static String o7BellenSemantiek(String naam) => 'Bel $naam';
  static const o7Annuleren = 'Hulp niet meer nodig';
  static const o7AnnulerenSemantiek = 'Ik heb deze hulp niet meer nodig';
  static const o7Vernieuwen = 'Vernieuwen';
  static const o7LadenMislukt = 'Je hulpvraag kon niet worden geladen.';
  static const o7Helper = 'Jouw strijder';

  // Feedbackronde 1 punt C: overzicht van een afgeronde klus.
  static const o7OverzichtKop = 'Overzicht';
  static const o7KlaarKop = 'Klaar';
  static const o7WaarKop = 'Waar';
  static const o7WieKop = 'Wie';
  static const o7HoelangKop = 'Hoelang';
  static const o7BedragKop = 'Bedrag';
  static const o7BetalingKop = 'Betaling';
  // Prijzen en saldo komen in B7; tot die tijd eerlijk zeggen.
  static String o7BedragVoorbeeld(String bedrag) => '$bedrag (voorbeeld)';
  static const o7BetalingLater = 'Betalen in de app komt binnenkort.';

  static const duurMinderDanMinuut = 'minder dan een minuut';
  static String duurMinuten(int n) => n == 1 ? '1 minuut' : '$n minuten';
  static String duurUren(int n) => '$n uur';
  static String duurUrenMinuten(int uren, int minuten) =>
      '${duurUren(uren)} en ${duurMinuten(minuten)}';

  // Annuleren door de bewoner: drie grote keuzes en "anders", zodat er niet
  // getypt hoeft te worden.
  static const o7AnnuleerTitel = 'Wil je de hulp stoppen?';
  static const o7AnnuleerUitleg = 'Wil je zeggen waarom? Kies een reden.';
  static const o7RedenOpgelost = 'Het is al opgelost';
  static const o7RedenAndereDag = 'Ik wil een andere dag';
  static const o7RedenNietThuis = 'Ik ben niet thuis';
  static const o7RedenAnders = 'Iets anders';
  static const o7RedenAndersLabel = 'Vertel kort waarom';
  static const o7AnnuleerBevestig = 'Ja, stop de hulpvraag';
  static const o7AnnuleerAfbreken = 'Nee, laat maar staan';
  static const o7AnnuleerGelukt = 'Je hulpvraag is gestopt.';

  // De volledige zin die naar de server gaat als de bewoner een vaste reden
  // kiest (de server eist minstens vijf tekens).
  static const o7RedenOpgelostZin = 'Het is al opgelost.';
  static const o7RedenAndereDagZin = 'Ik wil graag een andere dag.';
  static const o7RedenNietThuisZin = 'Ik ben die dag niet thuis.';

  // ---- O8 Mijn hulpvragen -------------------------------------------
  static const o8Titel = 'Mijn hulpvragen';
  static const o8TabOpen = 'Open';
  static const o8TabGepland = 'Gepland';
  static const o8TabAfgerond = 'Afgerond';
  static const o8TabbladenLabel = 'Mijn hulpvragen, drie soorten';
  static const o8LeegOpen = 'Je hebt geen open hulpvraag';
  static const o8LeegOpenUitleg = 'Vraag gerust hulp als je iets nodig hebt.';
  static const o8LeegGepland = 'Er staat nog niets gepland';
  static const o8LeegGeplandUitleg =
      'Zodra iemand je hulpvraag aanneemt, staat hij hier.';
  static const o8LeegAfgerond = 'Nog geen afgeronde hulp';
  static const o8LeegAfgerondUitleg = 'Wat klaar is, bewaren we hier voor je.';
  static const o8LadenMislukt = 'Je hulpvragen konden niet worden geladen.';
  static const o8Vernieuwen = 'Vernieuwen';
  static String o8TegelSemantiek(String wat, String wanneer, String wie) =>
      '$wat, $wanneer, $wie';
  static const o8NogNiemand = 'Nog niemand gevonden';
}
