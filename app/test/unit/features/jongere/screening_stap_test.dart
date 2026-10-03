import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/jongere/datum_invoer.dart';
import 'package:heitjehulp_app/features/jongere/domein/helper_wacht.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_profiel.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_screening_status.dart';
import 'package:heitjehulp_app/features/jongere/model/screening_stap.dart';
import 'package:heitjehulp_app/features/jongere/paden_jongere.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  final vandaag = DateTime(2026, 10, 3);
  const leeg = HhProfiel(id: 'p', gebruikerId: 'j');

  ScreeningGegevens helper({
    HhProfiel profiel = leeg,
    DateTime? geboren,
    DateTime? toestemming,
  }) => ScreeningGegevens(
    profiel: profiel,
    account: HhAccountGegevens(
      geboortedatum: geboren,
      ouderToestemmingOp: toestemming,
    ),
  );

  final jong = DateTime.utc(2013, 1, 1); // 13
  final oud = DateTime.utc(2000, 1, 1); // 26

  group('ScreeningStap.voor', () {
    test('onder 18: ID-foto en over mij, geen VOG', () {
      expect(ScreeningStap.voor(helper(geboren: jong), vandaag), [
        ScreeningStap.identiteit,
        ScreeningStap.overMij,
      ]);
    });

    test('18+ of onbekend: ook de VOG', () {
      for (final g in [helper(geboren: oud), helper()]) {
        expect(ScreeningStap.voor(g, vandaag), [
          ScreeningStap.identiteit,
          ScreeningStap.vog,
          ScreeningStap.overMij,
        ]);
      }
    });

    test('alleen de ID-foto is verplicht', () {
      expect(ScreeningStap.values.where((s) => s.isVerplicht), [
        ScreeningStap.identiteit,
      ]);
    });

    test('paden', () {
      expect(ScreeningStap.identiteit.pad, HhPadenJongere.identiteit);
      expect(ScreeningStap.vog.pad, HhPadenJongere.vog);
      expect(ScreeningStap.overMij.pad, HhPadenJongere.overMij);
      expect(HhPadenJongere.isScreeningPad(HhPadenJongere.binnen), isTrue);
      expect(HhPadenJongere.isScreeningPad('/jongere'), isFalse);
    });
  });

  group('isAf', () {
    test('zonder profiel is niets af', () {
      for (final stap in ScreeningStap.values) {
        expect(stap.isAf(const ScreeningGegevens()), isFalse);
      }
    });

    test('ID: foto op de server, of al gecontroleerd (foto gewist)', () {
      expect(ScreeningStap.identiteit.isAf(helper()), isFalse);
      expect(
        ScreeningStap.identiteit.isAf(
          helper(profiel: leeg.copyWith(documentFoto: 'id.jpg')),
        ),
        isTrue,
      );
      expect(
        ScreeningStap.identiteit.isAf(
          helper(
            profiel: leeg.copyWith(idGecontroleerdOp: () => DateTime.utc(2026)),
          ),
        ),
        isTrue,
      );
    });

    test('VOG: aangevraagd of gezien door de meldkamer', () {
      expect(ScreeningStap.vog.isAf(helper()), isFalse);
      expect(
        ScreeningStap.vog.isAf(
          helper(
            profiel: leeg.copyWith(vogAangevraagdOp: () => DateTime.utc(2026)),
          ),
        ),
        isTrue,
      );
      expect(
        ScreeningStap.vog.isAf(
          helper(profiel: leeg.copyWith(vogGezienOp: () => DateTime.utc(2026))),
        ),
        isTrue,
      );
    });

    test('over mij: alleen met tekst', () {
      expect(ScreeningStap.overMij.isAf(helper()), isFalse);
      expect(
        ScreeningStap.overMij.isAf(
          helper(profiel: leeg.copyWith(overMij: ' Hoi ')),
        ),
        isTrue,
      );
    });
  });

  group('kanTerControleAanbieden', () {
    final metFoto = helper(profiel: leeg.copyWith(documentFoto: 'id.jpg'));

    test('met ID-foto en status nieuw; VOG en over mij hoeven niet', () {
      expect(kanTerControleAanbieden(metFoto), isTrue);
      expect(kanTerControleAanbieden(helper()), isFalse);
      expect(kanTerControleAanbieden(const ScreeningGegevens()), isFalse);
    });

    test('niet meer na het versturen', () {
      for (final status in HhScreeningStatus.values.where(
        (s) => s != HhScreeningStatus.nieuw,
      )) {
        expect(
          kanTerControleAanbieden(
            metFoto.copyWith(
              profiel: metFoto.profiel!.copyWith(verificatiestatus: status),
            ),
          ),
          isFalse,
          reason: status.code,
        );
      }
    });
  });

  group('helperWacht: het eerste dat ontbreekt', () {
    HhProfiel met(HhScreeningStatus status, {bool vog = false}) =>
        leeg.copyWith(
          verificatiestatus: status,
          vogGezienOp: vog ? () => DateTime.utc(2026, 9, 1) : null,
        );

    test('nog niet verstuurd of afgewezen: aanmelden (J9)', () {
      expect(
        helperWacht(const ScreeningGegevens(), vandaag),
        HelperWacht.aanmelden,
      );
      expect(
        helperWacht(helper(profiel: met(HhScreeningStatus.afgewezen)), vandaag),
        HelperWacht.afgewezen,
      );
      expect(HelperWacht.aanmelden.isAanmelden, isTrue);
      expect(HelperWacht.afgewezen.isAanmelden, isTrue);
    });

    test('in behandeling gaat voor alles', () {
      expect(
        helperWacht(
          helper(profiel: met(HhScreeningStatus.inBehandeling), geboren: jong),
          vandaag,
        ),
        HelperWacht.nagekeken,
      );
    });

    test('onder 18: wacht op de ouder, daarna klaar (zonder VOG)', () {
      final goed = met(HhScreeningStatus.goedgekeurd);
      expect(
        helperWacht(helper(profiel: goed, geboren: jong), vandaag),
        HelperWacht.ouder,
      );
      expect(
        helperWacht(
          helper(profiel: goed, geboren: jong, toestemming: DateTime.utc(2026)),
          vandaag,
        ),
        HelperWacht.klaar,
      );
    });

    test('18+: wacht op de VOG, daarna klaar', () {
      expect(
        helperWacht(
          helper(profiel: met(HhScreeningStatus.goedgekeurd), geboren: oud),
          vandaag,
        ),
        HelperWacht.vog,
      );
      expect(
        helperWacht(
          helper(
            profiel: met(HhScreeningStatus.goedgekeurd, vog: true),
            geboren: oud,
          ),
          vandaag,
        ),
        HelperWacht.klaar,
      );
    });

    test('18 geworden: dan telt de VOG, niet meer de ouder', () {
      expect(
        helperWacht(
          helper(
            profiel: met(HhScreeningStatus.goedgekeurd),
            geboren: DateTime.utc(2008, 10, 3),
            toestemming: DateTime.utc(2025),
          ),
          vandaag,
        ),
        HelperWacht.vog,
      );
    });

    test(
      'goedgekeurd zonder geboortedatum: nagekeken (de meldkamer lost het op)',
      () {
        expect(
          helperWacht(
            helper(profiel: met(HhScreeningStatus.goedgekeurd, vog: true)),
            vandaag,
          ),
          HelperWacht.nagekeken,
        );
      },
    );

    test('balk alleen bij nagekeken, ouder en VOG', () {
      expect(HelperWacht.values.where((w) => w.heeftBalk), [
        HelperWacht.nagekeken,
        HelperWacht.ouder,
        HelperWacht.vog,
      ]);
    });
  });

  group('HhProfiel en HhAccountGegevens lezen B1-velden', () {
    test('vog_gezien_op, id_gecontroleerd_op en ouder_toestemming_op', () {
      final profiel = HhProfiel.vanRecord(
        RecordModel({
          'id': 'p1',
          'gebruiker': 'u1',
          'verificatiestatus': 'goedgekeurd',
          'vog_gezien_op': '2026-09-20 10:00:00.000Z',
          'id_gecontroleerd_op': '2026-09-21 10:00:00.000Z',
          'document_foto': '',
        }),
      );
      expect(profiel.vogGezienOp, DateTime.utc(2026, 9, 20, 10));
      expect(profiel.isIdGecontroleerd, isTrue);
      expect(profiel.heeftDocumentFoto, isFalse);
      final account = HhAccountGegevens.vanRecord(
        RecordModel({
          'id': 'u1',
          'geboortedatum': '2012-05-14 00:00:00.000Z',
          'ouder_toestemming_op': '',
          'wijk': 'w1',
        }),
      );
      expect(account.geboortedatum, DateTime.utc(2012, 5, 14));
      expect(account.ouderToestemmingOp, isNull);
      expect(account.wijkId, 'w1');
    });
  });

  group('HhScreeningStatus', () {
    test('leeg en onbekend tellen als nieuw', () {
      expect(HhScreeningStatus.vanCode(''), HhScreeningStatus.nieuw);
      expect(HhScreeningStatus.vanCode(null), HhScreeningStatus.nieuw);
      expect(HhScreeningStatus.vanCode('x'), HhScreeningStatus.nieuw);
      expect(
        HhScreeningStatus.vanCode('in_behandeling'),
        HhScreeningStatus.inBehandeling,
      );
    });
  });

  group('datum', () {
    test('dag-maand-jaar heen en terug', () {
      expect(parseDatumNl('14-05-2008'), DateTime.utc(2008, 5, 14));
      expect(parseDatumNl(' 1/2/2008 '), DateTime.utc(2008, 2, 1));
      expect(parseDatumNl('31-02-2008'), isNull);
      expect(parseDatumNl('2008-05-14'), isNull);
      expect(toonDatumNl(DateTime.utc(2008, 5, 14)), '14-05-2008');
      expect(HhProfiel.datumVanServer(''), isNull);
    });
  });
}
