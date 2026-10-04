import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/pb/fake_adres_gateway.dart';
import 'package:heitjehulp_app/core/pb/gateway_providers.dart';
import 'package:heitjehulp_app/features/adres/domein/adres_invoer.dart';
import 'package:heitjehulp_app/features/adres/widget/adres_zoeker.dart';
import 'package:heitjehulp_app/l10n/teksten_aanmelden_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_adres_nl.dart';

import '../../../support/hh_wikkel.dart';

class _Proef {
  _Proef() : nep = FakeAdresGateway();
  final FakeAdresGateway nep;
  final keuzes = <AdresKeuze?>[];
  AdresKeuze? get laatste => keuzes.isEmpty ? null : keuzes.last;

  Future<void> pomp(
    WidgetTester tester, {
    String postcode = '',
    String huisnummer = '',
    String? weergave,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adresGatewayProvider.overrideWithValue(nep)],
        child: hhWikkel(
          AdresZoeker(
            onGewijzigd: keuzes.add,
            beginPostcode: postcode,
            beginHuisnummer: huisnummer,
            beginWeergave: weergave,
          ),
        ),
      ),
    );
  }
}

Finder _veld(String label) => find.descendant(
  of: find
      .ancestor(of: find.textContaining(label), matching: find.byType(Column))
      .first,
  matching: find.byType(TextField),
);

Future<void> _vul(
  WidgetTester tester,
  String postcode,
  String nummer, [
  String toev = '',
]) async {
  await tester.enterText(_veld(TekstenAdresNl.veldPostcode), postcode);
  await tester.enterText(_veld(TekstenAdresNl.veldHuisnummer), nummer);
  if (toev.isNotEmpty) {
    await tester.enterText(_veld(TekstenAdresNl.veldToevoeging), toev);
  }
}

void main() {
  testWidgets(
    'geen straat- of plaatsveld: alleen postcode, huisnummer, toevoeging',
    (tester) async {
      await _Proef().pomp(tester);
      expect(
        find.textContaining(TekstenAdresNl.veldPostcode, findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining(TekstenAdresNl.veldHuisnummer, findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining(TekstenAdresNl.veldToevoeging, findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Straat'), findsNothing);
      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.text('Plaats'), findsNothing);
    },
  );

  testWidgets('postcode krijgt hoofdletters en een spatie', (tester) async {
    await _Proef().pomp(tester);
    await tester.enterText(_veld(TekstenAdresNl.veldPostcode), '4001ma');
    await tester.pump();
    expect(find.text('4001 MA'), findsOneWidget);
  });

  testWidgets('postcode + huisnummer -> na 400 ms het kaartje met vinkje', (
    tester,
  ) async {
    final p = _Proef();
    await p.pomp(tester);
    await _vul(tester, '4001ma', '1');
    await tester.pump(const Duration(milliseconds: 399));
    expect(
      p.nep.verzoeken,
      isEmpty,
      reason: 'nog niet opzoeken tijdens het typen',
    );
    expect(find.text(TekstenAdresNl.zoeken), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('Kerkstraat 1, 4001 MA Tiel'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(p.laatste?.isBevestigd, isTrue);
    expect(p.laatste?.velden['adres'], 'Kerkstraat 1');
    expect(p.laatste?.velden['plaats'], 'Tiel');
    expect(p.nep.verzoeken, hasLength(1));
    expect(find.text(TekstenAanmeldenNl.nietInBuurt), findsNothing);
  });

  testWidgets('snel doortypen = één verzoek (debounce)', (tester) async {
    final p = _Proef();
    await p.pomp(tester);
    await tester.enterText(_veld(TekstenAdresNl.veldPostcode), '4001 MA');
    for (final n in ['1', '12', '1']) {
      await tester.enterText(_veld(TekstenAdresNl.veldHuisnummer), n);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(p.nep.verzoeken, hasLength(1));
    expect(p.nep.verzoeken.single.huisnummer, '1');
  });

  testWidgets('meerdere toevoegingen -> kiezen uit een lijstje', (
    tester,
  ) async {
    final p = _Proef();
    await p.pomp(tester);
    await _vul(tester, '4001 JS', '1');
    await tester.pump(adresZoekWachttijd);
    await tester.pump();
    expect(find.text(TekstenAdresNl.kiesKop), findsOneWidget);
    expect(p.laatste, isNull);
    await tester.tap(find.text('Nieuwe Tielseweg 1a-02, 4001 JS Tiel'));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(p.laatste?.toevoeging, 'a-02');
    expect(find.text('a-02'), findsOneWidget, reason: 'toevoeging ingevuld');
    expect(p.nep.verzoeken, hasLength(1), reason: 'kiezen zoekt niet opnieuw');
  });

  testWidgets('niet gevonden -> rustige melding, geen keuze', (tester) async {
    final p = _Proef();
    await p.pomp(tester);
    await _vul(tester, '4001 MA', '999');
    await tester.pump(adresZoekWachttijd);
    await tester.pump();
    expect(find.text(TekstenAdresNl.nietGevonden), findsOneWidget);
    expect(p.laatste, isNull);
  });

  testWidgets(
    'buiten het werkgebied -> meteen "nog niet in jouw buurt", keuze mag wel',
    (tester) async {
      final p = _Proef();
      await p.pomp(tester);
      await _vul(tester, '1012 JS', '1');
      await tester.pump(adresZoekWachttijd);
      await tester.pump();
      expect(find.text('Dam 1, 1012 JS Amsterdam'), findsOneWidget);
      expect(find.text(TekstenAanmeldenNl.nietInBuurt), findsOneWidget);
      expect(p.laatste?.isBevestigd, isTrue);
    },
  );

  testWidgets('PDOK weg -> melding en een ongecontroleerde keuze', (
    tester,
  ) async {
    final p = _Proef()..nep.dienstWeg = true;
    await p.pomp(tester);
    await _vul(tester, '4001 MA', '3', 'b');
    await tester.pump(adresZoekWachttijd);
    await tester.pump();
    expect(find.text(TekstenAdresNl.dienstWeg), findsOneWidget);
    expect(p.laatste?.isBevestigd, isFalse);
    expect(p.laatste?.velden, {
      'postcode': '4001 MA',
      'huisnummer': '3',
      'toevoeging': 'b',
    });
  });

  testWidgets('limiet -> de melding van de server', (tester) async {
    final p = _Proef()..nep.limiet = true;
    await p.pomp(tester);
    await _vul(tester, '4001 MA', '1');
    await tester.pump(adresZoekWachttijd);
    await tester.pump();
    expect(find.textContaining('over een uur'), findsOneWidget);
    expect(p.laatste, isNull);
  });

  testWidgets(
    'wijzigen na een keuze wist de keuze tot het nieuwe adres er is',
    (tester) async {
      final p = _Proef();
      await p.pomp(tester);
      await _vul(tester, '4001 MA', '1');
      await tester.pump(adresZoekWachttijd);
      await tester.pump();
      expect(p.laatste?.isBevestigd, isTrue);
      await tester.enterText(_veld(TekstenAdresNl.veldHuisnummer), '12');
      await tester.pump();
      expect(p.laatste, isNull);
      await tester.pump(adresZoekWachttijd);
      await tester.pump();
    },
  );

  testWidgets('met een bekend adres: kaartje zonder opzoeken', (tester) async {
    final p = _Proef();
    await p.pomp(
      tester,
      postcode: '4001 MA',
      huisnummer: '1',
      weergave: 'Kerkstraat 1, 4001 MA Tiel',
    );
    await tester.pump(adresZoekWachttijd);
    expect(find.text('Kerkstraat 1, 4001 MA Tiel'), findsOneWidget);
    expect(p.nep.verzoeken, isEmpty);
  });

  testWidgets('smal scherm en 200% tekst: geen overloop', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final p = _Proef();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adresGatewayProvider.overrideWithValue(p.nep)],
        child: hhWikkel(
          AdresZoeker(onGewijzigd: p.keuzes.add),
          tekstschaal: hhMaxTekstschaal,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
