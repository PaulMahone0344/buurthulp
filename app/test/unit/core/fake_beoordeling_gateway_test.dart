import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/core/pb/beoordeling_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_beoordeling_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/features/jongere/klussen/model/hh_klus.dart';
import 'package:heitjehulp_app/features/jongere/reputatie/model/hh_beoordeling.dart';
import 'package:heitjehulp_app/theme.dart';

const _oudere = 'oudere1';
const _jongere = 'jongere1';
const _vreemde = 'jongere2';

HhKlus _klus(String id, {HhKlusStatus status = HhKlusStatus.afgerond}) =>
    HhKlus(
      id: id,
      hulpvragerId: _oudere,
      status: status,
      toegewezenJongereId: _jongere,
    );

HhReputatie _reputatie(FakeBeoordelingGateway fake, String id) {
  final r = fake.reputatieVan(id);
  return r;
}

void main() {
  group('de fake speelt de rules van hh_beoordelingen na', () {
    late FakeBeoordelingGateway fake;

    setUp(() {
      fake = FakeBeoordelingGateway(
        klussen: [
          _klus('k1'),
          _klus('k2'),
          _klus('k3'),
          _klus('open', status: HhKlusStatus.bezig),
        ],
        ikBenId: _oudere,
      );
    });

    test('de oudere beoordeelt de jongere bij een afgeronde klus', () async {
      final uitkomst = await fake.geef(
        klusId: 'k1',
        vanId: _oudere,
        naarId: _jongere,
        sterren: 5,
        tekst: 'Heel vriendelijk.',
      );
      expect(uitkomst, isA<BeoordelingOpgeslagen>());
      final b = (uitkomst as BeoordelingOpgeslagen).beoordeling;
      expect(b.klusId, 'k1');
      expect(b.sterren, 5);
      expect(b.tekst, 'Heel vriendelijk.');
    });

    test('een tweede keer dezelfde kant: al gegeven (unieke index)', () async {
      await fake.geef(
        klusId: 'k1',
        vanId: _oudere,
        naarId: _jongere,
        sterren: 5,
      );
      final dubbel = await fake.geef(
        klusId: 'k1',
        vanId: _oudere,
        naarId: _jongere,
        sterren: 3,
      );
      expect(
        dubbel,
        isA<BeoordelingGeweigerd>().having(
          (g) => g.reden,
          'reden',
          BeoordelingReden.alGegeven,
        ),
      );
    });

    test('niet bij een klus die nog niet afgerond is', () async {
      final r = await fake.geef(
        klusId: 'open',
        vanId: _oudere,
        naarId: _jongere,
        sterren: 5,
      );
      expect(
        r,
        isA<BeoordelingGeweigerd>().having(
          (g) => g.reden,
          'reden',
          BeoordelingReden.nietToegestaan,
        ),
      );
    });

    test('een vreemde, jezelf of namens een ander: geweigerd', () async {
      fake.ikBenId = _vreemde;
      final vreemde = await fake.geef(
        klusId: 'k1',
        vanId: _vreemde,
        naarId: _oudere,
        sterren: 5,
      );
      expect(vreemde, isA<BeoordelingGeweigerd>());

      fake.ikBenId = _oudere;
      final zelf = await fake.geef(
        klusId: 'k1',
        vanId: _oudere,
        naarId: _oudere,
        sterren: 5,
      );
      expect(zelf, isA<BeoordelingGeweigerd>());
      final namens = await fake.geef(
        klusId: 'k1',
        vanId: _jongere,
        naarId: _oudere,
        sterren: 5,
      );
      expect(namens, isA<BeoordelingGeweigerd>());
      expect(fake.alleBeoordelingen, isEmpty);
    });

    test('wijzigen mag alleen je eigen beoordeling', () async {
      final r = await fake.geef(
        klusId: 'k1',
        vanId: _oudere,
        naarId: _jongere,
        sterren: 4,
      );
      final id = (r as BeoordelingOpgeslagen).beoordeling.id;
      final gewijzigd = await fake.wijzig(id, sterren: 2, tekst: 'Te laat.');
      expect((gewijzigd as BeoordelingOpgeslagen).beoordeling.sterren, 2);
      fake.ikBenId = _jongere;
      final vanEenAnder = await fake.wijzig(id, sterren: 5, tekst: '');
      expect(
        vanEenAnder,
        isA<BeoordelingGeweigerd>().having(
          (g) => g.reden,
          'reden',
          BeoordelingReden.nietGevonden,
        ),
      );
    });
  });

  group('de fake speelt de hook na: gemiddelde en telling', () {
    test('kloppen na 1, 2 en 3 beoordelingen en na een wijziging', () async {
      final fake = FakeBeoordelingGateway(
        klussen: [_klus('k1'), _klus('k2'), _klus('k3')],
        ikBenId: _oudere,
      );
      // Drie afgeronde klussen tellen al vóór er iemand beoordeelt.
      expect(_reputatie(fake, _jongere).klussenAantal, 3);
      expect(_reputatie(fake, _jongere).heeftBeoordelingen, isFalse);

      await fake.geef(
        klusId: 'k1',
        vanId: _oudere,
        naarId: _jongere,
        sterren: 5,
      );
      expect(_reputatie(fake, _jongere).sterrenGemiddeld, 5.0);

      await fake.geef(
        klusId: 'k2',
        vanId: _oudere,
        naarId: _jongere,
        sterren: 4,
      );
      expect(_reputatie(fake, _jongere).sterrenGemiddeld, 4.5);

      final derde = await fake.geef(
        klusId: 'k3',
        vanId: _oudere,
        naarId: _jongere,
        sterren: 4,
      );
      expect(_reputatie(fake, _jongere).sterrenGemiddeld, 4.3);

      await fake.wijzig(
        (derde as BeoordelingOpgeslagen).beoordeling.id,
        sterren: 2,
        tekst: '',
      );
      expect(_reputatie(fake, _jongere).sterrenGemiddeld, 3.7);
      expect(_reputatie(fake, _jongere).klussenAantal, 3);
    });
  });

  group('lezen', () {
    test('gegeven en ontvangen (met tekst, laatste eerst)', () async {
      final fake = FakeBeoordelingGateway(
        klussen: [_klus('k1'), _klus('k2')],
        ikBenId: _oudere,
      );
      await fake.geef(
        klusId: 'k1',
        vanId: _oudere,
        naarId: _jongere,
        sterren: 5,
        tekst: 'Eerste',
      );
      await fake.geef(
        klusId: 'k2',
        vanId: _oudere,
        naarId: _jongere,
        sterren: 4,
      );

      final gegeven = await fake.gegevenDoor(_oudere);
      expect((gegeven as Ok<List<HhBeoordeling>>).waarde, hasLength(2));

      final ontvangen = await fake.ontvangen(_jongere);
      final lijst = (ontvangen as Ok<List<HhBeoordeling>>).waarde;
      expect(lijst.map((b) => b.tekst), ['Eerste']);
    });

    test('offline geeft een nette fout', () async {
      final fake = FakeBeoordelingGateway(isOffline: true);
      final r = await fake.reputatie(_jongere);
      expect((r as Err<HhReputatie>).fout.soort, HhFoutSoort.geenVerbinding);
      final g = await fake.geef(
        klusId: 'k1',
        vanId: _oudere,
        naarId: _jongere,
        sterren: 5,
      );
      expect(g, isA<BeoordelingFout>());
    });
  });
}
