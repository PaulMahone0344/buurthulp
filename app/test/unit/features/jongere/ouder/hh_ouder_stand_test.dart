import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/jongere/ouder/model/hh_ouder_stand.dart';

void main() {
  group('HhOuderStand.vanJson (GET /api/hh/ouder/status)', () {
    test('leest de stand van de server', () {
      final stand = HhOuderStand.vanJson({
        'status': 'verstuurd',
        'nodig': true,
        'ouder_email': 'mama@voorbeeld.nl',
        'verstuurd_op': '2026-10-04 10:00:00.000Z',
        'code_verloopt_op': '2026-10-05 10:00:00.000Z',
        'geblokkeerd': false,
        'gegeven_op': '',
        'ingetrokken_op': '',
        'nog_te_sturen': 2,
      });
      expect(stand.status, HhOuderStatus.verstuurd);
      expect(stand.ouderEmail, 'mama@voorbeeld.nl');
      expect(stand.verstuurdOp, DateTime.utc(2026, 10, 4, 10));
      expect(stand.nogTeSturen, 2);
      expect(stand.kanOpnieuw, isTrue);
      expect(stand.wachtOpNieuweCode, isFalse);
      expect(stand.gegevenOp, isNull);
    });

    test('onbekende of ontbrekende waarden: veilig terugvallen', () {
      final stand = HhOuderStand.vanJson({'status': 'iets'});
      expect(stand.status, HhOuderStatus.geen);
      expect(stand.nodig, isTrue);
      expect(stand.ouderEmail, '');
      expect(stand.nogTeSturen, 0);
      expect(stand.kanOpnieuw, isFalse);
    });

    test('verlopen of geblokkeerd: er moet een nieuwe code komen', () {
      expect(
        HhOuderStand.vanJson({'status': 'verlopen'}).wachtOpNieuweCode,
        isTrue,
      );
      expect(
        HhOuderStand.vanJson({
          'status': 'verstuurd',
          'geblokkeerd': true,
        }).wachtOpNieuweCode,
        isTrue,
      );
    });

    test('alle statussen volgen de server', () {
      for (final s in HhOuderStatus.values) {
        expect(HhOuderStatus.vanCode(s.code), s);
      }
    });
  });
}
