import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/features/toegang/kennismaken/kennismaken_screen.dart';
import 'package:heitjehulp_app/features/toegang/screen/welkom_screen.dart';
import 'package:heitjehulp_app/l10n/teksten_kennismaken_nl.dart';

import '../support/hh_toegang_wikkel.dart';

const _sleutel = 'hh_kennismaking_gezien';

Future<void> _tik(WidgetTester tester, String tekst) async {
  await tester.tap(find.text(tekst));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('eerste keer: kennismaking, vier pagina\'s, dan welkom', (
    tester,
  ) async {
    final opslag = GeheugenKeyValueStore();
    await pompApp(
      tester,
      gateway: fakeMetAlleRollen(),
      opslag: opslag,
      isKennismakingGezien: false,
    );

    expect(find.byType(KennismakenScreen), findsOneWidget);
    expect(find.byType(WelkomScreen), findsNothing);
    final paginas = TekstenKennismakenNl.paginas;
    for (var i = 0; i < paginas.length; i++) {
      expect(find.text(paginas[i].titel), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          TekstenKennismakenNl.paginaVan(i + 1, paginas.length),
        ),
        findsOneWidget,
      );
      if (i < paginas.length - 1) {
        await _tik(tester, TekstenKennismakenNl.volgende);
      }
    }
    expect(find.text(TekstenKennismakenNl.volgende), findsNothing);

    await _tik(tester, TekstenKennismakenNl.aanDeSlag);

    expect(find.byType(WelkomScreen), findsOneWidget);
    expect(opslag.waarden[_sleutel], 'true');
  });

  testWidgets('vegen werkt ook; overslaan gaat meteen naar welkom', (
    tester,
  ) async {
    await pompApp(
      tester,
      gateway: fakeMetAlleRollen(),
      isKennismakingGezien: false,
    );
    final eerste = TekstenKennismakenNl.paginas.first.titel;
    await tester.drag(find.text(eerste), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text(TekstenKennismakenNl.paginas[1].titel), findsOneWidget);

    await _tik(tester, TekstenKennismakenNl.overslaan);

    expect(find.byType(WelkomScreen), findsOneWidget);
  });

  testWidgets('al gezien: meteen welkom, geen kennismaking', (tester) async {
    await pompApp(
      tester,
      gateway: fakeMetAlleRollen(),
      opslag: GeheugenKeyValueStore({_sleutel: 'true'}),
      isKennismakingGezien: false,
    );

    expect(find.byType(WelkomScreen), findsOneWidget);
    expect(find.byType(KennismakenScreen), findsNothing);
  });

  testWidgets('groot lettertype: alles past, geen overloop', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      hhToegangWikkel(
        const KennismakenScreen(),
        gateway: fakeMetAlleRollen(),
        tekstschaal: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
