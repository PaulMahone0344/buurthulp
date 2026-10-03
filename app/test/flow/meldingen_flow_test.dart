import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/pb/fake_incident_gateway.dart';
import 'package:heitjehulp_app/core/pb/incident_gateway.dart';
import 'package:heitjehulp_app/features/hulpvrager/veiligheid/paden_veiligheid.dart';
import 'package:heitjehulp_app/features/jongere/klussen/paden_klussen.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/paden_uitvoeren.dart';
import 'package:heitjehulp_app/features/meldingen/model/hh_melding.dart';
import 'package:heitjehulp_app/features/meldingen/widget/meldingen_bel.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/l10n/teksten_hulpvrager_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_meldingen_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_uitvoeren_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../support/hh_jongere_wikkel.dart';
import '../support/hh_meldingen_wikkel.dart';
import '../support/hh_uitvoeren_wikkel.dart';

void main() {
  group('O11 bij de oudere', () {
    testWidgets('nood: O1 -> Bel ons -> Probleem melden -> bevestigen -> '
        '"We bellen u zo snel mogelijk"', (tester) async {
      final incidenten = FakeIncidentGateway();
      await tester.pumpWidget(
        hhMeldingenWikkel(
          HhPaden.hulpvrager,
          rol: HhRol.hulpvrager,
          incidentGateway: incidenten,
          // Geen lopende klus: nood mag zonder.
          uitvoerGateway: fakeUitvoer(klussen: const [], ikBen: oudereId),
        ),
      );
      await tester.pumpAndSettle();

      await tikTekst(tester, TekstenHulpvragerNl.tabBelOns);
      await tikKnop(tester, TekstenMeldingenNl.o10ProbleemMelden);
      await tikKnop(tester, TekstenMeldingenNl.o11Nood);
      expect(incidenten.gemeld, isEmpty, reason: 'eerst bevestigen');
      await tikKnop(tester, TekstenMeldingenNl.o11NoodJa);

      expect(find.text(TekstenMeldingenNl.o11NoodVerstuurdU), findsOneWidget);
      expect(
        find.widgetWithText(Semantics, TekstenMeldingenNl.o10Titel),
        findsWidgets,
      );
      final gemeld = incidenten.gemeld.single;
      expect(gemeld.soort, IncidentSoort.nood);
      expect(gemeld.melderId, oudereId);
      expect(gemeld.klusId, isEmpty);
    });

    testWidgets('probleem: de lopende klus gaat mee', (tester) async {
      final incidenten = FakeIncidentGateway();
      await tester.pumpWidget(
        hhMeldingenWikkel(
          HhPadenVeiligheid.belOns,
          rol: HhRol.hulpvrager,
          incidentGateway: incidenten,
          uitvoerGateway: fakeUitvoer(
            status: HhKlusStatus.onderweg,
            ikBen: oudereId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tikKnop(tester, TekstenMeldingenNl.o10ProbleemMelden);
      await tikKnop(tester, TekstenMeldingenNl.o11Probleem);
      expect(find.text(TekstenMeldingenNl.o11MetKlus), findsOneWidget);
      await tikKnop(tester, TekstenMeldingenNl.o11KeuzeNietGekomen);

      expect(
        find.text(TekstenMeldingenNl.o11ProbleemVerstuurdU),
        findsOneWidget,
      );
      final gemeld = incidenten.gemeld.single;
      expect(gemeld.soort, IncidentSoort.probleem);
      expect(gemeld.klusId, 'k-uitvoeren');
      expect(gemeld.omschrijving, TekstenMeldingenNl.o11KeuzeNietGekomen);
    });

    testWidgets('geen verbinding: melding, knop blijft, daarna lukt het', (
      tester,
    ) async {
      final incidenten = FakeIncidentGateway()..isOffline = true;
      await tester.pumpWidget(
        hhMeldingenWikkel(
          HhPadenVeiligheid.probleem,
          rol: HhRol.hulpvrager,
          incidentGateway: incidenten,
        ),
      );
      await tester.pumpAndSettle();
      await tikKnop(tester, TekstenMeldingenNl.o11Nood);
      await tikKnop(tester, TekstenMeldingenNl.o11NoodJa);
      expect(find.text(TekstenMeldingenNl.o11Mislukt), findsOneWidget);
      expect(find.text(TekstenMeldingenNl.o11NoodVerstuurdU), findsNothing);

      incidenten.isOffline = false;
      await tikKnop(tester, TekstenMeldingenNl.o11NoodJa);
      expect(find.text(TekstenMeldingenNl.o11NoodVerstuurdU), findsOneWidget);
      expect(incidenten.gemeld, hasLength(1));
    });
  });

  group('O11 bij de jongere (vanaf J15)', () {
    testWidgets('bij bezig: zelf typen, met de klus erbij, "je"', (
      tester,
    ) async {
      final incidenten = FakeIncidentGateway();
      await tester.pumpWidget(
        hhMeldingenWikkel(
          HhPadenUitvoeren.uitvoeren('k-uitvoeren'),
          incidentGateway: incidenten,
          uitvoerGateway: fakeUitvoer(status: HhKlusStatus.bezig),
        ),
      );
      await tester.pumpAndSettle();

      await tikKnop(tester, TekstenMeldingenNl.j15ProbleemMelden);
      await tikKnop(tester, TekstenMeldingenNl.o11Probleem);
      await tikKnop(tester, TekstenMeldingenNl.o11KeuzeAnders);
      await vulVeld(tester, 0, 'De sleutel past niet');
      await tikKnop(tester, TekstenMeldingenNl.o11Versturen);

      expect(
        find.text(TekstenMeldingenNl.o11ProbleemVerstuurdJe),
        findsOneWidget,
      );
      final gemeld = incidenten.gemeld.single;
      expect(gemeld.melderId, jongereId);
      expect(gemeld.klusId, 'k-uitvoeren');
      expect(gemeld.omschrijving, 'De sleutel past niet');
    });

    testWidgets('te kort getypt: niets verstuurd', (tester) async {
      final incidenten = FakeIncidentGateway();
      await tester.pumpWidget(
        hhMeldingenWikkel(
          HhPadenVeiligheid.probleemBij('k-uitvoeren'),
          incidentGateway: incidenten,
        ),
      );
      await tester.pumpAndSettle();
      await tikKnop(tester, TekstenMeldingenNl.o11Probleem);
      await tikKnop(tester, TekstenMeldingenNl.o11KeuzeAnders);
      await vulVeld(tester, 0, 'x');
      await tikKnop(tester, TekstenMeldingenNl.o11Versturen);
      expect(incidenten.gemeld, isEmpty);
      expect(find.text(TekstenMeldingenNl.o11AndersTeKort), findsOneWidget);
    });
  });

  group('meldingen komen live binnen', () {
    testWidgets('jongere: via de stroom -> teller -> overzicht -> gelezen '
        '-> J15', (tester) async {
      final meldingen = fakeMeldingen();
      await tester.pumpWidget(
        hhMeldingenWikkel(
          HhPadenKlussen.mijnKlussen,
          meldingenGateway: meldingen,
          uitvoerGateway: fakeUitvoer(status: HhKlusStatus.geaccepteerd),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(TekstenMeldingenNl.belSemantiek(0)),
        findsOneWidget,
      );

      meldingen.zendUit(
        testMelding(
          id: 'live',
          ontvanger: jongereId,
          soort: HhMeldingSoort.toegewezen,
          titel: 'Je staat op een klus',
          tekst: 'De meldkamer heeft je gekoppeld.',
          minutenGeleden: 0,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(TekstenMeldingenNl.belSemantiek(1)),
        findsOneWidget,
      );

      await tester.tap(find.byType(MeldingenBel));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Je staat op een klus'));
      await tester.pumpAndSettle();

      expect(meldingen.gelezenGezet, ['live']);
      expect(find.text(TekstenUitvoerenNl.j15Titel), findsOneWidget);

      // Terug: het belletje staat weer op nul.
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text(TekstenNl.terug));
        await tester.pumpAndSettle();
      }
      expect(
        find.bySemanticsLabel(TekstenMeldingenNl.belSemantiek(0)),
        findsOneWidget,
      );
    });

    testWidgets('oudere: de nieuwe melding staat als regel op O1, tik opent '
        'O7', (tester) async {
      final meldingen = fakeMeldingen();
      await tester.pumpWidget(
        hhMeldingenWikkel(
          HhPaden.hulpvrager,
          rol: HhRol.hulpvrager,
          meldingenGateway: meldingen,
          uitvoerGateway: fakeUitvoer(
            status: HhKlusStatus.onderweg,
            ikBen: oudereId,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sanne is onderweg naar u.'), findsNothing);

      meldingen.zendUit(testMelding(ontvanger: oudereId, minutenGeleden: 0));
      await tester.pumpAndSettle();
      expect(find.text('Sanne is onderweg naar u.'), findsOneWidget);

      await tester.tap(find.text('Sanne is onderweg naar u.'));
      await tester.pumpAndSettle();
      expect(meldingen.gelezenGezet, ['m1']);
      expect(find.text(TekstenUitvoerenNl.o7Titel), findsOneWidget);
    });
  });
}
