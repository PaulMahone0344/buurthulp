import 'package:go_router/go_router.dart';

import 'ouder/screen/ouder_screen.dart';
import 'screen/mijn_adres_screen.dart';
import 'paden_jongere.dart';
import 'screen/aanmelding_binnen_screen.dart';
import 'screen/screening_foto_screen.dart';
import 'screen/screening_over_mij_screen.dart';
import 'screen/screening_overzicht_screen.dart';
import 'screen/screening_vog_screen.dart';

/// Routes van het aanmelden van de helper (B2: ID-foto, VOG, over mij, het
/// overzicht en "Aanmelding binnen"). De landing /jongere staat in
/// router.dart; deze lijst wordt daar met een spread toegevoegd.
List<RouteBase> jongereRoutes() => [
  GoRoute(
    path: HhPadenJongere.identiteit,
    builder: (context, state) => const ScreeningIdentiteitScreen(),
  ),
  GoRoute(
    path: HhPadenJongere.vog,
    builder: (context, state) => const ScreeningVogScreen(),
  ),
  GoRoute(
    path: HhPadenJongere.overMij,
    builder: (context, state) => const ScreeningOverMijScreen(),
  ),
  GoRoute(
    path: HhPadenJongere.overzicht,
    builder: (context, state) => const ScreeningOverzichtScreen(),
  ),
  GoRoute(
    path: HhPadenJongere.binnen,
    builder: (context, state) => const AanmeldingBinnenScreen(),
  ),
  // ADRES: "Mijn adres" (gele balk "Vul je adres aan").
  GoRoute(
    path: HhPadenJongere.adres,
    builder: (context, state) => const MijnAdresScreen(),
  ),
  // B3: stap "Ouder" (helper onder 18).
  GoRoute(
    path: HhPadenOuder.ouder,
    builder: (context, state) => const OuderScreen(),
  ),
];
