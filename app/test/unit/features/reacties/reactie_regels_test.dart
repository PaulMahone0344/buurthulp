import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/reacties/domein/reactie_regels.dart';
import 'package:heitjehulp_app/features/reacties/model/hh_reactie.dart';
import 'package:heitjehulp_app/l10n/teksten_reacties_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import 'package:heitjehulp_app/features/jongere/klussen/model/hh_klus.dart';

HhReactie _r(
  String id,
  HhReactieStatus status,
  int minuut, {
  String besluit = '',
}) => HhReactie(
  id: id,
  klusId: 'k-$id',
  helperId: 'h',
  status: status,
  ouderBesluit: besluit,
  gemaakt: DateTime.utc(2026, 10, 4, 10, minuut),
);

void main() {
  test('initialen: eerste letter, hoofdletter; zonder naam een vraagteken', () {
    expect(initialen('daan'), 'D');
    expect(initialen('  Sanne '), 'S');
    expect(initialen(''), '?');
  });

  test('sterrenKort: "4,8 (12)", zonder beoordeling een zin', () {
    expect(sterrenKort(4.8, 12), '4,8 (12)');
    expect(sterrenKort(5, 1), '5,0 (1)');
    expect(sterrenKort(0, 0), TekstenReactiesNl.nogGeenBeoordeling);
  });

  test('leeftijdOp: verjaardag telt op de dag zelf', () {
    final geboren = DateTime.utc(2015, 10, 4);
    expect(leeftijdOp(geboren, DateTime(2026, 10, 3)), 10);
    expect(leeftijdOp(geboren, DateTime(2026, 10, 4)), 11);
    expect(leeftijdOp(null, DateTime(2026, 10, 4)), isNull);
  });

  test('eerste klus bij een bewoner: alleen echte klussen tellen', () {
    final mijn = [
      const HhKlus(id: 'a', hulpvragerId: 'b1', status: HhKlusStatus.afgerond),
      const HhKlus(
        id: 'b',
        hulpvragerId: 'b2',
        status: HhKlusStatus.geannuleerd,
      ),
    ];
    expect(isEersteKlusBij(mijn, 'b1'), isFalse);
    expect(
      isEersteKlusBij(mijn, 'b2'),
      isTrue,
      reason: 'geannuleerd telt niet',
    );
    expect(isEersteKlusBij(mijn, 'b3'), isTrue);
  });

  test(
    'punt 10: vinkje verplicht voor 10-12, tip voor 13-17, niets voor 18+',
    () {
      for (final jaren in [10, 11, 12]) {
        expect(moetOuderMeeVinkje(leeftijd: jaren, isEerste: true), isTrue);
        expect(toonOuderMeeTip(leeftijd: jaren, isEerste: true), isFalse);
      }
      for (final jaren in [13, 15, 17]) {
        expect(moetOuderMeeVinkje(leeftijd: jaren, isEerste: true), isFalse);
        expect(toonOuderMeeTip(leeftijd: jaren, isEerste: true), isTrue);
      }
      expect(toonOuderMeeTip(leeftijd: 18, isEerste: true), isFalse);
      expect(moetOuderMeeVinkje(leeftijd: 11, isEerste: false), isFalse);
      expect(moetOuderMeeVinkje(leeftijd: null, isEerste: true), isFalse);
    },
  );

  test(
    'gereageerdLijst: eerst wat loopt, dan wat niet doorging; gekozen en ingetrokken niet',
    () {
      final lijst = gereageerdLijst([
        _r('oud-open', HhReactieStatus.open, 1),
        _r('nieuw-wacht', HhReactieStatus.wachtOpOuder, 5),
        _r('afgewezen', HhReactieStatus.afgewezen, 9),
        _r('gekozen', HhReactieStatus.gekozen, 8),
        _r('ingetrokken', HhReactieStatus.ingetrokken, 7),
        _r('vervallen', HhReactieStatus.vervallen, 3),
      ]);
      expect(lijst.map((r) => r.id), [
        'nieuw-wacht',
        'oud-open',
        'afgewezen',
        'vervallen',
      ]);
      final veel = gereageerdLijst([
        for (var i = 0; i < 15; i++) _r('a$i', HhReactieStatus.afgewezen, i),
      ]);
      expect(veel, hasLength(10));
    },
  );

  test('reactieStand in gewone taal', () {
    expect(
      reactieStand(_r('a', HhReactieStatus.open, 1)),
      TekstenReactiesNl.standWachtBewoner,
    );
    expect(
      reactieStand(_r('a', HhReactieStatus.wachtOpOuder, 1)),
      TekstenReactiesNl.standWachtOuder,
    );
    expect(
      reactieStand(_r('a', HhReactieStatus.afgewezen, 1)),
      TekstenReactiesNl.standNietGekozen,
    );
    expect(
      reactieStand(
        _r('a', HhReactieStatus.afgewezen, 1, besluit: 'liever_niet'),
      ),
      TekstenReactiesNl.standOuderNee,
    );
    expect(
      reactieStand(_r('a', HhReactieStatus.vervallen, 1)),
      TekstenReactiesNl.standVervallen,
    );
  });

  test('Ik kan nu helpen staat aan tot het eindmoment', () {
    final nu = DateTime.utc(2026, 10, 4, 10);
    expect(isNuBeschikbaar(nu.add(const Duration(minutes: 1)), nu), isTrue);
    expect(isNuBeschikbaar(nu, nu), isFalse);
    expect(isNuBeschikbaar(null, nu), isFalse);
  });

  test('avatarkleur: vast per naam, binnen de palette', () {
    expect(avatarKleurIndex('Daan', 4), avatarKleurIndex('Daan', 4));
    expect(avatarKleurIndex('Daan', 4), inInclusiveRange(0, 3));
    expect(avatarKleurIndex('x', 0), 0);
  });

  test('HhReactieStatus: onbekende code blijft zichtbaar als onbekend', () {
    expect(HhReactieStatus.vanCode('open'), HhReactieStatus.open);
    expect(HhReactieStatus.vanCode('iets'), HhReactieStatus.onbekend);
    expect(HhReactieStatus.wachtOpOuder.isActief, isTrue);
    expect(HhReactieStatus.gekozen.isActief, isFalse);
  });
}
