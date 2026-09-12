import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/design/components/hh_kaart.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../support/hh_wikkel.dart';

void main() {
  group('HhKaart', () {
    testWidgets('rendert inhoud zonder kop', (tester) async {
      await tester.pumpWidget(hhWikkel(const HhKaart(child: Text('inhoud'))));

      expect(find.text('inhoud'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('toont kop en actie, actie reageert op tik', (tester) async {
      var getikt = 0;
      await tester.pumpWidget(
        hhWikkel(
          HhKaart(
            kop: 'Vandaag',
            actie: HhKnop(
              label: 'Alles',
              soort: HhKnopSoort.tekst,
              onPressed: () => getikt++,
            ),
            child: const Text('inhoud'),
          ),
        ),
      );

      expect(find.text('Vandaag'), findsOneWidget);
      await tester.tap(find.text('Alles'));
      expect(getikt, 1);
    });

    testWidgets('semantiek: kop wordt het label', (tester) async {
      await tester.pumpWidget(
        hhWikkel(const HhKaart(kop: 'Vandaag', child: Text('inhoud'))),
      );

      final semantiek = tester.getSemantics(find.byType(HhKaart));
      expect(semantiek.label, 'Vandaag');
    });

    testWidgets('wikkelt bij 200 procent tekst zonder overloop', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhWikkel(
          HhKaart(
            kop: 'Een lange kop die naast een actieknop moet passen',
            actie: HhKnop(
              label: 'Alles bekijken',
              soort: HhKnopSoort.tekst,
              onPressed: () {},
            ),
            child: const Text('inhoud'),
          ),
          dichtheid: HhDichtheid.groot,
          tekstschaal: hhMaxTekstschaal,
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
