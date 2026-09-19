import '../toegang/model/hh_rol.dart';
import '../toegang/model/sessie_state.dart';
import 'paden_coordinator.dart';

/// Uitbreiding van de router-guard (M10). De bestaande rol-guard in
/// router.dart bewaakt alleen de vier landingspaden; de paden ONDER
/// /coordinator (C1-detail, C2, C2-detail, instellingen) horen daar niet
/// bij. Deze regel stuurt iedereen die geen coordinator is vanaf zo'n pad
/// terug naar zijn eigen rolroute.
///
/// Uitgelogd zegt deze guard niets: [toegangRedirect] heeft de bezoeker dan
/// al naar G2 of G3 gestuurd.
String? coordinatorRedirect(SessieState sessie, String locatie) {
  if (!HhPadenCoordinator.isCoordinatorPad(locatie)) return null;
  if (sessie is! SessieIngelogd) return null;
  final gebruiker = sessie.gebruiker;
  return gebruiker.rol == HhRol.coordinator ? null : gebruiker.rol.pad;
}
