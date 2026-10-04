import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/core/pb/fake_uitvoer_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/components/hh_meld_balk.dart';
import 'package:heitjehulp_app/features/chat/model/hh_bericht.dart';
import 'package:heitjehulp_app/features/chat/paden_chat.dart';
import 'package:heitjehulp_app/features/chat/widget/bericht_bubbel.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/paden_status.dart';
import 'package:heitjehulp_app/features/hulpvrager/veiligheid/screen/probleem_melden_screen.dart';
import 'package:heitjehulp_app/features/jongere/klussen/paden_klussen.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/model/hh_klus_logregel.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/l10n/teksten_chat_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_uitvoeren_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../support/hh_chat_wikkel.dart';
import '../../../support/hh_jongere_wikkel.dart' show jongereId;
import '../../../support/hh_klussen_wikkel.dart' show testMijnKlussen;
import '../../../support/hh_uitvoeren_wikkel.dart';

final _pad = HhPadenChat.chat('k-uitvoeren');

/// Een afgelopen klus waarvan de laatste stap [geleden] terug is.
FakeUitvoerGateway _afgelopen(Duration geleden, {String? ikBen}) {
  final klus = uitvoerKlus(status: HhKlusStatus.afgerond);
  final fake = FakeUitvoerGateway(
    klussen: [klus],
    logregels: [
      HhKlusLogregel(
        id: 'log-af',
        klusId: klus.id,
        van: HhKlusStatus.bezig,
        naar: HhKlusStatus.afgerond,
        wanneer: uitvoerNu.subtract(geleden),
      ),
    ],
    ikBenId: ikBen ?? jongereId,
    klok: uitvoerNu,
  );
  addTearDown(fake.sluit);
  return fake;
}

void main() {
  group('B6 chatscherm (helper)', () {
    testWidgets(
      'kop: voornaam van de bewoner, klus eronder, meldknop en infobalk',
      (tester) async {
        await tester.pumpWidget(hhChatWikkel(_pad, chatGateway: fakeChat()));
        await tester.pumpAndSettle();
        expect(find.text('Mevrouw'), findsOneWidget);
        expect(find.textContaining('Boodschappen · '), findsOneWidget);
        expect(find.byTooltip(TekstenChatNl.meldProbleem), findsOneWidget);
        expect(find.text(TekstenChatNl.verborgen), findsOneWidget);
        expect(find.text(TekstenChatNl.leeg), findsOneWidget);
      },
    );

    testWidgets('snelknoppen van de helper; een snelknop wisselt geen status', (
      tester,
    ) async {
      final chat = fakeChat();
      final uitvoer = fakeUitvoer(ikBen: jongereId);
      await tester.pumpWidget(
        hhChatWikkel(_pad, chatGateway: chat, uitvoerGateway: uitvoer),
      );
      await tester.pumpAndSettle();
      for (final label in TekstenChatNl.snelHelper) {
        expect(find.widgetWithText(OutlinedButton, label), findsOneWidget);
      }
      for (final label in TekstenChatNl.snelBewoner) {
        expect(find.widgetWithText(OutlinedButton, label), findsNothing);
      }
      await tester.tap(find.widgetWithText(OutlinedButton, 'Ik ben onderweg'));
      await tester.pumpAndSettle();
      expect(chat.verstuurd.single.tekst, 'Ik ben onderweg');
      expect(chat.verstuurd.single.soort, HhBerichtSoort.snel);
      expect(uitvoer.aantalStatusStappen, 0);
      expect(find.byType(BerichtBubbel), findsOneWidget);
    });

    testWidgets('typen en versturen: bubbel erbij, veld leeg', (tester) async {
      final chat = fakeChat();
      await tester.pumpWidget(hhChatWikkel(_pad, chatGateway: chat));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Ik neem een tas mee  ');
      await tester.tap(find.byTooltip(TekstenChatNl.verstuur));
      await tester.pumpAndSettle();
      expect(chat.verstuurd.single.tekst, 'Ik neem een tas mee');
      expect(chat.verstuurd.single.soort, HhBerichtSoort.tekst);
      expect(find.text('Ik neem een tas mee'), findsOneWidget);
      final veld = tester.widget<TextField>(find.byType(TextField));
      expect(veld.controller?.text, isEmpty);
    });

    testWidgets('leeg bericht wordt niet verstuurd', (tester) async {
      final chat = fakeChat();
      await tester.pumpWidget(hhChatWikkel(_pad, chatGateway: chat));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byTooltip(TekstenChatNl.verstuur));
      await tester.pumpAndSettle();
      expect(chat.verstuurd, isEmpty);
    });

    testWidgets(
      'realtime: bericht van de bewoner verschijnt en wordt gelezen',
      (tester) async {
        final chat = fakeChat([
          testBericht(id: 'eigen', tekst: 'Ik kom om twee'),
        ]);
        await tester.pumpWidget(hhChatWikkel(_pad, chatGateway: chat));
        await tester.pumpAndSettle();
        chat.zendUit(
          testBericht(
            id: 'van-bewoner',
            afzender: oudereId,
            tekst: 'De poort zit aan de zijkant.',
            minutenGeleden: 1,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('De poort zit aan de zijkant.'), findsOneWidget);
        expect(chat.gelezenGezet, contains('van-bewoner'));
        expect(chat.gelezenGezet, isNot(contains('eigen')));
      },
    );

    testWidgets('eigen bericht dat de ander las: "Gelezen" eronder', (
      tester,
    ) async {
      final chat = fakeChat([
        testBericht(
          id: 'a',
          tekst: 'Eerste',
          minutenGeleden: 20,
          gelezen: true,
        ),
        testBericht(id: 'b', tekst: 'Tweede', minutenGeleden: 10),
      ]);
      await tester.pumpWidget(hhChatWikkel(_pad, chatGateway: chat));
      await tester.pumpAndSettle();
      expect(find.textContaining(TekstenChatNl.gelezen), findsOneWidget);
    });

    testWidgets('account van de ander verwijderd: "Bericht verwijderd"', (
      tester,
    ) async {
      final chat = fakeChat([
        testBericht(afzender: '', tekst: '', gewist: true),
      ]);
      await tester.pumpWidget(hhChatWikkel(_pad, chatGateway: chat));
      await tester.pumpAndSettle();
      expect(find.text(TekstenChatNl.berichtVerwijderd), findsOneWidget);
    });

    testWidgets('gesprek verwijderen: vragen, dan weg (alleen voor mij)', (
      tester,
    ) async {
      final chat = fakeChat([testBericht(tekst: 'Ik kom om twee')]);
      await tester.pumpWidget(hhChatWikkel(_pad, chatGateway: chat));
      await tester.pumpAndSettle();
      expect(find.text('Ik kom om twee'), findsOneWidget);

      // Annuleren: er gebeurt niets.
      await tester.tap(find.text(TekstenChatNl.gesprekVerwijderen));
      await tester.pumpAndSettle();
      expect(find.text(TekstenChatNl.verwijderVraag), findsOneWidget);
      await tester.tap(find.widgetWithText(HhKnop, TekstenChatNl.verwijderNee));
      await tester.pumpAndSettle();
      expect(chat.verborgenKlussen, isEmpty);
      expect(find.text('Ik kom om twee'), findsOneWidget);

      await tester.tap(find.text(TekstenChatNl.gesprekVerwijderen));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(HhKnop, TekstenChatNl.verwijderJa));
      await tester.pumpAndSettle();
      expect(chat.verborgenKlussen, ['k-uitvoeren']);
      expect(find.text('Ik kom om twee'), findsNothing);
      expect(find.text(TekstenChatNl.gesprekVerwijderd), findsOneWidget);
    });

    testWidgets(
      'gesprek verwijderen bij een lopende melding: uitleg, niets weg',
      (tester) async {
        final chat = fakeChat([testBericht(tekst: 'Ik kom om twee')])
          ..isIncident = true;
        await tester.pumpWidget(hhChatWikkel(_pad, chatGateway: chat));
        await tester.pumpAndSettle();
        await tester.tap(find.text(TekstenChatNl.gesprekVerwijderen));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(HhKnop, TekstenChatNl.verwijderJa),
        );
        await tester.pumpAndSettle();
        expect(find.text(TekstenChatNl.verwijderIncident), findsOneWidget);
        expect(find.text('Ik kom om twee'), findsOneWidget);
      },
    );

    testWidgets('weggefilterd: korte uitleg in de bubbel', (tester) async {
      final chat = fakeChat([
        testBericht(
          afzender: oudereId,
          tekst: 'Bel me op •••',
          gefilterd: true,
        ),
      ]);
      await tester.pumpWidget(hhChatWikkel(_pad, chatGateway: chat));
      await tester.pumpAndSettle();
      expect(find.text('Bel me op •••'), findsOneWidget);
      expect(find.text(TekstenChatNl.filterUitleg), findsOneWidget);
    });

    testWidgets(
      'de server weigert (dicht): invoer weg, "Deze chat is gesloten."',
      (tester) async {
        final chat = fakeChat()..isGesloten = true;
        await tester.pumpWidget(hhChatWikkel(_pad, chatGateway: chat));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Hallo');
        await tester.tap(find.byTooltip(TekstenChatNl.verstuur));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(find.text(TekstenChatNl.gesloten), findsOneWidget);
      },
    );

    testWidgets('geen verbinding bij versturen: foutbalk, tekst blijft staan', (
      tester,
    ) async {
      final chat = fakeChat();
      await tester.pumpWidget(hhChatWikkel(_pad, chatGateway: chat));
      await tester.pumpAndSettle();
      chat.volgendeFout = const HhFout(HhFoutSoort.geenVerbinding);
      await tester.enterText(find.byType(TextField), 'Hallo');
      await tester.tap(find.byTooltip(TekstenChatNl.verstuur));
      await tester.pumpAndSettle();
      expect(find.byType(HhMeldBalk), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      final veld = tester.widget<TextField>(find.byType(TextField));
      expect(veld.controller?.text, 'Hallo');
    });

    testWidgets('meldknop opent het bestaande meldpad (O11) met de klus', (
      tester,
    ) async {
      await tester.pumpWidget(hhChatWikkel(_pad, chatGateway: fakeChat()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(TekstenChatNl.meldProbleem));
      await tester.pumpAndSettle();
      final scherm = tester.widget<ProbleemMeldenScreen>(
        find.byType(ProbleemMeldenScreen),
      );
      expect(scherm.klusId, 'k-uitvoeren');
    });

    testWidgets('terug in de app: gesprek opnieuw geladen', (tester) async {
      final chat = fakeChat();
      await tester.pumpWidget(hhChatWikkel(_pad, chatGateway: chat));
      await tester.pumpAndSettle();
      final voor = chat.aantalLaadacties;
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pumpAndSettle();
      expect(chat.aantalLaadacties, greaterThan(voor));
    });
  });

  group('B6 open of dicht', () {
    testWidgets('afgerond 4 dagen geleden: alleen lezen', (tester) async {
      final chat = fakeChat([testBericht(tekst: 'Bedankt!')]);
      await tester.pumpWidget(
        hhChatWikkel(
          _pad,
          chatGateway: chat,
          uitvoerGateway: _afgelopen(const Duration(days: 4)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bedankt!'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text(TekstenChatNl.gesloten), findsOneWidget);
      for (final label in TekstenChatNl.snelHelper) {
        expect(find.text(label), findsNothing);
      }
    });

    testWidgets('afgerond 2 uur geleden: nog open', (tester) async {
      await tester.pumpWidget(
        hhChatWikkel(
          _pad,
          chatGateway: fakeChat(),
          uitvoerGateway: _afgelopen(const Duration(hours: 2)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(TekstenChatNl.gesloten), findsNothing);
    });

    testWidgets('klus zonder helper: dicht, geen gesprek geladen', (
      tester,
    ) async {
      final chat = fakeChat();
      final uitvoer = fakeUitvoer(
        klussen: [uitvoerKlus(status: HhKlusStatus.open, metJongere: false)],
        ikBen: oudereId,
      );
      await tester.pumpWidget(
        hhChatWikkel(
          _pad,
          rol: HhRol.hulpvrager,
          chatGateway: chat,
          uitvoerGateway: uitvoer,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(TekstenChatNl.gesloten), findsOneWidget);
      expect(chat.aantalLaadacties, 0);
    });
  });

  group('B6 chatscherm (bewoner)', () {
    testWidgets('naam van de helper en de snelknoppen van de bewoner', (
      tester,
    ) async {
      await tester.pumpWidget(
        hhChatWikkel(
          _pad,
          rol: HhRol.hulpvrager,
          chatGateway: fakeChat(),
          dichtheid: HhDichtheid.groot,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sanne'), findsOneWidget);
      for (final label in TekstenChatNl.snelBewoner) {
        expect(find.widgetWithText(OutlinedButton, label), findsOneWidget);
      }
    });

    testWidgets('200% tekst op 320 breed: geen overloop', (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        hhChatWikkel(
          _pad,
          rol: HhRol.hulpvrager,
          chatGateway: fakeChat([
            testBericht(
              tekst:
                  'Hoi! Ik kom zaterdag om tien uur. Moet ik zelf een schaar meenemen?',
            ),
          ]),
          dichtheid: HhDichtheid.groot,
          tekstschaal: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('B6 ingangen', () {
    testWidgets('Mijn klussen: Chat-knop met teller bij een klus met helper', (
      tester,
    ) async {
      final chat = fakeChat([
        testBericht(id: 'x1', klus: 'm-vandaag', afzender: oudereId),
        testBericht(id: 'x2', klus: 'm-vandaag', afzender: oudereId),
      ])..helperVanKlus = {'m-vandaag': jongereId, 'm-gepland': jongereId};
      await tester.pumpWidget(
        hhChatWikkel(
          HhPadenKlussen.mijnKlussen,
          chatGateway: chat,
          mijnKlussen: testMijnKlussen(),
        ),
      );
      await tester.pumpAndSettle();
      // B5: vandaag en later staan samen bij Gepland; elke klus met een
      // helper heeft een Chat-knop, alleen die van vandaag heeft berichten.
      expect(find.widgetWithText(HhKnop, TekstenChatNl.chat), findsNWidgets(2));
      expect(find.text('2'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('2 nieuwe berichten')),
        findsOneWidget,
      );

      // Live: een derde bericht verhoogt de teller.
      chat.zendUit(
        testBericht(id: 'x3', klus: 'm-vandaag', afzender: oudereId),
      );
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.widgetWithText(HhKnop, TekstenChatNl.chat).first);
      await tester.pumpAndSettle();
      expect(find.text(TekstenChatNl.verborgen), findsOneWidget);
    });

    testWidgets(
      'O7 (bewoner): chat in plaats van Vernieuwen, hooguit drie knoppen',
      (tester) async {
        await tester.pumpWidget(
          hhChatWikkel(
            HhPadenStatus.hulpvraag('k-uitvoeren'),
            rol: HhRol.hulpvrager,
            chatGateway: fakeChat(),
            uitvoerGateway: fakeUitvoer(
              ikBen: oudereId,
              status: HhKlusStatus.onderweg,
            ),
            dichtheid: HhDichtheid.groot,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(HhKnop, TekstenChatNl.chatMet('Sanne')),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(HhKnop, TekstenUitvoerenNl.o7Vernieuwen),
          findsNothing,
        );
        expect(find.byType(HhKnop).evaluate().length, lessThanOrEqualTo(3));
      },
    );

    testWidgets('O7 zonder helper: geen chat, wel Vernieuwen', (tester) async {
      await tester.pumpWidget(
        hhChatWikkel(
          HhPadenStatus.hulpvraag('k-uitvoeren'),
          rol: HhRol.hulpvrager,
          chatGateway: fakeChat(),
          uitvoerGateway: fakeUitvoer(
            klussen: [
              uitvoerKlus(status: HhKlusStatus.open, metJongere: false),
            ],
            ikBen: oudereId,
          ),
          dichtheid: HhDichtheid.groot,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(TekstenChatNl.chat), findsNothing);
      expect(
        find.widgetWithText(HhKnop, TekstenUitvoerenNl.o7Vernieuwen),
        findsOneWidget,
      );
    });
  });
}
