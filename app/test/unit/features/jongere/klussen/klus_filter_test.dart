import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/jongere/klussen/domein/dagdeel.dart';
import 'package:heitjehulp_app/features/jongere/klussen/domein/klus_filter.dart';

import '../../../../support/hh_klussen_wikkel.dart';

void main() {
  final klussen = testOpenKlussen();
  List<String> ids(GefilterdeKlussen g) => [for (final k in g.klussen) k.id];

  group('KlusFilter', () {
    test('leeg laat alles door', () {
      const filter = KlusFilter();
      expect(filter.isLeeg, isTrue);
      expect(filter.aantalActief, 0);
      expect(klussen.every(filter.laatDoor), isTrue);
    });

    test('op klustype', () {
      const filter = KlusFilter(klustypeIds: {'type-tuin'});
      expect(ids(filterKlussen(klussen, filter)), ['k-middag', 'k-avond']);
    });

    test('op dagdeel (afgeleid uit wanneer_van)', () {
      const filter = KlusFilter(dagdelen: {HhDagdeel.ochtend});
      expect(ids(filterKlussen(klussen, filter)), [
        'k-ochtend',
        'k-zonder-locatie',
      ]);
      const twee = KlusFilter(dagdelen: {HhDagdeel.middag, HhDagdeel.avond});
      expect(ids(filterKlussen(klussen, twee)), ['k-middag', 'k-avond']);
    });

    test('klustype en dagdeel samen', () {
      const filter = KlusFilter(
        klustypeIds: {'type-tuin'},
        dagdelen: {HhDagdeel.avond},
      );
      expect(ids(filterKlussen(klussen, filter)), ['k-avond']);
      expect(filter.aantalActief, 2);
    });

    test('een klus zonder begintijd valt buiten elk dagdeelfilter', () {
      final zonder = testKlus(id: 'z').copyWith();
      final klusZonderTijd = testKlus(id: 'z2');
      expect(
        const KlusFilter(dagdelen: {HhDagdeel.ochtend}).laatDoor(zonder),
        isFalse,
      );
      expect(const KlusFilter().laatDoor(klusZonderTijd), isTrue);
    });

    test('copyWith en gelijkheid', () {
      const a = KlusFilter(klustypeIds: {'x'});
      final b = a.copyWith(dagdelen: {HhDagdeel.avond});
      expect(b.klustypeIds, {'x'});
      expect(b.dagdelen, {HhDagdeel.avond});
      expect(a, const KlusFilter(klustypeIds: {'x'}));
      expect(a == b, isFalse);
    });
  });

  group('straalfilter', () {
    test('zonder straal (0) valt niets buiten', () {
      final g = filterKlussen(klussen, const KlusFilter());
      expect(g.buitenStraal, 0);
      expect(g.klussen.length, 4);
      expect(g.middelpunt, isNotNull);
    });

    test('klussen verder dan de straal van het middelpunt vallen eruit', () {
      // Middelpunt ligt rond 0,77 km; k-middag (1,2) ligt daar 0,43 km vandaan,
      // k-ochtend (0,3) 0,47 km. Straal 1 km houdt alles; een klein
      // middelpunt-verschil test we met een uitschieter.
      final metUitschieter = [...klussen, testKlus(id: 'k-ver', afstandKm: 6)];
      final g = filterKlussen(metUitschieter, const KlusFilter(), straalKm: 2);
      expect(ids(g), isNot(contains('k-ver')));
      expect(g.buitenStraal, 1);
    });

    test('een klus zonder coördinaten valt nooit buiten de straal', () {
      final g = filterKlussen(klussen, const KlusFilter(), straalKm: 1);
      expect(ids(g), contains('k-zonder-locatie'));
      expect(g.zonderCoordinaten.map((k) => k.id), ['k-zonder-locatie']);
      expect(g.metCoordinaten.length, 3);
    });

    test(
      'zonder een enkele locatie is er geen middelpunt en geen straalfilter',
      () {
        final zonder = [
          testKlus(id: 'a', afstandKm: null),
          testKlus(id: 'b', afstandKm: null),
        ];
        final g = filterKlussen(zonder, const KlusFilter(), straalKm: 1);
        expect(g.middelpunt, isNull);
        expect(g.klussen.length, 2);
        expect(g.buitenStraal, 0);
      },
    );

    test(
      'de filterbalk gaat vóór de straal: wat de balk wegfiltert telt niet als buiten de straal',
      () {
        final metUitschieter = [
          ...klussen,
          testKlus(id: 'k-ver', afstandKm: 6),
        ];
        final g = filterKlussen(
          metUitschieter,
          const KlusFilter(klustypeIds: {'type-tuin'}),
          straalKm: 2,
        );
        expect(ids(g), ['k-middag', 'k-avond']);
        expect(g.buitenStraal, 0);
      },
    );
  });
}
