import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../paden_familie.dart';
import 'familie_home_screen.dart';

/// Landing voor de rol familie (/familie). Sinds M9 is dat F1; de naam
/// blijft, zodat de router en de M2-tests ongemoeid blijven (zelfde aanpak
/// als HulpvragerStubScreen).
class FamilieStubScreen extends StatelessWidget {
  const FamilieStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var toonLijst = false;
    try {
      toonLijst =
          GoRouterState.of(
            context,
          ).uri.queryParameters[HhPadenFamilie.lijstParameter] ==
          '1';
    } on Object {
      // Buiten go_router (losse widgettest): gewoon de landing.
      toonLijst = false;
    }
    return FamilieHomeScreen(toonLijst: toonLijst);
  }
}
