// Schermteksten van het aanmelden van de helper (M3, ingekort in B2: ID-foto,
// VOG en "Je aanmelding"). Eigen bestand naast teksten_nl.dart; nergens een
// losse string in een widget. Nieuwe B2-teksten: teksten_aanmelden_nl.dart.

abstract final class TekstenJongereNl {
  // Statussen (hh_profielen.verificatiestatus)
  static const statusNieuw = 'Nog niet ingediend';
  static const statusInBehandeling = 'In behandeling';
  static const statusGoedgekeurd = 'Goedgekeurd';
  static const statusAfgewezen = 'Afgewezen';
  static String statusLabel(String naam) => 'Status: $naam';

  // Gedeeld in de stappen
  static const stapAf = 'Af';
  static const stapOpen = 'Nog doen';
  static const opslaanEnVerder = 'Opslaan en verder';
  static const opgeslagen = 'Opgeslagen.';
  static const ladenMislukt = 'Je gegevens konden niet worden geladen.';
  static const fotoMaken = 'Foto maken';
  static const fotoKiezen = 'Kies uit galerij';
  static const fotoStaatKlaar = 'Je foto is opgeslagen.';
  static const fotoNogGeen = 'Nog geen foto.';
  static const fotoBezig = 'Foto wordt verstuurd';
  static const fotoCameraLuktNiet =
      'De camera is op dit toestel niet beschikbaar.';
  static const fotoKiezenLuktNiet = 'Het kiezen van een foto is mislukt.';

  // J2 Identiteitscontrole
  static const j2Titel = 'Identiteitscontrole';
  static const j2Uitleg =
      'Maak een foto van je identiteitskaart, paspoort of rijbewijs. '
      'De meldkamer controleert je naam en geboortedatum.';
  static const j2WelZichtbaar =
      'Wel zichtbaar: je naam, je geboortedatum en je pasfoto.';
  static const j2NietZichtbaar =
      'Niet zichtbaar: je BSN. Dek het af met je vinger of een stukje '
      'papier voordat je de foto maakt.';
  static const j2Vertrouwelijk =
      'Alleen jij en de meldkamer kunnen deze foto zien. Na de controle '
      'wissen we hem.';

  // J4 VOG (alleen 18+)
  static const j4Titel = 'VOG';
  static const j4Aanvragen = 'VOG aanvragen';
  static const j4AanvragenLuktNiet =
      'De website kon niet worden geopend. Ga zelf naar justis.nl.';
  static const j4HebAangevraagd = 'Ik heb aangevraagd';
  static String j4AangevraagdOp(String datum) => 'Aangevraagd op $datum.';
  static const j4StatusKop = 'Status van je VOG';

  // J9 Je aanmelding
  static const j9Titel = 'Je aanmelding';
  static const j9StappenKop = 'Je stappen';
  static const j9StatusKop = 'Status';
  static const j9Ingediend = 'Je aanmelding is verstuurd.';
  static const j9WachtTekst =
      'De meldkamer kijkt je aanmelding na, meestal binnen 1 dag. Je krijgt '
      'een melding als je kunt beginnen.';
  static const j9AfgewezenTekst =
      'Je aanmelding is helaas niet goedgekeurd. Bel ons als je wilt weten '
      'waarom, of als je denkt dat er iets misgaat.';
  static const j9BelOns = 'Bel ons';
  static const j9GoedgekeurdTekst =
      'Je aanmelding is goedgekeurd. Op de start zie je of er nog iets '
      'ontbreekt.';
  static const j9Vernieuwen = 'Status vernieuwen';
  static const j9VerificatieLabel = 'Aanmelding';
}
