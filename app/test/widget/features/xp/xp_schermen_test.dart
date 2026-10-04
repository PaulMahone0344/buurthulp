// B9: Profiel (niveau, XP-balk, badges, vertrouwen, verdiensten), "Mijn
// verdiensten", de Verklaring van inzet en HBeloning na "Klaar". Alle
// getallen komen uit de fake (zoals ze van de server zouden komen).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/pb/fake_xp_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/theme.dart';
import 'package:heitjehulp_app/features/jongere/klussen/paden_klussen.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/paden_uitvoeren.dart';
import 'package:heitjehulp_app/features/jongere/xp/model/hh_xp.dart';
import 'package:heitjehulp_app/features/jongere/xp/screen/beloning_screen.dart';
import 'package:heitjehulp_app/l10n/teksten_beoordelen_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_uitvoeren_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_xp_nl.dart';

import '../../../support/hh_beoordelen_wikkel.dart';
import '../../../support/hh_jongere_wikkel.dart';
import '../../../support/hh_uitvoeren_wikkel.dart';
import '../../../support/hh_xp_data.dart';

Future<FakeXpGateway> _profiel(WidgetTester tester, {FakeXpGateway? xp}) async {
  final fake = xp ?? FakeXpGateway(overzicht: testXpOverzicht());
  await tester.pumpWidget(
    hhReputatieWikkel(
      HhPadenKlussen.profiel,
      uitvoerGateway: fakeUitvoer(),
      beoordelingGateway: fakeBeoordeling(),
      xpGateway: fake,
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

Future<void> _scrollNaar(WidgetTester tester, Finder doel) async {
  await tester.scrollUntilVisible(
    doel,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Profiel (HProfiel)', () {
    testWidgets('niveau, XP en wat er nog nodig is, van de server', (
      tester,
    ) async {
      await _profiel(tester);
      expect(find.text('Ervaren'), findsOneWidget);
      expect(find.text(TekstenXpNl.xpTotaal(605)), findsOneWidget);
      expect(
        find.text(
          'Nog 395 XP tot Top en nog 10 klussen en gemiddeld 4,5 sterren.',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(TekstenXpNl.balkSemantiek(605, 1000, 'Top')),
        findsOneWidget,
      );
    });

    testWidgets('badges: teller en behaald met datum / nog niet', (
      tester,
    ) async {
      await _profiel(tester);
      await _scrollNaar(tester, find.text(TekstenXpNl.badgesKop));
      expect(find.text(TekstenXpNl.badgesTeller(3, 6)), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          TekstenXpNl.badgeSemantiek(
            'Eerste klus',
            TekstenXpNl.behaaldOp('1 september 2026'),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          TekstenXpNl.badgeSemantiek('10 klussen', TekstenXpNl.nogNiet),
        ),
        findsOneWidget,
      );
    });

    testWidgets('vertrouwen met datum; een verlopen VOG zegt het', (
      tester,
    ) async {
      await _profiel(tester);
      await _scrollNaar(tester, find.text(TekstenXpNl.vertrouwenKop));
      expect(find.text(TekstenXpNl.sinds('20 augustus 2026')), findsOneWidget);
      expect(
        find.text(TekstenXpNl.geldigTot('1 september 2029')),
        findsOneWidget,
      );

      await _profiel(
        tester,
        xp: FakeXpGateway(overzicht: testXpOverzicht(verlopenVog: true)),
      );
      await _scrollNaar(tester, find.text(TekstenXpNl.vertrouwenKop));
      expect(
        find.text(TekstenXpNl.verlopenOp('1 september 2026')),
        findsOneWidget,
      );
    });

    testWidgets(
      'verdiensten: deze maand en dit jaar; alle maanden op een eigen scherm',
      (tester) async {
        await _profiel(tester);
        await _scrollNaar(tester, find.text(TekstenXpNl.alleVerdiensten));
        expect(
          find.text('€ 37,50'),
          findsOneWidget,
        ); // september 2026 (testklok)
        expect(find.text('€ 47,50'), findsOneWidget); // 2026
        await tikKnop(tester, TekstenXpNl.alleVerdiensten);
        expect(find.text(TekstenXpNl.verdienstenTitel), findsOneWidget);
        expect(find.text('september 2026'), findsOneWidget);
        expect(find.text('augustus 2026'), findsOneWidget);
        expect(find.text(TekstenXpNl.klussenAantal(4)), findsOneWidget);
      },
    );

    testWidgets('verklaring van inzet: code van de server', (tester) async {
      final fake = FakeXpGateway(
        overzicht: testXpOverzicht(),
        verklaring: HhVerklaring.vanJson(testVerklaringJson),
      );
      await _profiel(tester, xp: fake);
      await _scrollNaar(tester, find.text(TekstenXpNl.verklaringKnop));
      await tikKnop(tester, TekstenXpNl.verklaringKnop);
      expect(fake.verklaringenGemaakt, 1);
      expect(find.text('ABCDE-FGH23'), findsOneWidget);
      expect(find.text(TekstenXpNl.verklaringZin('Daan', 5)), findsOneWidget);
      expect(find.text(TekstenXpNl.uren('6,5')), findsOneWidget);
      await tikKnop(tester, TekstenXpNl.openOpWebsite);
      expect(find.text(TekstenXpNl.openMislukt), findsNothing);
    });

    testWidgets('laden mislukt: lege staat, opnieuw proberen werkt', (
      tester,
    ) async {
      final fake = FakeXpGateway(overzicht: testXpOverzicht())
        ..isOffline = true;
      await _profiel(tester, xp: fake);
      expect(find.text(TekstenXpNl.ladenMislukt), findsOneWidget);
      // De reputatie (M7) staat er gewoon.
      expect(find.text(TekstenBeoordelenNl.j19ReputatieKop), findsOneWidget);
      fake.isOffline = false;
      await tikKnop(tester, 'Opnieuw proberen');
      expect(find.text(TekstenXpNl.xpTotaal(605)), findsOneWidget);
    });
  });

  group('HBeloning na "Klaar"', () {
    testWidgets(
      'afgerond met beloning: +XP, nieuw niveau en badge; Top! gaat terug',
      (tester) async {
        final fake = fakeUitvoer(status: HhKlusStatus.bezig)
          ..beloningBijAfgerond = testBeloning;
        await tester.pumpWidget(
          hhReputatieWikkel(
            HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
            uitvoerGateway: fake,
            beoordelingGateway: fakeBeoordeling(),
          ),
        );
        await tester.pumpAndSettle();
        await tikKnop(tester, TekstenUitvoerenNl.j15KnopAfgerond);

        expect(find.byType(BeloningScreen), findsOneWidget);
        expect(find.text(TekstenXpNl.xpErbij(125)), findsOneWidget);
        expect(find.text(TekstenXpNl.nieuwNiveau('Ervaren')), findsOneWidget);
        expect(find.text('5 klussen'), findsOneWidget);
        expect(find.text('Vijf klussen gedaan.'), findsOneWidget);

        await tikKnop(tester, TekstenXpNl.top);
        expect(find.byType(BeloningScreen), findsNothing);
        expect(find.text(TekstenUitvoerenNl.j15Afgerond), findsOneWidget);
        expect(
          find.widgetWithText(HhKnop, TekstenBeoordelenNl.j15Beoordelen),
          findsOneWidget,
        );
      },
    );

    testWidgets('zonder beloning (oude server): gewoon de eindstaat', (
      tester,
    ) async {
      final fake = fakeUitvoer(status: HhKlusStatus.bezig);
      await tester.pumpWidget(
        hhReputatieWikkel(
          HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
          uitvoerGateway: fake,
          beoordelingGateway: fakeBeoordeling(),
        ),
      );
      await tester.pumpAndSettle();
      await tikKnop(tester, TekstenUitvoerenNl.j15KnopAfgerond);
      expect(find.byType(BeloningScreen), findsNothing);
      expect(find.text(TekstenUitvoerenNl.j15Afgerond), findsOneWidget);
    });

    testWidgets('met "verminder beweging" staat alles meteen (geen animatie)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: hhReputatieWikkel(
            HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
            uitvoerGateway: fakeUitvoer(status: HhKlusStatus.bezig)
              ..beloningBijAfgerond = const HhBeloning(xpErbij: 50, totaal: 50),
            beoordelingGateway: fakeBeoordeling(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tikKnop(tester, TekstenUitvoerenNl.j15KnopAfgerond);
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
      expect(find.text(TekstenXpNl.xpErbij(50)), findsOneWidget);
    });
  });
}
