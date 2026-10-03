import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/jongere/domein/helper_wacht.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_profiel.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_screening_status.dart';
import 'package:heitjehulp_app/features/jongere/model/screening_stap.dart';
import 'package:heitjehulp_app/features/toegang/domein/werkgebied.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_gebruiker.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/l10n/teksten_aanmelden_nl.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  group('HhWerkgebiedStatus', () {
    test('leest de serverwaarden, leeg en onbekend tellen als onbepaald', () {
      expect(HhWerkgebiedStatus.vanCode('binnen'), HhWerkgebiedStatus.binnen);
      expect(HhWerkgebiedStatus.vanCode('buiten'), HhWerkgebiedStatus.buiten);
      expect(
        HhWerkgebiedStatus.vanCode('onbekend'),
        HhWerkgebiedStatus.onbekend,
      );
      expect(HhWerkgebiedStatus.vanCode(''), HhWerkgebiedStatus.onbepaald);
      expect(HhWerkgebiedStatus.vanCode(null), HhWerkgebiedStatus.onbepaald);
    });
  });

  group('werkgebiedMelding', () {
    test('met een wijk: geen melding', () {
      expect(werkgebiedMelding('w1', HhWerkgebiedStatus.binnen), isNull);
      // Bestaande accounts: wijk zonder status.
      expect(werkgebiedMelding('w1', HhWerkgebiedStatus.onbepaald), isNull);
    });

    test('zonder wijk: "nog niet in jouw buurt"', () {
      for (final s in [
        HhWerkgebiedStatus.buiten,
        HhWerkgebiedStatus.onbepaald,
      ]) {
        expect(werkgebiedMelding('', s), TekstenAanmeldenNl.nietInBuurt);
      }
    });

    test('geocoding mislukt: de meldkamer kijkt ernaar', () {
      expect(
        werkgebiedMelding('', HhWerkgebiedStatus.onbekend),
        TekstenAanmeldenNl.adresOnbekend,
      );
    });
  });

  group('HhGebruiker leest wijk en werkgebied_status', () {
    test('uit het hh_users-record', () {
      final g = HhGebruiker.vanRecord(
        RecordModel({
          'id': 'u1',
          'naam': 'Ans',
          'email': 'ans@voorbeeld.nl',
          'rol': 'hulpvrager',
          'wijk': 'w-regio',
          'werkgebied_status': 'binnen',
        }),
      );
      expect(g.wijkId, 'w-regio');
      expect(g.werkgebiedStatus, HhWerkgebiedStatus.binnen);
      expect(g.magKlusPlaatsen, isTrue);
    });

    test('een bewoner zonder wijk mag geen klus plaatsen', () {
      const g = HhGebruiker(
        id: 'u',
        naam: 'A',
        email: 'a@b.nl',
        rol: HhRol.hulpvrager,
        werkgebiedStatus: HhWerkgebiedStatus.buiten,
      );
      expect(g.magKlusPlaatsen, isFalse);
    });
  });

  group('helperWacht met werkgebied', () {
    final vandaag = DateTime(2026, 10, 3);
    ScreeningGegevens helper({
      required HhScreeningStatus status,
      String wijk = '',
      HhWerkgebiedStatus werkgebied = HhWerkgebiedStatus.buiten,
    }) => ScreeningGegevens(
      profiel: HhProfiel(
        id: 'p',
        gebruikerId: 'j',
        verificatiestatus: status,
        vogGezienOp: DateTime.utc(2026, 9, 1),
      ),
      account: HhAccountGegevens(
        geboortedatum: DateTime.utc(2000, 1, 1),
        wijkId: wijk,
        werkgebiedStatus: werkgebied,
      ),
    );

    test(
      'buiten het werkgebied: balk "nog niet in jouw buurt", ook als nagekeken',
      () {
        for (final s in [
          HhScreeningStatus.inBehandeling,
          HhScreeningStatus.goedgekeurd,
        ]) {
          expect(
            helperWacht(helper(status: s), vandaag),
            HelperWacht.nietInBuurt,
          );
        }
        expect(HelperWacht.nietInBuurt.heeftBalk, isTrue);
      },
    );

    test('adres niet gevonden: eigen balk', () {
      expect(
        helperWacht(
          helper(
            status: HhScreeningStatus.goedgekeurd,
            werkgebied: HhWerkgebiedStatus.onbekend,
          ),
          vandaag,
        ),
        HelperWacht.adresOnbekend,
      );
      expect(HelperWacht.adresOnbekend.heeftBalk, isTrue);
    });

    test('nog niet verstuurd gaat voor: eerst de aanmelding afmaken', () {
      expect(
        helperWacht(helper(status: HhScreeningStatus.nieuw), vandaag),
        HelperWacht.aanmelden,
      );
    });

    test('met wijk: klaar', () {
      expect(
        helperWacht(
          helper(
            status: HhScreeningStatus.goedgekeurd,
            wijk: 'w',
            werkgebied: HhWerkgebiedStatus.binnen,
          ),
          vandaag,
        ),
        HelperWacht.klaar,
      );
    });
  });
}
