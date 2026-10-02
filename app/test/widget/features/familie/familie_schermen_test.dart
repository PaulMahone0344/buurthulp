import 'package:flutter/widgets.dart';
import 'package:heitjehulp_app/features/meldingen/model/hh_melding.dart';
import 'package:heitjehulp_app/core/pb/fake_meldingen_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/pb/fake_familie_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_uitvoer_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/features/familie/model/hh_koppeling.dart';
import 'package:heitjehulp_app/features/familie/paden_familie.dart';
import 'package:heitjehulp_app/features/hulpvrager/paden_hulpvrager.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/widget/hulpvraag_tegel.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/l10n/teksten_familie_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../support/hh_familie_wikkel.dart';
import '../../../support/hh_jongere_wikkel.dart';
import '../../../support/hh_uitvoeren_wikkel.dart';

/// Een klus van de test-oudere die het familielid zelf plaatste.
FakeUitvoerGateway _uitvoerMetEigenKlus({
  HhKlusStatus status = HhKlusStatus.geaccepteerd,
}) => fakeUitvoer(
  klussen: [
    uitvoerKlus(
      id: 'k-mijn',
      status: status,
    ).copyWith(geplaatstDoorId: familieId),
    uitvoerKlus(id: 'k-oudere', status: HhKlusStatus.open, metJongere: false),
  ],
  ikBen: familieId,
);

class _Geval {
  const _Geval(
    this.naam,
    this.pad,
    this.familie, {
    this.rol = HhRol.familie,
    this.uitvoer,
  });

  final String naam;
  final String pad;
  final FakeFamilieGateway Function() familie;
  final HhRol rol;
  final FakeUitvoerGateway Function()? uitvoer;
}

final _gevallen = <_Geval>[
  _Geval('F1 leeg', HhPaden.familie, () => fakeFamilie()),
  _Geval(
    'F1 twee ouderen en een aanvraag',
    HhPaden.familie,
    () => fakeFamilie(
      koppelingen: [
        testKoppeling(),
        testKoppeling(id: 'kp-2', oudere: 'o2', oudereNaam: 'Meneer Jansen'),
        testKoppeling(
          id: 'kp-3',
          oudere: 'o3',
          status: KoppelingStatus.aangevraagd,
        ),
      ],
    ),
  ),
  _Geval('aanvragen', HhPadenFamilie.koppelen, () => fakeFamilie()),
  _Geval(
    'F3 met beide rechten',
    HhPadenFamilie.oudere(oudereId),
    () => fakeFamilie(koppelingen: [testKoppeling()]),
    uitvoer: _uitvoerMetEigenKlus,
  ),
  _Geval(
    'F3 alleen meekijken',
    HhPadenFamilie.oudere(oudereId),
    () => fakeFamilie(
      koppelingen: [
        testKoppeling(rechten: {FamilieRecht.meekijken}),
      ],
    ),
    uitvoer: _uitvoerMetEigenKlus,
  ),
  _Geval(
    'F3 alleen plaatsen',
    HhPadenFamilie.oudere(oudereId),
    () => fakeFamilie(
      koppelingen: [
        testKoppeling(rechten: {FamilieRecht.plaatsen}),
      ],
    ),
  ),
  _Geval(
    'F3-detail eigen klus',
    HhPadenFamilie.hulpvraag(oudereId, 'k-mijn'),
    () => fakeFamilie(koppelingen: [testKoppeling()]),
    uitvoer: _uitvoerMetEigenKlus,
  ),
  _Geval(
    'O12 blok met een vraag en een gekoppeld familielid',
    HhPadenHulpvrager.gegevens,
    () => fakeFamilie(
      koppelingen: [
        testKoppeling(id: 'kp-vraag', status: KoppelingStatus.aangevraagd),
        testKoppeling(id: 'kp-actief'),
      ],
    ),
    rol: HhRol.hulpvrager,
  ),
];

Future<FakeFamilieGateway> _pomp(
  WidgetTester tester,
  _Geval geval, {
  HhDichtheid? dichtheid,
  double tekstschaal = 1.0,
}) async {
  final familie = geval.familie();
  await tester.pumpWidget(
    hhFamilieWikkel(
      geval.pad,
      rol: geval.rol,
      familieGateway: familie,
      uitvoerGateway: geval.uitvoer?.call(),
      dichtheid: dichtheid,
      tekstschaal: tekstschaal,
    ),
  );
  await tester.pumpAndSettle();
  return familie;
}

void main() {
  group('elk M9-scherm rendert in beide dichtheden met semantiek', () {
    for (final geval in _gevallen) {
      for (final dichtheid in HhDichtheid.values) {
        testWidgets('${geval.naam} (${dichtheid.name})', (tester) async {
          final handle = tester.ensureSemantics();
          await _pomp(tester, geval, dichtheid: dichtheid);
          expect(tester.takeException(), isNull);
          controleerSemantiek(tester);
          handle.dispose();
        });
      }
    }

    for (final geval in _gevallen) {
      testWidgets('${geval.naam} op 200 procent zonder overloop', (
        tester,
      ) async {
        await _pomp(
          tester,
          geval,
          dichtheid: HhDichtheid.groot,
          tekstschaal: 2.0,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('F1', () {
    testWidgets('twee ouderen: de lijst, de aanvraag staat er niet', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[1]);
      expect(find.text(testOudereNaam), findsOneWidget);
      expect(find.text('Meneer Jansen'), findsOneWidget);
      // Besluit 30 sep: F1 verraadt niet of een adres bij een oudere hoort.
      expect(find.text(TekstenFamilieNl.f1AanvragenKop), findsNothing);
      expect(find.text(TekstenFamilieNl.f1AanvraagRegel), findsNothing);
    });

    testWidgets('precies één oudere: meteen door naar F3', (tester) async {
      await tester.pumpWidget(
        hhFamilieWikkel(
          HhPaden.familie,
          familieGateway: fakeFamilie(koppelingen: [testKoppeling()]),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(TekstenFamilieNl.f3Titel(testOudereNaam)),
        findsOneWidget,
      );
    });

    testWidgets('vanaf F3 terug: de lijst blijft staan', (tester) async {
      await tester.pumpWidget(
        hhFamilieWikkel(
          HhPadenFamilie.lijst,
          familieGateway: fakeFamilie(koppelingen: [testKoppeling()]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(TekstenFamilieNl.f1Titel), findsOneWidget);
      expect(find.text(testOudereNaam), findsOneWidget);
    });

    testWidgets('een aanvraag alleen: blijft op F1, als lege staat', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhFamilieWikkel(
          HhPaden.familie,
          familieGateway: fakeFamilie(
            koppelingen: [testKoppeling(status: KoppelingStatus.aangevraagd)],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(TekstenFamilieNl.f1AanvragenKop), findsNothing);
      expect(find.text(TekstenFamilieNl.f1Leeg), findsOneWidget);
    });
  });

  group('aanvragen', () {
    testWidgets('een ongeldig adres gaat niet weg', (tester) async {
      final familie = await _pomp(tester, _gevallen[2]);
      await vulVeld(tester, 0, 'geen-adres');
      await tikKnop(tester, TekstenFamilieNl.aanvraagVersturen);
      expect(find.text(TekstenFamilieNl.aanvraagEmailFout), findsOneWidget);
      expect(familie.aangevraagd, isEmpty);
    });
  });

  group('F3 (rechten -> wat zichtbaar is)', () {
    testWidgets('beide rechten: "Hulp vragen voor ..." en de lijsten', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[3]);
      expect(
        find.widgetWithText(
          HhKnop,
          TekstenFamilieNl.f3HulpVragen(testOudereNaam),
        ),
        findsOneWidget,
      );
      expect(find.byType(HulpvraagTegel), findsOneWidget); // gepland
      expect(find.text(TekstenFamilieNl.f3MeldingenKop), findsOneWidget);
    });

    testWidgets('meekijken: de laatste meldingen van de oudere', (
      tester,
    ) async {
      final meldingen = FakeMeldingenGateway(
        meldingen: [
          HhMelding(
            id: 'm-o',
            ontvangerId: oudereId,
            soort: HhMeldingSoort.onderweg,
            tekst: 'Sanne is onderweg naar u.',
          ),
        ],
      );
      await tester.pumpWidget(
        hhFamilieWikkel(
          HhPadenFamilie.oudere(oudereId),
          familieGateway: fakeFamilie(koppelingen: [testKoppeling()]),
          meldingenGateway: meldingen,
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Sanne is onderweg naar u.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Sanne is onderweg naar u.'), findsOneWidget);
      // Alleen lezen: het familielid zet niets op gelezen.
      expect(meldingen.gelezenGezet, isEmpty);
    });

    testWidgets('alleen plaatsen: geen meldingen van de oudere', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[5]);
      expect(find.text(TekstenFamilieNl.f3MeldingenKop), findsNothing);
    });

    testWidgets('alleen meekijken: geen F2-knop', (tester) async {
      await _pomp(tester, _gevallen[4]);
      expect(
        find.widgetWithText(
          HhKnop,
          TekstenFamilieNl.f3HulpVragen(testOudereNaam),
        ),
        findsNothing,
      );
      expect(find.byType(HulpvraagTegel), findsOneWidget);
    });

    testWidgets('alleen plaatsen: wel F2, geen lijsten', (tester) async {
      await _pomp(tester, _gevallen[5]);
      expect(
        find.widgetWithText(
          HhKnop,
          TekstenFamilieNl.f3HulpVragen(testOudereNaam),
        ),
        findsOneWidget,
      );
      expect(find.byType(HulpvraagTegel), findsNothing);
      expect(find.text(TekstenFamilieNl.f3GeenMeekijken), findsOneWidget);
    });

    testWidgets('geen koppeling met deze oudere: nette lege staat', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhFamilieWikkel(
          HhPadenFamilie.oudere('vreemd'),
          familieGateway: fakeFamilie(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(TekstenFamilieNl.f3GeenToegang), findsOneWidget);
    });
  });

  group('F3-detail', () {
    testWidgets('eigen klus: zin, en "stoppen" mag', (tester) async {
      await _pomp(tester, _gevallen[6]);
      expect(find.text(TekstenFamilieNl.f3DoorMij), findsOneWidget);
      expect(
        find.widgetWithText(HhKnop, TekstenFamilieNl.f3Annuleren),
        findsOneWidget,
      );
      // Alleen-lezen: geen bellen, geen statusstappen.
      expect(find.byType(HhKnop).evaluate().length, lessThanOrEqualTo(2));
    });

    testWidgets('de statuszin noemt de oudere, niet "u"', (tester) async {
      await _pomp(tester, _gevallen[6]);
      expect(find.text('Sanne komt Mevrouw de Vries helpen.'), findsOneWidget);
      expect(find.text(TekstenFamilieNl.f3Helper), findsWidgets);
      expect(find.textContaining('komt u'), findsNothing);
      expect(find.text('Uw helper'), findsNothing);
    });

    testWidgets('klus van de oudere zelf: geen "stoppen"', (tester) async {
      await tester.pumpWidget(
        hhFamilieWikkel(
          HhPadenFamilie.hulpvraag(oudereId, 'k-oudere'),
          familieGateway: fakeFamilie(koppelingen: [testKoppeling()]),
          uitvoerGateway: _uitvoerMetEigenKlus(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(HhKnop, TekstenFamilieNl.f3Annuleren),
        findsNothing,
      );
      expect(find.text(TekstenFamilieNl.f3DoorMij), findsNothing);
    });
  });

  group('O12 blok "Familie" (ouderenregel)', () {
    testWidgets('de vraag in gewone taal met Ja en Nee; gekoppeld met '
        'Ontkoppelen', (tester) async {
      await _pomp(tester, _gevallen[7]);
      expect(find.text(TekstenFamilieNl.o12Vraag(familieNaam)), findsOneWidget);
      expect(
        find.widgetWithText(HhKnop, TekstenFamilieNl.o12Ja),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(HhKnop, TekstenFamilieNl.o12Nee),
        findsOneWidget,
      );
      expect(
        find.text(TekstenFamilieNl.o12Gekoppeld(familieNaam)),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(HhKnop, TekstenFamilieNl.o12Ontkoppelen),
        findsOneWidget,
      );
      expect(find.text(TekstenNl.terug), findsOneWidget);
    });

    testWidgets('niemand: een rustige zin', (tester) async {
      await tester.pumpWidget(
        hhFamilieWikkel(
          HhPadenHulpvrager.gegevens,
          rol: HhRol.hulpvrager,
          familieGateway: fakeFamilie(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(TekstenFamilieNl.o12Niemand), findsOneWidget);
    });

    testWidgets('elke knop in het blok is groot (60)', (tester) async {
      await _pomp(tester, _gevallen[7], dichtheid: HhDichtheid.groot);
      for (final label in [
        TekstenFamilieNl.o12Ja,
        TekstenFamilieNl.o12Nee,
        TekstenFamilieNl.o12Ontkoppelen,
      ]) {
        final knop = find.widgetWithText(HhKnop, label);
        await tester.ensureVisible(knop);
        expect(
          tester.getSize(knop).height,
          greaterThanOrEqualTo(HhMaten.knopHoogte(HhDichtheid.groot)),
        );
      }
    });
  });
}
