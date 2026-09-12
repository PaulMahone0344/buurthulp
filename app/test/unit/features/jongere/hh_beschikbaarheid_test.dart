import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_beschikbaarheid.dart';

void main() {
  const seedJson = {
    'ma': ['middag'],
    'di': ['ochtend', 'middag'],
    'wo': ['middag'],
    'do': <String>[],
    'vr': ['middag', 'avond'],
    'za': ['ochtend'],
    'zo': <String>[],
  };

  test(
    'json heen en terug geeft dezelfde json (alle 7 dagen, vaste volgorde)',
    () {
      final b = HhBeschikbaarheid.vanJson(seedJson);
      expect(b.naarJson(), seedJson);
      expect(b.voor(HhDag.di), {HhDagdeel.ochtend, HhDagdeel.middag});
      expect(b.voor(HhDag.do_), isEmpty);
      expect(b.isLeeg, isFalse);
    },
  );

  test('dagdelen komen altijd in de volgorde ochtend, middag, avond', () {
    final b = HhBeschikbaarheid.van({
      HhDag.vr: {HhDagdeel.avond, HhDagdeel.ochtend},
    });
    expect(b.naarJson()['vr'], ['ochtend', 'avond']);
  });

  test('onbekende sleutels en waarden worden overgeslagen; rommel is leeg', () {
    final b = HhBeschikbaarheid.vanJson({
      'ma': ['middag', 'nacht'],
      'feestdag': ['ochtend'],
      'wo': 'middag',
    });
    expect(b.voor(HhDag.ma), {HhDagdeel.middag});
    expect(b.voor(HhDag.wo), isEmpty);
    expect(HhBeschikbaarheid.vanJson(null).isLeeg, isTrue);
    expect(HhBeschikbaarheid.vanJson('x').isLeeg, isTrue);
    expect(HhBeschikbaarheid.vanJson(const {}).isLeeg, isTrue);
  });

  test('met() levert een nieuw object en laat het oude staan', () {
    const leeg = HhBeschikbaarheid.leeg();
    final met = leeg.met(HhDag.za, {HhDagdeel.ochtend});
    expect(leeg.isLeeg, isTrue);
    expect(met.voor(HhDag.za), {HhDagdeel.ochtend});
    expect(met.met(HhDag.za, {}).isLeeg, isTrue);
  });

  test('gelijkheid kijkt naar inhoud, niet naar sleutelvolgorde', () {
    final a = HhBeschikbaarheid.vanJson(seedJson);
    final b = HhBeschikbaarheid.vanJson({
      'zo': <String>[],
      'za': ['ochtend'],
      'vr': ['avond', 'middag'],
      'wo': ['middag'],
      'di': ['middag', 'ochtend'],
      'ma': ['middag'],
    });
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(a.met(HhDag.zo, {HhDagdeel.avond})));
  });
}
