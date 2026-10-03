// Schermteksten van klussen vinden en accepteren (M5, J11-J14) en de
// tabbalk van de helper. Eigen bestand naast teksten_nl.dart en
// teksten_jongere_nl.dart; nergens een losse string in een widget.

abstract final class TekstenKlussenNl {
  // Tabbalk helper
  static const tabKlussen = 'Klussen';
  static const tabMijnKlussen = 'Mijn klussen';
  static const tabProfiel = 'Profiel';
  static const tabInstellingen = 'Instellingen';
  static const tabbalkLabel = 'Hoofdmenu';

  // J11 Home: klussen in de buurt
  static const j11Titel = 'Klussen in de buurt';
  static const weergaveLijst = 'Lijst';
  static const weergaveKaart = 'Kaart';
  static const weergaveLabel = 'Weergave';
  static const filterKlustype = 'Soort klus';
  static const filterDagdeel = 'Dagdeel';
  static const filterWissen = 'Filters wissen';
  static const dagdeelOchtend = 'Ochtend';
  static const dagdeelMiddag = 'Middag';
  static const dagdeelAvond = 'Avond';
  static const j11Leeg = 'Nog geen klussen in je buurt';
  static const j11LeegUitleg =
      'Zodra een buurtbewoner hulp vraagt in jouw wijk, zie je de klus hier. '
      'Trek de lijst omlaag om te verversen.';
  static const j11LeegGefilterd = 'Geen klussen met deze filters';
  static const j11LeegGefilterdUitleg =
      'Kies een andere soort of een ander dagdeel, of wis de filters.';
  static const j11LadenMislukt = 'De klussen konden niet worden geladen.';
  static const j11Verversen = 'Verversen';
  static const j11Vernieuwd = 'Lijst is bijgewerkt.';
  static String j11Aantal(int n) => n == 1 ? '1 klus' : '$n klussen';
  static String j11BuitenStraal(int n, int km) => n == 1
      ? '1 klus ligt buiten je straal van $km km'
      : '$n klussen liggen buiten je straal van $km km';

  // Klus-tegel
  static const zonderLocatie = 'Locatie onbekend';
  static const buurtbewoner = 'Een buurtbewoner';
  static String afstandKm(String km) => 'ca. $km km';
  static String afstandMeter(int m) => 'ca. $m m';
  static String vergoeding(String euro) => 'Je verdient $euro';

  /// Antwoord Ibrahim 4 okt: zolang de vergoeding 0 is (prijzen komen in
  /// B7) ziet de helper dit in plaats van "€ 0,00".
  static const vergoedingVolgt = 'Vergoeding volgt';
  static String klusTegelSemantiek({
    required String soort,
    required String wanneer,
    required String afstand,
    required String vergoeding,
  }) => '$soort, $wanneer, $afstand, $vergoeding';

  // J12 Kaart
  static const j12Titel = 'Klussen op de kaart';
  static const j12KaartLabel = 'Kaart met klussen in je wijk';
  static String j12ZonderLocatie(int n) =>
      n == 1 ? '1 zonder locatie' : '$n zonder locatie';
  static String j12ZonderLocatieSemantiek(int n) => n == 1
      ? '1 klus zonder locatie, bekijk in de lijst'
      : '$n klussen zonder locatie, bekijk in de lijst';
  static const j12Leeg = 'Geen klussen om op de kaart te zetten';
  static const j12LeegUitleg =
      'Klussen zonder bekende locatie staan alleen in de lijst.';
  static String j12Marker(String soort) => 'Klus: $soort. Tik voor details.';

  // J13 Klusdetail
  static const j13Titel = 'Klus';
  static const j13WatKop = 'Wat';
  static const j13WanneerKop = 'Wanneer';
  static const j13WaarKop = 'Waar';
  static const j13VoorWieKop = 'Voor wie';
  static const j13VergoedingKop = 'Vergoeding';
  static const j13ToelichtingKop = 'Toelichting';
  static const j13GeenToelichting = 'Geen toelichting.';
  static const j13AdresNaAccepteren =
      'Het adres zie je zodra je de klus hebt aangenomen.';
  static const j13NaamNaAccepteren =
      'Naam en foto zie je zodra je de klus hebt aangenomen.';
  static String j13Wijk(String wijk) => 'Wijk: $wijk';
  static const j13Aannemen = 'Klus aannemen';
  static const j13Aangenomen = 'Je hebt deze klus aangenomen.';
  static const j13AangenomenUitleg =
      'De klus staat nu bij Mijn klussen. Op de dag zelf zet je hier stap '
      'voor stap door: op weg, aangekomen, klaar.';
  static const j13NaarMijnKlussen = 'Naar mijn klussen';
  static const j13Bezet = 'Deze klus is net door iemand anders aangenomen.';
  static const j13GeenToegang =
      'Je kunt deze klus niet aannemen. Controleer je aanmelding en je '
      'werkgebied.';
  static const j13NietGevonden = 'Deze klus bestaat niet meer.';
  static const j13LadenMislukt = 'De klus kon niet worden geladen.';
  static const j13StatusLabel = 'Status';
  static String j13Duur(int minuten) => 'ongeveer $minuten minuten';

  // J14 Mijn klussen
  static const j14Titel = 'Mijn klussen';
  static const j14TabVandaag = 'Vandaag';
  static const j14TabGepland = 'Gepland';
  static const j14TabHistorie = 'Historie';
  static const j14TabbladenLabel = 'Mijn klussen, tabbladen';
  static const j14LeegVandaag = 'Vandaag geen klussen';
  static const j14LeegVandaagUitleg =
      'Klussen die je vandaag doet, staan hier.';
  static const j14LeegGepland = 'Niets gepland';
  static const j14LeegGeplandUitleg =
      'Neem een klus aan in de buurt; hij komt dan hier te staan.';
  static const j14LeegHistorie = 'Nog geen historie';
  static const j14LeegHistorieUitleg = 'Afgeronde klussen bewaren we hier.';
  static const j14LadenMislukt = 'Je klussen konden niet worden geladen.';

  // Statussen van een klus (hh_klussen.status), voor de pil
  static const statusConcept = 'Concept';
  static const statusOpen = 'Open';
  static const statusGeaccepteerd = 'Aangenomen';
  static const statusOnderweg = 'Onderweg';
  static const statusBezig = 'Bezig';
  static const statusAfgerond = 'Afgerond';
  static const statusGeannuleerd = 'Geannuleerd';
  static const statusProbleem = 'Probleem';
  static String statusSemantiek(String naam) => 'Status: $naam';

  // Wanneer in gewone taal
  static const vandaag = 'vandaag';
  static const morgen = 'morgen';
  static const weekdagen = [
    'maandag',
    'dinsdag',
    'woensdag',
    'donderdag',
    'vrijdag',
    'zaterdag',
    'zondag',
  ];
  static const maanden = [
    'januari',
    'februari',
    'maart',
    'april',
    'mei',
    'juni',
    'juli',
    'augustus',
    'september',
    'oktober',
    'november',
    'december',
  ];
  static String wanneerMetTijd(String dag, String van, String tot) =>
      '$dag van $van tot $tot';
  static String wanneerZonderEind(String dag, String van) => '$dag om $van';
}
