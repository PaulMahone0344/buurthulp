// M12 — loopt elk vast scherm van de app langs per rol, op 320, 390 en 430
// breed en met tekstschaal 1.0 en 2.0, en meldt elke layoutfout (overflow,
// afgekapte rij, onbegrensde hoogte). Vervangt de schermcheck van het
// overgeslagen M11.
//
// De test faalt pas aan het eind, met de volledige lijst, zodat één run
// laat zien waar het misgaat.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/app.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/app/router.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/features/coordinator/paden_coordinator.dart';
import 'package:heitjehulp_app/features/familie/paden_familie.dart';
import 'package:heitjehulp_app/features/hulpvrager/paden_hulpvrager.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/paden_status.dart';
import 'package:heitjehulp_app/features/hulpvrager/veiligheid/paden_veiligheid.dart';
import 'package:heitjehulp_app/features/jongere/klussen/paden_klussen.dart';
import 'package:heitjehulp_app/features/jongere/paden_jongere.dart';
import 'package:heitjehulp_app/features/meldingen/paden_meldingen.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';

import '../support/hh_toegang_wikkel.dart';

const breedtes = [320.0, 390.0, 430.0];
const hoogte = 760.0;
const tekstschalen = [1.0, 2.0];

final schermenPerRol = <HhRol?, List<String>>{
  null: [
    HhPaden.welkom,
    HhPaden.inloggen,
    HhPaden.registreren,
    HhPaden.wachtwoordVergeten,
    HhPaden.hulp,
  ],
  HhRol.hulpvrager: [
    HhPaden.hulpvrager,
    HhPadenHulpvrager.hulpVragenWat,
    HhPadenHulpvrager.hulpVragenWanneer,
    HhPadenHulpvrager.hulpVragenWaar,
    HhPadenHulpvrager.hulpVragenBevestigen,
    HhPadenHulpvrager.hulpVragenVerstuurd,
    HhPadenHulpvrager.gegevens,
    HhPadenStatus.hulpvragen,
    HhPadenVeiligheid.belOns,
    HhPadenVeiligheid.probleem,
    HhPadenMeldingen.overzicht,
    HhPaden.instellingen,
  ],
  HhRol.jongere: [
    HhPaden.jongere,
    HhPadenJongere.overzicht,
    HhPadenJongere.profiel,
    HhPadenJongere.identiteit,
    HhPadenJongere.selfie,
    HhPadenJongere.vog,
    HhPadenJongere.iban,
    HhPadenJongere.werkgebied,
    HhPadenJongere.beschikbaarheid,
    HhPadenJongere.klussoorten,
    HhPadenKlussen.mijnKlussen,
    HhPadenKlussen.profiel,
    HhPadenKlussen.instellingen,
    HhPadenMeldingen.overzicht,
  ],
  HhRol.familie: [
    HhPaden.familie,
    HhPadenFamilie.koppelen,
    HhPadenMeldingen.overzicht,
    HhPaden.instellingen,
  ],
  HhRol.coordinator: [
    HhPaden.coordinator,
    HhPadenCoordinator.klussen,
    HhPadenCoordinator.instellingen,
  ],
};

/// Pompt de app voor één rol, gaat naar [pad] en geeft de layoutfouten
/// terug die Flutter tijdens het opbouwen meldde.
Future<List<String>> bekijk(
  WidgetTester tester, {
  required HhRol? rol,
  required String pad,
  required double breedte,
  required double tekstschaal,
}) async {
  final fouten = <String>[];
  final vorige = FlutterError.onError;
  FlutterError.onError = (details) {
    final regel = details.exceptionAsString().split('\n').first;
    final bron = RegExp(r'file:///[^\s:]+/lib/([^\s]+:\d+)')
        .firstMatch(details.toString())
        ?.group(1);
    fouten.add(bron == null ? regel : '$regel  [$bron]');
  };

  tester.view.physicalSize = Size(breedte, hoogte);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = tekstschaal;

  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      ...toegangOverrides(
        gateway: fakeMetAlleRollen(),
        opslag: GeheugenKeyValueStore(),
        sessie: rol == null
            ? const SessieUitgelogd()
            : SessieIngelogd(testGebruiker(rol)),
        gekozenRol: rol ?? HhRol.hulpvrager,
      ),
    ],
  );

  try {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const HeitjeHulpApp(),
      ),
    );
    await tester.pump();
    container.read(routerProvider).go(pad);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  } finally {
    FlutterError.onError = vorige;
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  }
  return fouten;
}

void main() {
  testWidgets('elk vast scherm past op 320/390/430 bij tekst 100 en 200%', (
    tester,
  ) async {
    final bevindingen = <String>[];
    for (final MapEntry(key: rol, value: paden) in schermenPerRol.entries) {
      for (final pad in paden) {
        for (final breedte in breedtes) {
          for (final schaal in tekstschalen) {
            final fouten = await bekijk(
              tester,
              rol: rol,
              pad: pad,
              breedte: breedte,
              tekstschaal: schaal,
            );
            for (final f in fouten.toSet()) {
              bevindingen.add(
                '${rol?.code ?? 'uitgelogd'} $pad @${breedte.toInt()} x$schaal: $f',
              );
            }
          }
        }
      }
    }
    // ignore: avoid_print
    for (final b in bevindingen) print(b);
    expect(bevindingen, isEmpty, reason: '${bevindingen.length} layoutfouten');
  });
}
