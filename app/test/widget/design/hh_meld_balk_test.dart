import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/design/components/hh_meld_balk.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../support/hh_wikkel.dart';

void main() {
  group('HhMeldBalk', () {
    for (final soort in HhMeldSoort.values) {
      testWidgets('rendert soort $soort met icoon en tekst', (tester) async {
        await tester.pumpWidget(
          hhWikkel(HhMeldBalk(soort: soort, tekst: 'Bericht')),
        );

        expect(find.text('Bericht'), findsOneWidget);
        expect(find.byType(Icon), findsOneWidget);
      });
    }

    testWidgets('semantiek: soort plus tekst, als live-region', (tester) async {
      await tester.pumpWidget(
        hhWikkel(
          const HhMeldBalk(
            soort: HhMeldSoort.fout,
            tekst: 'Verzenden lukte niet.',
          ),
        ),
      );

      final semantiek = tester.getSemantics(find.byType(HhMeldBalk));
      expect(semantiek.label, 'Fout: Verzenden lukte niet.');
      expect(semantiek.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    });

    testWidgets('wikkelt bij 200 procent tekst zonder overloop', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhWikkel(
          const HhMeldBalk(
            soort: HhMeldSoort.waarschuwing,
            tekst:
                'Nog niemand heeft deze klus aangenomen. We blijven '
                'zoeken en bellen u zodra er iemand is.',
          ),
          dichtheid: HhDichtheid.groot,
          tekstschaal: hhMaxTekstschaal,
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
