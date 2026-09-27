import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/router.dart';
import 'package:heitjehulp_app/features/hulpvrager/veiligheid/paden_veiligheid.dart';
import 'package:heitjehulp_app/features/meldingen/paden_meldingen.dart';
import 'package:heitjehulp_app/features/meldingen/widget/meldingen_bel.dart';
import 'package:heitjehulp_app/l10n/teksten_meldingen_nl.dart';

import '../support/hh_hulpvrager_wikkel.dart';
import '../support/hh_klussen_wikkel.dart';

void main() {
  group('de echte router (met guard) kent de M8-routes', () {
    testWidgets('oudere: O10 en O11', (tester) async {
      final container = await pompHulpvragerApp(
        tester,
        klusGateway: fakeKlusGateway(),
      );
      container.read(routerProvider).go(HhPadenVeiligheid.belOns);
      await tester.pumpAndSettle();
      expect(find.text(TekstenMeldingenNl.o10Bellen), findsOneWidget);
      container.read(routerProvider).go(HhPadenVeiligheid.probleem);
      await tester.pumpAndSettle();
      expect(find.text(TekstenMeldingenNl.o11Vraag), findsOneWidget);
    });

    testWidgets('jongere: het meldingen-overzicht', (tester) async {
      final container = await pompKlussenApp(
        tester,
        klussenGateway: fakeKlussen(),
      );
      expect(find.byType(MeldingenBel), findsOneWidget);
      container.read(routerProvider).go(HhPadenMeldingen.overzicht);
      await tester.pumpAndSettle();
      expect(find.text(TekstenMeldingenNl.overzichtLeeg), findsOneWidget);
    });
  });
}
