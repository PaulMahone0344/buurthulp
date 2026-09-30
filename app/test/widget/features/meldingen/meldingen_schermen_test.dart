import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/config.dart';
import 'package:heitjehulp_app/core/pb/fake_meldingen_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/features/hulpvrager/veiligheid/paden_veiligheid.dart';
import 'package:heitjehulp_app/features/jongere/klussen/paden_klussen.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/paden_uitvoeren.dart';
import 'package:heitjehulp_app/features/meldingen/model/hh_melding.dart';
import 'package:heitjehulp_app/features/meldingen/paden_meldingen.dart';
import 'package:heitjehulp_app/features/meldingen/widget/laatste_melding_regel.dart';
import 'package:heitjehulp_app/features/meldingen/widget/meldingen_bel.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/l10n/teksten_hulpvrager_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_meldingen_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../support/hh_jongere_wikkel.dart';
import '../../../support/hh_meldingen_wikkel.dart';
import '../../../support/hh_uitvoeren_wikkel.dart';

List<HhMelding> _voorJongere() => [
  testMelding(
    id: 'a',
    ontvanger: jongereId,
    soort: HhMeldingSoort.nieuweKlus,
    klus: 'k-ochtend',
    titel: 'Nieuwe klus in je buurt',
    tekst: 'Boodschappen woensdag 16 september om 09:00.',
    minutenGeleden: 2,
  ),
  testMelding(
    id: 'b',
    ontvanger: jongereId,
    soort: HhMeldingSoort.afgerond,
    titel: 'Klus afgerond',
    tekst: 'Bedankt voor je hulp. Boodschappen is klaar.',
    minutenGeleden: 60,
    gelezen: true,
  ),
];

/// Een scherm in de staat die het nodig heeft.
class _Geval {
  const _Geval(this.naam, this.pad, this.rol, {this.meldingen, this.stappen});

  final String naam;
  final String pad;
  final HhRol rol;
  final List<HhMelding> Function()? meldingen;

  /// Knoppen die na het laden getikt worden om bij de stap te komen.
  final List<String>? stappen;
}

final _gevallen = [
  const _Geval(
    'overzicht met meldingen',
    HhPadenMeldingen.overzicht,
    HhRol.jongere,
    meldingen: _voorJongere,
  ),
  const _Geval('overzicht leeg', HhPadenMeldingen.overzicht, HhRol.jongere),
  const _Geval('O10 bel ons', HhPadenVeiligheid.belOns, HhRol.hulpvrager),
  const _Geval('O11 keuze', HhPadenVeiligheid.probleem, HhRol.hulpvrager),
  const _Geval(
    'O11 nood bevestigen',
    HhPadenVeiligheid.probleem,
    HhRol.hulpvrager,
    stappen: [TekstenMeldingenNl.o11Nood],
  ),
  const _Geval(
    'O11 nood verstuurd',
    HhPadenVeiligheid.probleem,
    HhRol.hulpvrager,
    stappen: [TekstenMeldingenNl.o11Nood, TekstenMeldingenNl.o11NoodJa],
  ),
  const _Geval(
    'O11 probleem',
    HhPadenVeiligheid.probleem,
    HhRol.hulpvrager,
    stappen: [TekstenMeldingenNl.o11Probleem],
  ),
  const _Geval(
    'O11 iets anders',
    HhPadenVeiligheid.probleem,
    HhRol.hulpvrager,
    stappen: [
      TekstenMeldingenNl.o11Probleem,
      TekstenMeldingenNl.o11KeuzeAnders,
    ],
  ),
  const _Geval(
    'O11 probleem verstuurd',
    HhPadenVeiligheid.probleem,
    HhRol.hulpvrager,
    stappen: [
      TekstenMeldingenNl.o11Probleem,
      TekstenMeldingenNl.o11KeuzeNietGekomen,
    ],
  ),
];

Future<FakeMeldingenGateway> _pomp(
  WidgetTester tester,
  _Geval geval, {
  HhDichtheid? dichtheid,
  double tekstschaal = 1.0,
}) async {
  final meldingen = fakeMeldingen(geval.meldingen?.call() ?? const []);
  await tester.pumpWidget(
    hhMeldingenWikkel(
      geval.pad,
      rol: geval.rol,
      meldingenGateway: meldingen,
      uitvoerGateway: fakeUitvoer(
        ikBen: geval.rol == HhRol.jongere ? jongereId : oudereId,
      ),
      dichtheid: dichtheid,
      tekstschaal: tekstschaal,
    ),
  );
  await tester.pumpAndSettle();
  for (final label in geval.stappen ?? const <String>[]) {
    await tikKnop(tester, label);
  }
  return meldingen;
}

/// Grote keuzes: elke knop behalve een kleine tekstknop.
int _groteKeuzes() => find
    .byType(HhKnop)
    .evaluate()
    .where((e) => (e.widget as HhKnop).soort != HhKnopSoort.tekst)
    .length;

void main() {
  group('elk M8-scherm rendert in beide dichtheden met semantiek', () {
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

  group('O10 en O11: hooguit drie grote keuzes, altijd terug', () {
    for (final geval in _gevallen.where((g) => g.rol == HhRol.hulpvrager)) {
      testWidgets(geval.naam, (tester) async {
        await _pomp(tester, geval);
        expect(_groteKeuzes(), lessThanOrEqualTo(3), reason: geval.naam);
        expect(find.text(TekstenNl.terug), findsOneWidget);
      });
    }

    // Mislukt bellen staat in hulpvrager/schermen_test (O10 met een opener
    // die faalt).
    testWidgets('O10: bellen dat lukt zet geen meldbalk neer', (tester) async {
      await tester.pumpWidget(
        hhMeldingenWikkel(HhPadenVeiligheid.belOns, rol: HhRol.hulpvrager),
      );
      await tester.pumpAndSettle();
      await tikKnop(tester, TekstenMeldingenNl.o10Bellen);
      expect(
        find.text(TekstenNl.hulpBellenLuktNiet(HhConfig.meldkamerTelefoon)),
        findsNothing,
      );
      expect(find.text(TekstenMeldingenNl.o10Openingstijden), findsOneWidget);
    });

    testWidgets('O11 terug vanaf nood bevestigen gaat naar de keuze', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[4]);
      await tester.tap(find.text(TekstenNl.terug));
      await tester.pumpAndSettle();
      expect(find.text(TekstenMeldingenNl.o11Vraag), findsOneWidget);
    });

    testWidgets('O11 voor de oudere met u, voor de jongere met je', (
      tester,
    ) async {
      await _pomp(tester, _gevallen[5]);
      expect(find.text(TekstenMeldingenNl.o11NoodVerstuurdU), findsOneWidget);
    });
  });

  group('meldingen-overzicht', () {
    testWidgets('nieuwste bovenaan, stip alleen bij ongelezen', (tester) async {
      await _pomp(tester, _gevallen[0]);
      final nieuw = tester.getTopLeft(find.text('Nieuwe klus in je buurt'));
      final oud = tester.getTopLeft(find.text('Klus afgerond'));
      expect(nieuw.dy, lessThan(oud.dy));
      expect(find.byKey(const ValueKey('ongelezen-stip')), findsOneWidget);
    });

    testWidgets('tik zet gelezen_op en opent de klus', (tester) async {
      final fake = await _pomp(tester, _gevallen[0]);
      await tester.tap(find.text('Nieuwe klus in je buurt'));
      await tester.pumpAndSettle();
      expect(fake.gelezenGezet, ['a']);
      // Weg van het overzicht, op J13 van de klus.
      expect(find.text(TekstenMeldingenNl.overzichtTitel), findsNothing);
    });

    testWidgets('leeg: rustig uitgelegd', (tester) async {
      await _pomp(tester, _gevallen[1]);
      expect(find.text(TekstenMeldingenNl.overzichtLeeg), findsOneWidget);
    });

    testWidgets('laadfout: opnieuw proberen', (tester) async {
      final fake = fakeMeldingen()..isOffline = true;
      await tester.pumpWidget(
        hhMeldingenWikkel(HhPadenMeldingen.overzicht, meldingenGateway: fake),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(TekstenMeldingenNl.overzichtLadenMislukt),
        findsOneWidget,
      );
      fake.isOffline = false;
      await tikKnop(tester, TekstenNl.opnieuwProberen);
      expect(find.text(TekstenMeldingenNl.overzichtLeeg), findsOneWidget);
    });
  });

  group('het belletje', () {
    testWidgets(
      'jongere: teller en schermlezer-tekst, tik opent het overzicht',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          hhMeldingenWikkel(
            HhPadenKlussen.mijnKlussen,
            meldingenGateway: fakeMeldingen(_voorJongere()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MeldingenBel), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
        expect(
          find.bySemanticsLabel(TekstenMeldingenNl.belSemantiek(1)),
          findsOneWidget,
        );
        await tester.tap(find.byType(MeldingenBel));
        await tester.pumpAndSettle();
        expect(find.text(TekstenMeldingenNl.overzichtTitel), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets('familie: het belletje staat op de landing', (tester) async {
      await tester.pumpWidget(
        hhMeldingenWikkel(HhPaden.familie, rol: HhRol.familie),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MeldingenBel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('oudere: geen belletje en geen teller op O1', (tester) async {
      await tester.pumpWidget(
        hhMeldingenWikkel(
          HhPaden.hulpvrager,
          rol: HhRol.hulpvrager,
          meldingenGateway: fakeMeldingen([testMelding(ontvanger: oudereId)]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MeldingenBel), findsNothing);
      expect(find.byType(LaatsteMeldingRegel), findsOneWidget);
      expect(find.text('Sanne is onderweg naar u.'), findsOneWidget);
    });

    testWidgets('oudere: alles gelezen, dan geen regel op O1', (tester) async {
      await tester.pumpWidget(
        hhMeldingenWikkel(
          HhPaden.hulpvrager,
          rol: HhRol.hulpvrager,
          meldingenGateway: fakeMeldingen([
            testMelding(ontvanger: oudereId, gelezen: true),
          ]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sanne is onderweg naar u.'), findsNothing);
    });

    testWidgets('oudere: O1 toont de nieuwste ONGELEZEN, niet de nieuwste', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhMeldingenWikkel(
          HhPaden.hulpvrager,
          rol: HhRol.hulpvrager,
          meldingenGateway: fakeMeldingen([
            testMelding(
              id: 'm2',
              ontvanger: oudereId,
              tekst: 'Nieuwste maar gelezen.',
              minutenGeleden: 1,
              gelezen: true,
            ),
            testMelding(ontvanger: oudereId, minutenGeleden: 10),
          ]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nieuwste maar gelezen.'), findsNothing);
      expect(find.text('Sanne is onderweg naar u.'), findsOneWidget);
    });
  });

  group('aanhaakpunten', () {
    testWidgets('O1: nog steeds drie grote knoppen, Bel ons opent O10', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhMeldingenWikkel(
          HhPaden.hulpvrager,
          rol: HhRol.hulpvrager,
          meldingenGateway: fakeMeldingen([testMelding(ontvanger: oudereId)]),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find
            .byType(HhKnop)
            .evaluate()
            .where((e) => (e.widget as HhKnop).soort != HhKnopSoort.tekst)
            .length,
        3,
      );
      await tikKnop(tester, TekstenHulpvragerNl.homeBelOns);
      expect(find.text(TekstenMeldingenNl.o10Bellen), findsOneWidget);
    });

    testWidgets('O1 zonder meldingen: geen regel', (tester) async {
      await tester.pumpWidget(
        hhMeldingenWikkel(HhPaden.hulpvrager, rol: HhRol.hulpvrager),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sanne is onderweg naar u.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final (status, zichtbaar) in [
      (HhKlusStatus.geaccepteerd, true),
      (HhKlusStatus.bezig, true),
      (HhKlusStatus.afgerond, false),
    ]) {
      testWidgets('J15 bij ${status.name}: "Probleem melden" '
          '${zichtbaar ? 'staat er' : 'staat er niet'}', (tester) async {
        await tester.pumpWidget(
          hhMeldingenWikkel(
            HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
            uitvoerGateway: fakeUitvoer(status: status),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(HhKnop, TekstenMeldingenNl.j15ProbleemMelden),
          zichtbaar ? findsOneWidget : findsNothing,
        );
      });
    }
  });
}
