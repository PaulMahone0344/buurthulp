import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/design/components/hh_pas_tekst.dart';

import '../../support/hh_wikkel.dart';

// In de testomgeving is elk teken even breed als de lettergrootte.
const _stijl = TextStyle(fontSize: 16, height: 1);

Widget _in(double breedte, String tekst, {bool metHoogteMeting = false}) {
  final vak = SizedBox(
    width: breedte,
    child: HhPasTekst(tekst, stijl: _stijl, textAlign: TextAlign.center),
  );
  return hhWikkel(
    Center(child: metHoogteMeting ? IntrinsicHeight(child: vak) : vak),
  );
}

Size _maat(WidgetTester tester) => tester.getSize(find.byType(HhPasTekst));

void main() {
  group('HhPasTekst', () {
    testWidgets('een woord dat past houdt zijn maat', (tester) async {
      await tester.pumpWidget(_in(200, 'Tuin'));

      // Niet gekrompen: het vak is even hoog als het woord zelf.
      expect(_maat(tester).height, tester.getSize(find.text('Tuin')).height);
    });

    testWidgets('een te lang woord krimpt en blijft op één regel', (
      tester,
    ) async {
      // "Boodschappen" = 12 tekens x 16 = 192 breed, het vak is 160.
      await tester.pumpWidget(_in(160, 'Boodschappen'));

      final ongekrompen = tester.getSize(find.text('Boodschappen'));
      expect(ongekrompen.width, greaterThan(160));
      expect(_maat(tester).width, lessThanOrEqualTo(160));
      expect(_maat(tester).height, lessThan(ongekrompen.height));
    });

    testWidgets('meer woorden gaan tussen de woorden naar een nieuwe regel', (
      tester,
    ) async {
      await tester.pumpWidget(_in(200, 'Tuin'));
      final eenRegel = _maat(tester).height;

      // "Kleine klusjes" (14 x 16 = 224) past niet naast elkaar in 160.
      await tester.pumpWidget(_in(160, 'Kleine klusjes'));

      expect(find.byType(FittedBox), findsNothing);
      expect(_maat(tester).height, eenRegel * 2);
    });

    testWidgets('het hele label blijft als één tekst vindbaar', (tester) async {
      await tester.pumpWidget(_in(160, 'Auto & fiets'));

      expect(find.text('Auto & fiets'), findsOneWidget);
    });

    testWidgets('werkt in een vak dat zijn hoogte vooraf meet', (tester) async {
      // De Keuzerij gebruikt IntrinsicHeight; een LayoutBuilder kan dat niet.
      await tester.pumpWidget(_in(160, 'Boodschappen', metHoogteMeting: true));

      expect(tester.takeException(), isNull);
      expect(find.text('Boodschappen'), findsOneWidget);
    });
  });
}
