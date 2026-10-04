// Regressie (bestond al vóór ADRES, Riverpod 3.3.2): verandert de sessie
// (taal) terwijl Start eronder ligt of alleen nog in het geheugen zit, dan gaf
// de debug-app bij terugkomen "markNeedsBuild() called during build".
// Instellingen geeft de nieuwe gebruiker nu pas door als het scherm weg is.

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/design/components/hh_scherm.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_gebruiker.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/provider/sessie_providers.dart';
import 'package:heitjehulp_app/features/toegang/screen/instellingen_screen.dart';
import 'package:heitjehulp_app/l10n/teksten_hulpvrager_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_klussen_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';

import '../support/hh_hulpvrager_wikkel.dart';
import '../support/hh_toegang_wikkel.dart';

void main() {
  testWidgets('helper: taal wijzigen in de tab Instellingen, terug naar Klussen', (
    tester,
  ) async {
    final auth = fakeMetAlleRollen();
    final container = await pompApp(
      tester,
      gateway: auth,
      opslag: GeheugenKeyValueStore({
        'hh_auth_token': testToken(HhRol.jongere),
      }),
    );
    await tester.tap(find.text(TekstenKlussenNl.tabInstellingen).last);
    await tester.pumpAndSettle();
    expect(find.byType(InstellingenScreen), findsOneWidget);
    await tester.tap(find.text(TekstenNl.taalTurks));
    await tester.pumpAndSettle();
    expect(auth.laatsteUpdateBody, {'taal': 'tr'});
    expect(find.text(TekstenNl.instellingenOpgeslagen), findsOneWidget);

    await tester.tap(find.text(TekstenKlussenNl.tabKlussen).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(container.read(huidigeGebruikerProvider)?.taal, HhTaal.tr);
  });

  testWidgets('bewoner: Meer -> Instellingen -> taal -> terug', (tester) async {
    final container = await pompHulpvragerApp(
      tester,
      klusGateway: fakeKlusGateway(),
    );
    await tester.tap(find.text(TekstenHulpvragerNl.tabMeer).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(TekstenHulpvragerNl.homeInstellingen));
    await tester.pumpAndSettle();
    await tester.tap(find.text(TekstenNl.taalTurks));
    await tester.pumpAndSettle();

    final terug = find.descendant(
      of: find.byType(HhTerugKnop),
      matching: find.text(TekstenNl.terug),
    );
    await tester.tap(terug);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(container.read(huidigeGebruikerProvider)?.taal, HhTaal.tr);
  });
}
