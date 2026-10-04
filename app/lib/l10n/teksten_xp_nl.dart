// Schermteksten van B9: XP, niveaus, badges, verdiensten, beloning na een
// klus en de verklaring van inzet. Alleen voor de helper (de bewoner ziet
// alleen de niveau-pil en "Nieuw in de buurt" op KiesHelper). Nergens een
// losse string in een widget. De getallen komen van de server.

abstract final class TekstenXpNl {
  // ---- Niveau en XP -------------------------------------------------
  static const niveauKop = 'Mijn niveau';
  static String xpTotaal(int xp) => '$xp XP';
  static String niveauPil(String niveau) => 'Niveau $niveau';
  static String nogTot(int xp, String niveau) => 'Nog $xp XP tot $niveau';
  static String nogKlussen(int aantal) =>
      aantal == 1 ? 'en nog 1 klus' : 'en nog $aantal klussen';
  static String nogSterren(String sterren) => 'en gemiddeld $sterren sterren';
  static const hoogsteNiveau = 'Je hebt het hoogste niveau. Knap gedaan!';
  static String balkSemantiek(int xp, int tot, String niveau) =>
      '$xp van de $tot XP naar niveau $niveau';
  static const hoeWerktHet =
      'Je krijgt XP voor elke klus, een extra bonus als een bewoner je '
      'opnieuw kiest en voor een goede beoordeling.';

  // ---- Badges -------------------------------------------------------
  static const badgesKop = 'Badges';
  static String badgesTeller(int behaald, int totaal) => '$behaald van $totaal';
  static String behaaldOp(String datum) => 'Behaald op $datum';
  static const nogNiet = 'Nog niet behaald';
  static String badgeSemantiek(String naam, String stand) => '$naam, $stand';

  // ---- Vertrouwen ---------------------------------------------------
  static const vertrouwenKop = 'Gecontroleerd';
  static const vertrouwenLeeg =
      'Nog niets gecontroleerd. De meldkamer zet dit erbij.';
  static String sinds(String datum) => 'Sinds $datum';
  static String geldigTot(String datum) => 'Geldig tot $datum';
  static String verlopenOp(String datum) => 'Verlopen op $datum';

  // ---- Recensies ----------------------------------------------------
  static const recensiesKop = 'Recensies';
  static const recensiesLeeg = 'Nog geen recensies met tekst.';
  static String recensieVan(String voornaam, String datum) =>
      voornaam.isEmpty ? datum : '$voornaam · $datum';

  // ---- Verdiensten --------------------------------------------------
  static const verdienstenKop = 'Verdiensten';
  static const verdienstenVerwacht = 'verwacht';
  static const dezeMaand = 'Deze maand';
  static const ditJaar = 'Dit jaar';
  static const alleVerdiensten = 'Alle verdiensten';
  static const verdienstenTitel = 'Mijn verdiensten';
  static const perMaandKop = 'Per maand';
  static const perJaarKop = 'Per jaar';
  static const verdienstenLeeg = 'Nog geen klussen klaar.';
  static const verdienstenUitleg =
      'Dit is wat je met je klaar-gemelde klussen hoort te krijgen. Het '
      'echte uitbetalen komt later; dan zie je hier ook wat er is betaald.';
  static String klussenAantal(int n) => n == 1 ? '1 klus' : '$n klussen';

  // ---- Beloning (HBeloning) -----------------------------------------
  static const beloningTitel = 'Beloning';
  static String goedGedaan(String voornaam) =>
      voornaam.isEmpty ? 'Goed gedaan!' : 'Goed gedaan, $voornaam!';
  static String xpErbij(int xp) => '+$xp XP';
  static String nieuwNiveau(String niveau) => 'Je bent nu $niveau!';
  static const nieuweBadge = 'Nieuwe badge';
  static String totaalNu(String niveau, int xp) => '$niveau · $xp XP';
  static const top = 'Top!';

  // ---- Verklaring van inzet -----------------------------------------
  static const verklaringKnop = 'Verklaring van inzet';
  static const verklaringTitel = 'Verklaring van inzet';
  static const verklaringUitleg =
      'Laat zien wat je hebt gedaan, bijvoorbeeld bij een sollicitatie of op '
      'school. Wie deze verklaring krijgt, kan de code nakijken bij '
      'HeitjeHulp.';
  static String verklaringZin(String voornaam, int klussen) =>
      '$voornaam hielp buren via HeitjeHulp met ${klussenAantal(klussen)}.';
  static String uren(String uren) => 'Ongeveer $uren uur';
  static String periode(String van, String tot) =>
      van == tot ? 'Op $van' : 'Van $van tot $tot';
  static String niveauRegel(String niveau) => 'Niveau: $niveau';
  static const controlecodeKop = 'Controlecode';
  static const openOpWebsite = 'Open om te printen of te delen';
  static const openMislukt =
      'De pagina ging niet open. Schrijf de code over of maak een '
      'schermafbeelding.';
  static const verklaringMislukt = 'De verklaring lukte nu niet.';

  // ---- Laden --------------------------------------------------------
  static const ladenMislukt = 'Je XP en badges konden niet worden geladen.';

  // ---- Start (helper) -----------------------------------------------
  static String startRegel(String niveau, int xp) => '$niveau · $xp XP';
  static const startNaarProfiel = 'Bekijk je badges';
}
