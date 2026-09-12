import 'package:go_router/go_router.dart';

import 'paden_jongere.dart';
import 'screen/screening_beschikbaarheid_screen.dart';
import 'screen/screening_foto_screen.dart';
import 'screen/screening_iban_screen.dart';
import 'screen/screening_klussoorten_screen.dart';
import 'screen/screening_overzicht_screen.dart';
import 'screen/screening_profiel_screen.dart';
import 'screen/screening_vog_screen.dart';
import 'screen/screening_werkgebied_screen.dart';

/// Routes van de jongere (M3: screening J1-J9). De landing /jongere staat
/// in router.dart; deze lijst wordt daar met een spread toegevoegd.
List<RouteBase> jongereRoutes() => [
  GoRoute(
    path: HhPadenJongere.profiel,
    builder: (context, state) => const ScreeningProfielScreen(),
  ),
  GoRoute(
    path: HhPadenJongere.identiteit,
    builder: (context, state) => const ScreeningIdentiteitScreen(),
  ),
  GoRoute(
    path: HhPadenJongere.selfie,
    builder: (context, state) => const ScreeningSelfieScreen(),
  ),
  GoRoute(
    path: HhPadenJongere.vog,
    builder: (context, state) => const ScreeningVogScreen(),
  ),
  GoRoute(
    path: HhPadenJongere.iban,
    builder: (context, state) => const ScreeningIbanScreen(),
  ),
  GoRoute(
    path: HhPadenJongere.werkgebied,
    builder: (context, state) => const ScreeningWerkgebiedScreen(),
  ),
  GoRoute(
    path: HhPadenJongere.beschikbaarheid,
    builder: (context, state) => const ScreeningBeschikbaarheidScreen(),
  ),
  GoRoute(
    path: HhPadenJongere.klussoorten,
    builder: (context, state) => const ScreeningKlussoortenScreen(),
  ),
  GoRoute(
    path: HhPadenJongere.overzicht,
    builder: (context, state) => const ScreeningOverzichtScreen(),
  ),
];
