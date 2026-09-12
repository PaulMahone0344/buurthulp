import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/coordinator/screen/coordinator_stub_screen.dart';
import '../features/familie/screen/familie_stub_screen.dart';
import '../features/hulpvrager/screen/hulpvrager_stub_screen.dart';
import '../features/jongere/screen/jongere_stub_screen.dart';
import 'screens/rolwissel_screen.dart';

/// TIJDELIJK: het rolwisselscherm op / verdwijnt zodra splash en inloggen
/// (G1-G3) er zijn. Dan wordt / het opstartpad.
const rolwisselPad = '/';
const hulpvragerPad = '/hulpvrager';
const jongerePad = '/jongere';
const familiePad = '/familie';
const coordinatorPad = '/coordinator';

/// Zelfde opzet als ObyCom: de router als provider, zodat een latere
/// auth-redirect via `ref` bij de sessie kan zonder de router te herbouwen.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: rolwisselPad,
    routes: [
      GoRoute(
        path: rolwisselPad,
        builder: (context, state) => const RolwisselScreen(),
      ),
      GoRoute(
        path: hulpvragerPad,
        builder: (context, state) => const HulpvragerStubScreen(),
      ),
      GoRoute(
        path: jongerePad,
        builder: (context, state) => const JongereStubScreen(),
      ),
      GoRoute(
        path: familiePad,
        builder: (context, state) => const FamilieStubScreen(),
      ),
      GoRoute(
        path: coordinatorPad,
        builder: (context, state) => const CoordinatorStubScreen(),
      ),
    ],
  );
});
