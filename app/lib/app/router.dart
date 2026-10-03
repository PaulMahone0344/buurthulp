import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/coordinator/coordinator_guard.dart';
import '../features/coordinator/coordinator_routes.dart';
import '../features/coordinator/screen/coordinator_stub_screen.dart';
import '../features/familie/familie_routes.dart';
import '../features/familie/screen/familie_stub_screen.dart';
import '../features/hulpvrager/beoordelen/beoordelen_routes.dart';
import '../features/hulpvrager/hulpvrager_routes.dart';
import '../features/hulpvrager/provider/hulpvrager_providers.dart'
    show klokProvider;
import '../features/hulpvrager/screen/hulpvrager_stub_screen.dart';
import '../features/hulpvrager/status/status_routes.dart';
import '../features/hulpvrager/veiligheid/veiligheid_routes.dart';
import '../features/jongere/jongere_routes.dart';
import '../features/jongere/klussen/klussen_routes.dart';
import '../features/jongere/provider/screening_providers.dart';
import '../features/jongere/reputatie/reputatie_routes.dart';
import '../features/jongere/screen/jongere_stub_screen.dart';
import '../features/jongere/screening_guard.dart';
import '../features/jongere/uitvoeren/uitvoeren_routes.dart';
import '../features/meldingen/meldingen_routes.dart';
import '../features/toegang/model/sessie_state.dart';
import '../features/toegang/provider/sessie_providers.dart';
import '../features/toegang/screen/bevestig_email_screen.dart';
import '../features/toegang/screen/hulp_screen.dart';
import '../features/toegang/screen/inloggen_screen.dart';
import '../features/toegang/screen/instellingen_screen.dart';
import '../features/toegang/screen/registreren_screen.dart';
import '../features/toegang/screen/splash_screen.dart';
import '../features/toegang/screen/wachtwoord_vergeten_screen.dart';
import '../features/toegang/screen/welkom_screen.dart';
import 'paden.dart';
import 'screens/dev_screen.dart';
import '../design/components/hh_tabbalk.dart';

/// De guard. Sessie onbekend: iedereen blijft op de splash. Uitgelogd:
/// alleen de toegangsschermen, anders naar G2 (of G3 na een verlopen
/// sessie). Ingelogd: nooit meer op een toegangsscherm, altijd op de
/// eigen rolroute; direct na registreren eerst G5.
@visibleForTesting
String? toegangRedirect(SessieState sessie, String locatie) {
  if (kDebugMode && locatie == HhPaden.dev) return null;

  return switch (sessie) {
    SessieOnbekend() => locatie == HhPaden.splash ? null : HhPaden.splash,
    SessieBezig() => null,
    SessieUitgelogd(:final reden) => switch (locatie) {
      _ when HhPaden.zonderSessie.contains(locatie) => null,
      _ when reden == UitlogReden.sessieVerlopen => HhPaden.inloggen,
      _ => HhPaden.welkom,
    },
    SessieIngelogd(:final gebruiker) => switch (locatie) {
      HhPaden.registreren => HhPaden.bevestigEmail,
      _ when HhPaden.alleenUitgelogd.contains(locatie) => gebruiker.rol.pad,
      _
          when HhPaden.rolPaden.contains(locatie) &&
              locatie != gebruiker.rol.pad =>
        gebruiker.rol.pad,
      _ => null,
    },
  };
}

/// Notifieert go_router zodra de sessie verandert, zodat de guard
/// opnieuw wordt bekeken zonder de router (en de navigatiestapel) te
/// herbouwen.
class _SessieListenable extends ChangeNotifier {
  _SessieListenable(Ref ref) {
    ref.listen(sessieControllerProvider, (vorige, nieuwe) => notifyListeners());
    // M3: de screening-guard kijkt naar het profiel van de jongere.
    ref.listen(
      screeningControllerProvider,
      (vorige, nieuwe) => notifyListeners(),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _SessieListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: HhPaden.splash,
    refreshListenable: listenable,
    redirect: (context, state) =>
        toegangRedirect(
          ref.read(sessieControllerProvider),
          state.matchedLocation,
        ) ??
        // M3/B2: helper die nog niet verstuurde of is afgewezen gaat naar J9.
        screeningRedirect(
          ref.read(sessieControllerProvider),
          ref.read(screeningControllerProvider),
          state.matchedLocation,
          klok: ref.read(klokProvider),
        ) ??
        // M10: alleen de coordinator komt op de paden onder /coordinator.
        coordinatorRedirect(
          ref.read(sessieControllerProvider),
          state.matchedLocation,
        ),
    routes: [
      GoRoute(
        path: HhPaden.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: HhPaden.welkom,
        builder: (context, state) => const WelkomScreen(),
      ),
      GoRoute(
        path: HhPaden.inloggen,
        builder: (context, state) => const InloggenScreen(),
      ),
      GoRoute(
        path: HhPaden.registreren,
        builder: (context, state) => const RegistrerenScreen(),
      ),
      GoRoute(
        path: HhPaden.bevestigEmail,
        builder: (context, state) => const BevestigEmailScreen(),
      ),
      GoRoute(
        path: HhPaden.wachtwoordVergeten,
        builder: (context, state) => const WachtwoordVergetenScreen(),
      ),
      GoRoute(
        path: HhPaden.instellingen,
        builder: (context, state) => const InstellingenScreen(),
      ),
      GoRoute(
        path: HhPaden.hulp,
        builder: (context, state) => const HulpScreen(),
      ),
      GoRoute(
        path: HhPaden.hulpvrager,
        pageBuilder: (context, state) =>
            hhTabPagina(state, const HulpvragerStubScreen()),
      ),
      GoRoute(
        path: HhPaden.jongere,
        pageBuilder: (context, state) =>
            hhTabPagina(state, const JongereStubScreen()),
      ),
      GoRoute(
        path: HhPaden.familie,
        builder: (context, state) => const FamilieStubScreen(),
      ),
      GoRoute(
        path: HhPaden.coordinator,
        pageBuilder: (context, state) =>
            hhTabPagina(state, const CoordinatorStubScreen()),
      ),
      ...hulpvragerRoutes(),
      ...jongereRoutes(),
      ...klussenRoutes(),
      ...uitvoerenRoutes(),
      ...statusRoutes(),
      ...coordinatorRoutes(),
      ...reputatieRoutes(),
      ...beoordelenRoutes(),
      ...meldingenRoutes(),
      ...veiligheidRoutes(),
      ...familieRoutes(),
      // Alleen in debug-builds; een release kent dit pad niet.
      if (kDebugMode)
        GoRoute(
          path: HhPaden.dev,
          builder: (context, state) => const DevScreen(),
        ),
    ],
  );
});
