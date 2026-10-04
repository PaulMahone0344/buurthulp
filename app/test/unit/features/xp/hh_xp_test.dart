import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/jongere/xp/domein/xp_tekst.dart';
import 'package:heitjehulp_app/features/jongere/xp/model/hh_xp.dart';

import '../../../support/hh_xp_data.dart';

void main() {
  group('HhXpOverzicht.vanJson', () {
    test('leest XP, niveau, volgend, badges, vertrouwen en verdiensten', () {
      final o = testXpOverzicht();
      expect(o.xpTotaal, 605);
      expect(o.niveau, const HhNiveau(code: 'ervaren', naam: 'Ervaren'));
      expect(o.volgend?.niveau.naam, 'Top');
      expect(o.volgend?.xpNodig, 395);
      expect(o.badges, hasLength(6));
      expect(o.badgesBehaald, 3);
      expect(o.badges.first.behaaldOp, DateTime.utc(2026, 9, 1, 8));
      expect(o.badges[2].isBehaald, isFalse);
      expect(o.vertrouwen.map((v) => v.code), ['ouder_toestemming', 'vog']);
      expect(o.verdiensten.bedragIn('2026-09'), 37.5);
      expect(o.verdiensten.bedragIn('2026'), 47.5);
      expect(o.verdiensten.bedragIn('2025'), 0);
    });

    test('een leeg of vreemd antwoord geeft nette lege waarden', () {
      final o = HhXpOverzicht.vanJson({
        'xp_totaal': 'veel',
        'badges': 'x',
        'niveau': null,
      });
      expect(o.xpTotaal, 0);
      expect(o.niveau, HhNiveau.nieuw);
      expect(o.volgend, isNull);
      expect(o.badges, isEmpty);
      expect(o.verdiensten.maanden, isEmpty);
    });

    test('de XP-balk volgt de grenzen van de server', () {
      final v = testXpOverzicht().volgend!;
      expect(v.voortgang(300), 0);
      expect(v.voortgang(650), 0.5);
      expect(v.voortgang(2000), 1);
      expect(const HhVolgendNiveau(niveau: HhNiveau.nieuw).voortgang(10), 1);
    });
  });

  group('HhBeloning.vanJson', () {
    test('zonder beloning in het antwoord: null', () {
      expect(HhBeloning.vanJson(null), isNull);
      expect(HhBeloning.vanJson('x'), isNull);
    });

    test('met beloning: XP, niveau omhoog en badges', () {
      final b = HhBeloning.vanJson({
        'xp_erbij': 75,
        'totaal': 75,
        'niveau': {'code': 'nieuw', 'naam': 'Nieuw'},
        'niveau_omhoog': false,
        'nieuwe_badges': [
          {
            'code': 'eerste_klus',
            'naam': 'Eerste klus',
            'uitleg': 'Je eerste klus is klaar.',
            'icoon': 'flag',
          },
        ],
      })!;
      expect(b.xpErbij, 75);
      expect(b.isNiveauOmhoog, isFalse);
      expect(b.nieuweBadges.single.naam, 'Eerste klus');
      expect(b.isIetsTeVieren, isTrue);
      expect(const HhBeloning().isIetsTeVieren, isFalse);
    });
  });

  test('HhVerklaring.vanJson leest de snapshot', () {
    final v = HhVerklaring.vanJson(testVerklaringJson);
    expect(v.code, 'ABCDE-FGH23');
    expect(v.voornaam, 'Daan');
    expect(v.klussen, 5);
    expect(v.uren, 6.5);
    expect(v.badges, [('Eerste klus', '2026-08-01')]);
    expect(v.vertrouwen.single.$1, 'VOG gezien');
  });

  group('xp_tekst', () {
    test('periode, euro, uren en datum in het Nederlands', () {
      expect(periodeTekst('2026-10'), 'oktober 2026');
      expect(periodeTekst('2026'), '2026');
      expect(periodeTekst('2026-13'), '2026-13');
      expect(euroVanBedrag(17.5), '€ 17,50');
      expect(euroVanBedrag(0), '€ 0,00');
      expect(urenTekst(5), '5');
      expect(urenTekst(1.25), '1,25');
      expect(datumTekst(DateTime(2026, 10, 1, 12)), '1 oktober 2026');
      expect(datumTekst(null), '');
      expect(maandSleutel(DateTime(2026, 3, 9)), '2026-03');
    });
  });
}
