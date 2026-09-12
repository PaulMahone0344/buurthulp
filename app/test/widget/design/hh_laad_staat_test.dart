import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/design/components/hh_laad_staat.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../support/hh_wikkel.dart';

void main() {
  group('HhLaadStaat', () {
    testWidgets('spinner rendert een voortgangsindicator', (tester) async {
      await tester.pumpWidget(hhWikkel(const HhLaadStaat.spinner()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('skelet rendert het gevraagde aantal rijen', (tester) async {
      await tester.pumpWidget(hhWikkel(const HhLaadStaat.skelet(regels: 4)));
      // Een enkele pump: de pulsanimatie herhaalt zich en settelt nooit.
      await tester.pump();

      expect(find.byType(FractionallySizedBox), findsNWidgets(8));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('semantiek: alleen het label, als live-region', (tester) async {
      await tester.pumpWidget(
        hhWikkel(const HhLaadStaat.skelet(label: 'Klussen worden geladen')),
      );

      final semantiek = tester.getSemantics(find.byType(HhLaadStaat));
      expect(semantiek.label, 'Klussen worden geladen');
    });

    testWidgets('skelet volgt de dichtheid: grotere avatar in groot', (
      tester,
    ) async {
      final maten = <HhDichtheid, double>{};
      for (final dichtheid in HhDichtheid.values) {
        await tester.pumpWidget(
          hhWikkel(const HhLaadStaat.skelet(regels: 1), dichtheid: dichtheid),
        );
        maten[dichtheid] = tester.getSize(find.byType(HhLaadStaat)).height;
      }

      expect(
        maten[HhDichtheid.groot],
        greaterThan(maten[HhDichtheid.normaal]!),
      );
    });
  });
}
