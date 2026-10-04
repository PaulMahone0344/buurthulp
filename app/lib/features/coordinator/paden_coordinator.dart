import '../../app/paden.dart';

/// Routepaden van de coordinator in de app (M10, C1 en C2) en van zijn
/// tabbalk. C1 zit op de landing /coordinator (HhPaden.coordinator).
abstract final class HhPadenCoordinator {
  /// C1-detail, met het incident-id erachter.
  static const incident = '${HhPaden.coordinator}/melding';
  static const incidentPatroon = '$incident/:id';
  static String incidentDetail(String id) => '$incident/$id';

  /// C2: de lijst met open klussen.
  static const klussen = '${HhPaden.coordinator}/klussen';

  /// C2-detail, met het klus-id erachter.
  static const klus = '${HhPaden.coordinator}/klus';
  static const klusPatroon = '$klus/:id';
  static String klusDetail(String id) => '$klus/$id';

  /// B11: tab "Te doen" (bellen, helpers en klussen keuren, ouder vrijgeven).
  static const teDoen = '${HhPaden.coordinator}/te-doen';

  /// Tab Instellingen: G7 met de tabbalk van de coordinator.
  static const instellingen = '${HhPaden.coordinator}/instellingen';

  /// Elk M10-pad onder de landing: hoort bij de rol coordinator (guard).
  static bool isCoordinatorPad(String locatie) =>
      locatie == klussen ||
      locatie == teDoen ||
      locatie == instellingen ||
      locatie.startsWith('$incident/') ||
      locatie.startsWith('$klus/');
}
