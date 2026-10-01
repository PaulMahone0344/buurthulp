import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/app.dart';
import 'package:heitjehulp_app/app/router.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/features/familie/paden_familie.dart';
import 'package:heitjehulp_app/features/familie/screen/familie_home_screen.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/l10n/teksten_familie_nl.dart';

import '../support/hh_toegang_wikkel.dart';

void main() {
  testWidgets('de echte router (met guard) kent de M9-routes', (tester) async {
    final container = toegangContainer(
      gateway: fakeMetAlleRollen(),
      opslag: GeheugenKeyValueStore({
        'hh_auth_token': testToken(HhRol.familie),
      }),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const HeitjeHulpApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Inloggen als familielid landt op F1.
    expect(find.byType(FamilieHomeScreen), findsOneWidget);

    container.read(routerProvider).go(HhPadenFamilie.koppelen);
    await tester.pumpAndSettle();
    expect(find.text(TekstenFamilieNl.aanvraagTitel), findsOneWidget);

    container.read(routerProvider).go(HhPadenFamilie.oudere('vreemd'));
    await tester.pumpAndSettle();
    expect(find.text(TekstenFamilieNl.f3GeenToegang), findsOneWidget);
  });
}
