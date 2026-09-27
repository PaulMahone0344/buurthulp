import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/familie/domein/familie_rechten.dart';
import 'package:heitjehulp_app/features/familie/model/hh_koppeling.dart';

HhKoppeling _k({
  KoppelingStatus status = KoppelingStatus.actief,
  Set<FamilieRecht> rechten = const {
    FamilieRecht.meekijken,
    FamilieRecht.plaatsen,
  },
  String id = 'k1',
  String oudere = 'o1',
}) => HhKoppeling(
  id: id,
  oudereId: oudere,
  familielidId: 'f1',
  status: status,
  rechten: rechten,
  oudereNaam: 'Mevrouw A. de Vries',
  familielidNaam: 'Karin de Vries',
);

void main() {
  group('rechten -> wat het familielid ziet', () {
    test('actief met beide rechten: meekijken en plaatsen', () {
      final zicht = zichtVoor(_k());
      expect(zicht.kanMeekijken, isTrue);
      expect(zicht.kanPlaatsen, isTrue);
    });

    test('alleen meekijken: geen "Hulp vragen"-knop (F2 verborgen)', () {
      final zicht = zichtVoor(_k(rechten: {FamilieRecht.meekijken}));
      expect(zicht.kanMeekijken, isTrue);
      expect(zicht.kanPlaatsen, isFalse);
    });

    test('alleen plaatsen: wel F2, geen lijsten', () {
      final zicht = zichtVoor(_k(rechten: {FamilieRecht.plaatsen}));
      expect(zicht.kanMeekijken, isFalse);
      expect(zicht.kanPlaatsen, isTrue);
    });

    test('aangevraagd: niets, ook al zouden er rechten staan', () {
      final zicht = zichtVoor(_k(status: KoppelingStatus.aangevraagd));
      expect(zicht.kanMeekijken, isFalse);
      expect(zicht.kanPlaatsen, isFalse);
    });
  });

  group('de landing (F1)', () {
    test('actieve koppelingen en lopende aanvragen apart', () {
      final indeling = deelKoppelingenIn([
        _k(id: 'a'),
        _k(id: 'b', status: KoppelingStatus.aangevraagd, rechten: const {}),
        _k(id: 'c', oudere: 'o2'),
      ]);
      expect(indeling.actief.map((k) => k.id), ['a', 'c']);
      expect(indeling.aangevraagd.map((k) => k.id), ['b']);
    });

    test('precies één actieve oudere: meteen door naar F3', () {
      expect(meteenDoorNaar([_k()]), 'o1');
      expect(
        meteenDoorNaar([
          _k(),
          _k(id: 'x', status: KoppelingStatus.aangevraagd, rechten: const {}),
        ]),
        'o1',
      );
      expect(meteenDoorNaar([_k(), _k(id: 'b', oudere: 'o2')]), isNull);
      expect(meteenDoorNaar(const []), isNull);
    });
  });

  group('van de server', () {
    test('status en rechten uit de codes; onbekend of leeg = aangevraagd', () {
      expect(KoppelingStatus.vanCode('actief'), KoppelingStatus.actief);
      expect(
        KoppelingStatus.vanCode('aangevraagd'),
        KoppelingStatus.aangevraagd,
      );
      // Leeg bestaat na script 40 niet meer; mocht het toch voorkomen, dan
      // liever te weinig tonen dan te veel.
      expect(KoppelingStatus.vanCode(''), KoppelingStatus.aangevraagd);
      expect(FamilieRecht.uitCodes(['meekijken', 'plaatsen', 'iets']), {
        FamilieRecht.meekijken,
        FamilieRecht.plaatsen,
      });
    });
  });
}
