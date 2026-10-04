import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/pb/fake_klus_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_reactie_gateway.dart';
import 'package:heitjehulp_app/core/pb/reactie_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/dichtheid_scope.dart';
import 'package:heitjehulp_app/features/chat/paden_chat.dart';
import 'package:heitjehulp_app/features/hulpvrager/screen/hulpvrager_home_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/paden_status.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/screen/hulpvraag_status_screen.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/status_routes.dart';
import 'package:heitjehulp_app/features/jongere/klussen/model/hh_klus.dart';
import 'package:heitjehulp_app/features/meldingen/domein/melding_domein.dart';
import 'package:heitjehulp_app/features/meldingen/model/hh_melding.dart';
import 'package:heitjehulp_app/features/reacties/model/hh_reactie.dart';
import 'package:heitjehulp_app/features/reacties/paden_reacties.dart';
import 'package:heitjehulp_app/features/reacties/reacties_routes.dart';
import 'package:heitjehulp_app/features/reacties/screen/kies_helper_screen.dart';
import 'package:heitjehulp_app/features/reacties/widget/helper_kaart.dart';
import 'package:heitjehulp_app/features/reacties/widget/helpers_kunnen_nu_regel.dart';
import 'package:heitjehulp_app/features/reacties/widget/initialen_avatar.dart';
import 'package:heitjehulp_app/features/reacties/widget/kan_nu_helpen_schakelaar.dart';
import 'package:heitjehulp_app/features/reacties/widget/match_sheet.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/features/jongere/klussen/paden_klussen.dart';
import 'package:heitjehulp_app/l10n/teksten_reacties_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../support/hh_hulpvrager_wikkel.dart';
import '../../../support/hh_jongere_wikkel.dart';
import '../../../support/hh_klussen_wikkel.dart';
import '../../../support/hh_toegang_wikkel.dart';
import '../../../support/hh_uitvoeren_wikkel.dart';

const _daan = HhReactieKaart(
  reactieId: 'r-daan',
  helperId: 'h-daan',
  voornaam: 'Daan',
  leeftijd: 14,
  sterren: 4.8,
  beoordelingen: 12,
  isIdGecontroleerd: true,
  laatsteRecensie: 'Heel netjes de heg geknipt.',
  bericht: 'Ik heb al vaker tuinen gedaan.',
);
const _sanne = HhReactieKaart(
  reactieId: 'r-sanne',
  helperId: 'h-sanne',
  voornaam: 'Sanne',
  leeftijd: 16,
);

HhKlus _openKlus({int reacties = 2}) => uitvoerKlus(
  id: 'k-open',
  status: HhKlusStatus.open,
  metJongere: false,
).copyWith(reactiesAantal: reacties);

/// De bewoner-kant met echte routes (KiesHelper, O7, chat-stub).
Future<FakeReactieGateway> _pompBewoner(
  WidgetTester tester, {
  required String pad,
  FakeReactieGateway? reacties,
  List<HhKlus>? klussen,
  double tekstschaal = 1.0,
}) async {
  final fake =
      reacties ??
      FakeReactieGateway(
        kaarten: {
          'k-open': [_daan, _sanne],
        },
      );
  final container = hulpvragerContainer(
    klusGateway: FakeKlusGateway(),
    sessie: SessieIngelogd(testGebruiker(HhRol.hulpvrager)),
    uitvoerGateway: fakeUitvoer(
      klussen: klussen ?? [_openKlus()],
      ikBen: oudereId,
    ),
    reactieGateway: fake,
  );
  final router = GoRouter(
    initialLocation: pad,
    routes: [
      GoRoute(
        path: HhPaden.hulpvrager,
        builder: (context, state) => const HulpvragerHomeScreen(),
      ),
      ...statusRoutes(),
      ...reactiesRoutes(),
      GoRoute(
        path: HhPadenChat.patroon,
        builder: (context, state) => const Scaffold(body: Text('CHAT')),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: hhThema(HhDichtheid.groot),
        routerConfig: router,
        builder: (context, kind) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(tekstschaal)),
          child: HhDichtheidScope(dichtheid: HhDichtheid.groot, child: kind!),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  group('KiesHelper (bewoner)', () {
    testWidgets('kaarten: initialen, voornaam + leeftijd, niveau, sterren, ID, '
        'recensie, berichtje; geen achternaam', (tester) async {
      await _pompBewoner(tester, pad: HhPadenReacties.kies('k-open'));
      expect(find.byType(KiesHelperScreen), findsOneWidget);
      expect(find.byType(HelperKaart), findsNWidgets(2));
      expect(find.text(TekstenReactiesNl.aantalReacties(2)), findsOneWidget);
      expect(find.text('Daan, 14'), findsOneWidget);
      expect(find.text('Nieuw'), findsNWidgets(2));
      expect(find.text('4,8 (12)'), findsOneWidget);
      expect(find.text(TekstenReactiesNl.idGecontroleerd), findsOneWidget);
      expect(find.text('“Heel netjes de heg geknipt.”'), findsOneWidget);
      expect(find.text('Ik heb al vaker tuinen gedaan.'), findsOneWidget);
      expect(find.text(TekstenReactiesNl.nogGeenBeoordeling), findsOneWidget);
      expect(find.byType(InitialenAvatar), findsNWidgets(2));
      expect(find.text('D'), findsOneWidget);
      // Geen foto's van mensen: geen enkel netwerkplaatje.
      expect(find.byType(Image), findsNothing);
    });

    testWidgets(
      'kiezen: eerst bevestigen, dan "Het is een match!" en de chat',
      (tester) async {
        final fake = await _pompBewoner(
          tester,
          pad: HhPadenReacties.kies('k-open'),
        );
        await tikKnop(tester, TekstenReactiesNl.kies('Daan'));
        expect(find.text(TekstenReactiesNl.kiesVraag('Daan')), findsOneWidget);
        // "Nog niet": er gebeurt niets.
        await tikTekst(tester, TekstenReactiesNl.kiesNee);
        expect(fake.gekozen, isEmpty);

        await tikKnop(tester, TekstenReactiesNl.kies('Daan'));
        await tikTekst(tester, TekstenReactiesNl.kiesJa);
        expect(fake.gekozen.single, (klusId: 'k-open', reactieId: 'r-daan'));
        expect(find.byType(MatchSheet), findsOneWidget);
        expect(find.text(TekstenReactiesNl.matchTitel), findsOneWidget);
        expect(
          find.textContaining('Daan helpt je met Boodschappen'),
          findsOneWidget,
        );
        expect(find.text(TekstenReactiesNl.matchUitleg), findsOneWidget);

        await tikKnop(tester, TekstenReactiesNl.openDeChat);
        expect(find.text('CHAT'), findsOneWidget);
      },
    );

    testWidgets('"Later" gaat naar de hulpvraag (O7)', (tester) async {
      await _pompBewoner(tester, pad: HhPadenReacties.kies('k-open'));
      await tikKnop(tester, TekstenReactiesNl.kies('Sanne'));
      await tikTekst(tester, TekstenReactiesNl.kiesJa);
      await tikKnop(tester, TekstenReactiesNl.later);
      expect(find.byType(HulpvraagStatusScreen), findsOneWidget);
    });

    testWidgets('een weigering toont de melding van de server', (tester) async {
      final fake =
          FakeReactieGateway(
              kaarten: {
                'k-open': [_daan],
              },
            )
            ..kiesUitkomst = const KiesGeweigerd(
              'helperbezet',
              'Deze helper heeft op dat moment al een andere klus. Kies iemand anders.',
            );
      await _pompBewoner(
        tester,
        pad: HhPadenReacties.kies('k-open'),
        reacties: fake,
      );
      await tikKnop(tester, TekstenReactiesNl.kies('Daan'));
      await tikTekst(tester, TekstenReactiesNl.kiesJa);
      expect(find.byType(MatchSheet), findsNothing);
      expect(find.textContaining('al een andere klus'), findsOneWidget);
    });

    testWidgets('zonder reacties een rustige lege staat', (tester) async {
      await _pompBewoner(
        tester,
        pad: HhPadenReacties.kies('k-open'),
        reacties: FakeReactieGateway(),
      );
      expect(find.text(TekstenReactiesNl.geenReacties), findsOneWidget);
    });

    testWidgets('op 200 procent zonder overloop', (tester) async {
      await _pompBewoner(
        tester,
        pad: HhPadenReacties.kies('k-open'),
        tekstschaal: 2.0,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ingangen bewoner', () {
    testWidgets('Start: "2 helpers willen je helpen" opent KiesHelper', (
      tester,
    ) async {
      await _pompBewoner(tester, pad: HhPaden.hulpvrager);
      expect(find.text(TekstenReactiesNl.helpersWillen(2)), findsOneWidget);
      await tikKnop(tester, TekstenReactiesNl.bekijkReacties);
      expect(find.byType(KiesHelperScreen), findsOneWidget);
    });

    testWidgets('Start zonder reacties: geen kaart', (tester) async {
      await _pompBewoner(
        tester,
        pad: HhPaden.hulpvrager,
        klussen: [_openKlus(reacties: 0)],
      );
      expect(find.text(TekstenReactiesNl.bekijkReacties), findsNothing);
    });

    testWidgets('plaatsen: "4 helpers kunnen nu helpen", 0 = niets', (
      tester,
    ) async {
      Future<FakeReactieGateway> pomp(int aantal) async {
        final fake = FakeReactieGateway(aantalNu: aantal);
        final container = hulpvragerContainer(
          klusGateway: FakeKlusGateway(),
          sessie: SessieIngelogd(testGebruiker(HhRol.hulpvrager)),
          reactieGateway: fake,
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: hhThema(HhDichtheid.groot),
              home: Scaffold(
                body: HelpersKunnenNuRegel(
                  klustypeId: 't-tuin',
                  van: DateTime.utc(2026, 10, 10, 8),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return fake;
      }

      final fake = await pomp(4);
      expect(find.text(TekstenReactiesNl.helpersKunnenNu(4)), findsOneWidget);
      expect(fake.geteld.single.klustypeId, 't-tuin');
      // Weg en de tijd laten lopen: geen timer van autoDispose over.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('plaatsen: bij 0 helpers geen regel', (tester) async {
      final container = hulpvragerContainer(
        klusGateway: FakeKlusGateway(),
        sessie: SessieIngelogd(testGebruiker(HhRol.hulpvrager)),
        reactieGateway: FakeReactieGateway(),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: hhThema(HhDichtheid.groot),
            home: const Scaffold(
              body: HelpersKunnenNuRegel(klustypeId: 't-tuin'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('kunnen nu'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('O7 bij een open klus met reacties: knop naar KiesHelper', (
      tester,
    ) async {
      await _pompBewoner(tester, pad: HhPadenStatus.hulpvraag('k-open'));
      await tikKnop(tester, TekstenReactiesNl.helpersWillen(2));
      expect(find.byType(KiesHelperScreen), findsOneWidget);
    });
  });

  group('helper', () {
    testWidgets('"Ik kan nu helpen": aan tot over 3 uur, en weer uit', (
      tester,
    ) async {
      final fake = FakeReactieGateway(klok: () => klussenNu);
      final container = klussenContainer(
        klussenGateway: fakeKlussen(),
        sessie: SessieIngelogd(testGebruiker(HhRol.jongere)),
        reactieGateway: fake,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: hhThema(HhDichtheid.normaal),
            home: const Scaffold(body: KanNuHelpenSchakelaar()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(TekstenReactiesNl.nuHelpenUit), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(fake.beschikbaarGezet, [true]);
      expect(find.textContaining('Aan tot'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(fake.beschikbaarGezet, [true, false]);
      expect(find.text(TekstenReactiesNl.nuHelpenUit), findsOneWidget);
    });

    testWidgets('Start helper toont de schakelaar boven de lijst', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhKlussenWikkel(HhPaden.jongere, klussenGateway: fakeKlussen()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(KanNuHelpenSchakelaar), findsOneWidget);
    });

    testWidgets('J13 met een eigen reactie: "Je hebt gereageerd", geen knop', (
      tester,
    ) async {
      final open = testKlus(
        id: 'k-r',
      ).copyWith(mijnReactie: 'open', reactiesAantal: 3);
      await tester.pumpWidget(
        hhKlussenWikkel(
          HhPadenKlussen.klusDetail('k-r'),
          klussenGateway: fakeKlussen(open: [open]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(TekstenReactiesNl.gereageerdKop), findsOneWidget);
      expect(
        find.widgetWithText(HhKnop, TekstenReactiesNl.reageerKnop),
        findsNothing,
      );
    });

    testWidgets('J13 open klus: "3 helpers reageerden al"', (tester) async {
      final open = testKlus(id: 'k-r').copyWith(reactiesAantal: 3);
      await tester.pumpWidget(
        hhKlussenWikkel(
          HhPadenKlussen.klusDetail('k-r'),
          klussenGateway: fakeKlussen(open: [open]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(TekstenReactiesNl.alReacties(3)), findsOneWidget);
    });
  });

  group('meldingen', () {
    HhMelding melding() => const HhMelding(
      id: 'm1',
      ontvangerId: 'x',
      soort: HhMeldingSoort.reactie,
      klusId: 'k1',
      titel: 'Daan wil je helpen',
    );

    test('soort "reactie" bestaat en heeft een titel', () {
      expect(HhMeldingSoort.vanCode('reactie'), HhMeldingSoort.reactie);
      expect(titelVan(melding(), HhRol.hulpvrager), 'Daan wil je helpen');
    });

    test('bewoner -> KiesHelper, helper -> Mijn klussen', () {
      expect(doelVan(melding(), HhRol.hulpvrager), HhPadenReacties.kies('k1'));
      expect(doelVan(melding(), HhRol.jongere), HhPadenKlussen.mijnKlussen);
    });
  });
}
