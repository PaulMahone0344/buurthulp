import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/core/pb/fake_meldkamer_gateway.dart';
import 'package:heitjehulp_app/features/coordinator/model/hh_te_doen.dart';
import 'package:heitjehulp_app/features/coordinator/paden_coordinator.dart';
import 'package:heitjehulp_app/l10n/teksten_meldkamer_nl.dart';

import '../../../support/hh_coordinator_wikkel.dart';

const _anja = HhTeBellen(
  id: 'b1',
  naam: 'Anja',
  telefoon: '06 1234 5678',
  plaats: 'Tiel',
);
final _sanne = HhTeKeurenHelper(
  profielId: 'p1',
  gebruikerId: 'u1',
  naam: 'Sanne',
  geboortedatum: DateTime.utc(2006),
  aangemeldOp: null,
);
const _ouder = HhOuderIngetrokken(helperId: 'h1', naam: 'Daan');
const _klusWacht = HhTeKeurenKlus(
  id: 'k1',
  bewonerNaam: 'Anja',
  soort: 'tuin',
  omschrijving: 'Heg knippen',
  wanneerVan: null,
  wanneerTot: null,
  wachtOpBelletje: true,
);

Future<FakeMeldkamerGateway> _open(WidgetTester tester, HhTeDoen stand) async {
  final fake = FakeMeldkamerGateway(stand: stand);
  await tester.pumpWidget(
    hhCoordinatorWikkel(
      HhPadenCoordinator.teDoen,
      gateway: fakeCoordinator(),
      meldkamer: fake,
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

Future<void> _tik(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Finder _inDialoog(String tekst) => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.widgetWithText(TextButton, tekst),
);

void main() {
  testWidgets('niets te doen: lege staat', (tester) async {
    await _open(tester, const HhTeDoen());
    expect(find.text(TekstenMeldkamerNl.legeTitel), findsOneWidget);
  });

  testWidgets('teller op de tab telt alles', (tester) async {
    await _open(
      tester,
      HhTeDoen(
        bellen: const [_anja],
        helpers: [_sanne],
        ouders: const [_ouder],
      ),
    );
    expect(
      find.bySemanticsLabel(TekstenMeldkamerNl.tabSemantiek(3)),
      findsOneWidget,
    );
  });

  testWidgets('bewoner gesproken: notitie optioneel, daarna uit de lijst', (
    tester,
  ) async {
    final fake = await _open(tester, const HhTeDoen(bellen: [_anja]));
    expect(find.text('06 1234 5678 · Tiel'), findsOneWidget);

    await _tik(
      tester,
      find.widgetWithText(InkWell, TekstenMeldkamerNl.gesproken).first,
    );
    await tester.enterText(find.byType(TextField), 'Aardig');
    await _tik(tester, _inDialoog(TekstenMeldkamerNl.gesproken));

    expect(fake.aanroepen, ['kennismaking b1 gesproken Aardig']);
    expect(
      find.text(TekstenMeldkamerNl.gesprokenGelukt('Anja')),
      findsOneWidget,
    );
    expect(find.text(TekstenMeldkamerNl.legeTitel), findsOneWidget);
  });

  testWidgets(
    'weigeren: pas na een notitie, melding met geannuleerde klussen',
    (tester) async {
      final fake = await _open(tester, const HhTeDoen(bellen: [_anja]))
        ..geannuleerdBijWeigeren = 2;

      await _tik(
        tester,
        find.widgetWithText(InkWell, TekstenMeldkamerNl.weigeren).first,
      );
      expect(find.text(TekstenMeldkamerNl.weigerenUitleg), findsOneWidget);
      final knop = tester.widget<TextButton>(
        _inDialoog(TekstenMeldkamerNl.weigeren),
      );
      expect(knop.onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Wilde zorgtaken');
      await tester.pumpAndSettle();
      await _tik(tester, _inDialoog(TekstenMeldkamerNl.weigeren));

      expect(fake.aanroepen, ['kennismaking b1 geweigerd Wilde zorgtaken']);
      expect(
        find.text(TekstenMeldkamerNl.geweigerdGelukt('Anja', 2)),
        findsOneWidget,
      );
    },
  );

  testWidgets('strijder goedkeuren met voorgevulde notitie', (tester) async {
    final fake = await _open(tester, HhTeDoen(helpers: [_sanne]));
    expect(find.textContaining('jaar'), findsOneWidget);

    await _tik(
      tester,
      find.widgetWithText(InkWell, TekstenMeldkamerNl.goedkeuren).first,
    );
    await _tik(tester, _inDialoog(TekstenMeldkamerNl.goedkeuren));

    expect(fake.aanroepen, [
      'strijder p1 goedgekeurd ${TekstenMeldkamerNl.goedkeurenStandaardNotitie}',
    ]);
  });

  testWidgets('ouder vrijgeven na bevestigen', (tester) async {
    final fake = await _open(tester, const HhTeDoen(ouders: [_ouder]));
    await _tik(
      tester,
      find.widgetWithText(InkWell, TekstenMeldkamerNl.vrijgeven).first,
    );
    await _tik(tester, _inDialoog(TekstenMeldkamerNl.vrijgeven));
    expect(fake.aanroepen, ['ouder h1']);
    expect(
      find.text(TekstenMeldkamerNl.vrijgevenGelukt('Daan')),
      findsOneWidget,
    );
  });

  testWidgets(
    'klus die op het belletje wacht: goedkeuren uit, afkeuren met reden',
    (tester) async {
      final fake = await _open(tester, const HhTeDoen(klussen: [_klusWacht]));
      expect(find.text(TekstenMeldkamerNl.eerstBellen), findsOneWidget);

      await _tik(
        tester,
        find.widgetWithText(InkWell, TekstenMeldkamerNl.goedkeuren).first,
      );
      expect(fake.aanroepen, isEmpty);

      await _tik(
        tester,
        find.widgetWithText(InkWell, TekstenMeldkamerNl.afkeuren).first,
      );
      await tester.enterText(find.byType(TextField), 'kort');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(_inDialoog(TekstenMeldkamerNl.afkeuren))
            .onPressed,
        isNull,
        reason: 'minstens 5 tekens',
      );
      await tester.enterText(
        find.byType(TextField),
        'Dit mag een strijder niet doen.',
      );
      await tester.pumpAndSettle();
      await _tik(tester, _inDialoog(TekstenMeldkamerNl.afkeuren));
      expect(fake.aanroepen, [
        'klus k1 afkeuren Dit mag een strijder niet doen.',
      ]);
    },
  );

  testWidgets('fout van de server: de melding staat bovenaan, item blijft', (
    tester,
  ) async {
    final fake = await _open(tester, const HhTeDoen(ouders: [_ouder]));
    fake.volgendeFout = HhFout.vanStatus(
      409,
      antwoord: {'melding': 'De toestemming is niet ingetrokken.'},
    );
    await _tik(
      tester,
      find.widgetWithText(InkWell, TekstenMeldkamerNl.vrijgeven).first,
    );
    await _tik(tester, _inDialoog(TekstenMeldkamerNl.vrijgeven));
    expect(find.text('De toestemming is niet ingetrokken.'), findsOneWidget);
    expect(find.text('Daan'), findsOneWidget);
  });
}
