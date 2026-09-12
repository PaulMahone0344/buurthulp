import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/jongere/datum_invoer.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_beschikbaarheid.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_profiel.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_screening_status.dart';
import 'package:heitjehulp_app/features/jongere/model/screening_stap.dart';
import 'package:heitjehulp_app/features/jongere/paden_jongere.dart';

void main() {
  final compleet = HhProfiel(
    id: 'p',
    gebruikerId: 'j',
    straalKm: 2,
    beschikbaarheid: HhBeschikbaarheid.van({
      HhDag.ma: {HhDagdeel.middag},
    }),
    klustypeIds: const {'a'},
    overMij: 'Hoi',
    documentFoto: 'doc.jpg',
    selfie: 'selfie.jpg',
    iban: 'NL91ABNA0417164300',
    vogAangevraagdOp: DateTime.utc(2026, 9, 1),
  );
  final account = HhAccountGegevens(
    fotoBestand: 'foto.jpg',
    geboortedatum: DateTime.utc(2008, 5, 14),
    wijkId: 'wijk-west',
  );
  final klaar = ScreeningGegevens(profiel: compleet, account: account);

  group('ScreeningStap.isAf', () {
    test('zonder profiel is niets af', () {
      const leeg = ScreeningGegevens();
      for (final stap in ScreeningStap.values) {
        expect(stap.isAf(leeg), isFalse, reason: stap.name);
      }
      expect(ScreeningStap.alleAf(leeg), isFalse);
      expect(leeg.verificatiestatus, HhScreeningStatus.nieuw);
    });

    test('met alles ingevuld is alles af', () {
      for (final stap in ScreeningStap.values) {
        expect(stap.isAf(klaar), isTrue, reason: stap.name);
      }
      expect(ScreeningStap.alleAf(klaar), isTrue);
    });

    test('J1 vraagt foto, geboortedatum en over mij', () {
      expect(
        ScreeningStap.profiel.isAf(
          klaar.copyWith(account: account.copyWith(fotoBestand: '')),
        ),
        isFalse,
      );
      expect(
        ScreeningStap.profiel.isAf(
          klaar.copyWith(account: account.copyWith(geboortedatum: () => null)),
        ),
        isFalse,
      );
      expect(
        ScreeningStap.profiel.isAf(
          klaar.copyWith(profiel: compleet.copyWith(overMij: '  ')),
        ),
        isFalse,
      );
    });

    test('J2, J3, J5, J8 hangen aan hun eigen veld', () {
      expect(
        ScreeningStap.identiteit.isAf(
          klaar.copyWith(profiel: compleet.copyWith(documentFoto: '')),
        ),
        isFalse,
      );
      expect(
        ScreeningStap.selfie.isAf(
          klaar.copyWith(profiel: compleet.copyWith(selfie: '')),
        ),
        isFalse,
      );
      expect(
        ScreeningStap.iban.isAf(
          klaar.copyWith(profiel: compleet.copyWith(iban: '')),
        ),
        isFalse,
      );
      expect(
        ScreeningStap.klussoorten.isAf(
          klaar.copyWith(profiel: compleet.copyWith(klustypeIds: const {})),
        ),
        isFalse,
      );
    });

    test('J4 is af na aanvragen, of zodra de meldkamer een vog_status zet', () {
      final zonderDatum = compleet.copyWith(vogAangevraagdOp: () => null);
      expect(
        ScreeningStap.vog.isAf(klaar.copyWith(profiel: zonderDatum)),
        isFalse,
      );
      expect(
        ScreeningStap.vog.isAf(
          klaar.copyWith(
            profiel: zonderDatum.copyWith(
              vogStatus: HhScreeningStatus.inBehandeling,
            ),
          ),
        ),
        isTrue,
      );
    });

    test('J6 vraagt wijk (hh_users) en straal (hh_profielen)', () {
      expect(
        ScreeningStap.werkgebied.isAf(
          klaar.copyWith(account: account.copyWith(wijkId: '')),
        ),
        isFalse,
      );
      expect(
        ScreeningStap.werkgebied.isAf(
          klaar.copyWith(profiel: compleet.copyWith(straalKm: 0)),
        ),
        isFalse,
      );
    });

    test('J7 vraagt minstens een dagdeel', () {
      expect(
        ScreeningStap.beschikbaarheid.isAf(
          klaar.copyWith(
            profiel: compleet.copyWith(
              beschikbaarheid: const HhBeschikbaarheid.leeg(),
            ),
          ),
        ),
        isFalse,
      );
    });

    test('nummer, volgende stap en paden', () {
      expect(ScreeningStap.totaal, 8);
      expect(ScreeningStap.profiel.nummer, 1);
      expect(ScreeningStap.profiel.volgendPad, HhPadenJongere.identiteit);
      expect(ScreeningStap.klussoorten.volgendPad, HhPadenJongere.overzicht);
      expect(HhPadenJongere.isScreeningPad(HhPadenJongere.vog), isTrue);
      expect(HhPadenJongere.isScreeningPad('/jongere'), isFalse);
    });
  });

  group('kanTerControleAanbieden', () {
    test('alleen als alles af is en de status nieuw', () {
      expect(kanTerControleAanbieden(klaar), isTrue);
      expect(kanTerControleAanbieden(const ScreeningGegevens()), isFalse);
      for (final status in HhScreeningStatus.values.where(
        (s) => s != HhScreeningStatus.nieuw,
      )) {
        expect(
          kanTerControleAanbieden(
            klaar.copyWith(
              profiel: compleet.copyWith(verificatiestatus: status),
            ),
          ),
          isFalse,
          reason: status.code,
        );
      }
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
      expect(HhScreeningStatus.inBehandeling.code, 'in_behandeling');
    });
  });

  group('datum', () {
    test('dag-maand-jaar heen en terug', () {
      expect(parseDatumNl('14-05-2008'), DateTime.utc(2008, 5, 14));
      expect(parseDatumNl(' 1/2/2008 '), DateTime.utc(2008, 2, 1));
      expect(parseDatumNl('31-02-2008'), isNull);
      expect(parseDatumNl('2008-05-14'), isNull);
      expect(parseDatumNl('abc'), isNull);
      expect(toonDatumNl(DateTime.utc(2008, 5, 14)), '14-05-2008');
      expect(
        HhProfiel.datumVanServer('2008-05-14 00:00:00.000Z'),
        DateTime.utc(2008, 5, 14),
      );
      expect(HhProfiel.datumVanServer(''), isNull);
    });
  });
}
