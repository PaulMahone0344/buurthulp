// DEMO — de demomodus: elke rol logt zonder server in en landt op zijn
// eigen startscherm, met de nepgegevens erin.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/app.dart';
import 'package:heitjehulp_app/app/router.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/demo/demo_data.dart';
import 'package:heitjehulp_app/demo/demo_knoppen.dart';
import 'package:heitjehulp_app/demo/demo_overrides.dart';
import 'package:heitjehulp_app/features/jongere/klussen/provider/klussen_providers.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/features/toegang/provider/sessie_providers.dart';

import '../support/hh_klussen_wikkel.dart' show NepTegels;
import '../support/hh_wikkel.dart';

Future<ProviderContainer> _pompDemo(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      ...demoOverrides(),
      // Nooit het netwerk op voor kaarttegels.
      kaartTegelsProvider.overrideWithValue(NepTegels.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const HeitjeHulpApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return container;
}

String _pad(ProviderContainer container) =>
    container.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

void main() {
  testWidgets('demo start uitgelogd; zonder HH_DEMO geen knoppen op G2', (
    tester,
  ) async {
    final container = await _pompDemo(tester);

    expect(container.read(sessieControllerProvider), isA<SessieUitgelogd>());
    expect(
      find.byType(DemoKnoppen),
      findsNothing,
      reason: 'zonder HH_DEMO toont G2 geen demo-knoppen',
    );
  });

  testWidgets('tik op "Als strijder" logt de demo-strijder in', (tester) async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [...demoOverrides()],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: hhWikkel(const DemoKnoppen()),
      ),
    );

    expect(find.text('Als bewoner'), findsOneWidget);
    expect(find.text('Als meldkamer'), findsOneWidget);
    await tester.tap(find.text('Als strijder'));
    await tester.pump();

    final sessie = container.read(sessieControllerProvider);
    expect(sessie, isA<SessieIngelogd>());
    expect((sessie as SessieIngelogd).gebruiker.id, demoStrijderId);
  });

  for (final rol in HhRol.values) {
    testWidgets('demo: ${rol.code} logt in zonder server en landt op '
        '${rol.pad}', (tester) async {
      final container = await _pompDemo(tester);

      final uitkomst = await container
          .read(sessieControllerProvider.notifier)
          .inloggen(
            email: demoGebruiker(rol).email,
            wachtwoord: demoWachtwoord,
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(uitkomst, isA<Ok<void>>());
      final sessie = container.read(sessieControllerProvider);
      expect(sessie, isA<SessieIngelogd>());
      expect((sessie as SessieIngelogd).gebruiker.rol, rol);
      expect(_pad(container), startsWith(rol.pad));
      expect(tester.takeException(), isNull);
    });
  }
}
