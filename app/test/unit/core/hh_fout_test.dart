import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/hh_fout.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';

void main() {
  group('HhFout.vanStatus', () {
    test('geen statuscode is geen verbinding', () {
      expect(HhFout.vanStatus(null).soort, HhFoutSoort.geenVerbinding);
      expect(HhFout.vanStatus(0).soort, HhFoutSoort.geenVerbinding);
      expect(HhFout.vanStatus(0).isGeenVerbinding, isTrue);
    });

    test('400 met validation_not_unique op email is e-mail bestaat al', () {
      final fout = HhFout.vanStatus(
        400,
        antwoord: {
          'data': {
            'email': {
              'code': 'validation_not_unique',
              'message': 'Value must be unique.',
            },
          },
          'message': 'Failed to create record.',
          'status': 400,
        },
      );
      expect(fout.soort, HhFoutSoort.emailBestaatAl);
      expect(fout.melding, TekstenNl.foutEmailBestaatAl);
    });

    test('400 zonder velddata is ongeldige invoer', () {
      final fout = HhFout.vanStatus(
        400,
        antwoord: {'data': {}, 'message': 'Failed to authenticate.'},
      );
      expect(fout.soort, HhFoutSoort.ongeldigeInvoer);
    });

    test('400 met een ander veld is ongeldige invoer', () {
      final fout = HhFout.vanStatus(
        400,
        antwoord: {
          'data': {
            'password': {'code': 'validation_length_out_of_range'},
          },
        },
      );
      expect(fout.soort, HhFoutSoort.ongeldigeInvoer);
    });

    test('401, 403, 404, 500 en de rest', () {
      expect(HhFout.vanStatus(401).soort, HhFoutSoort.nietIngelogd);
      expect(HhFout.vanStatus(403).soort, HhFoutSoort.geenToegang);
      expect(HhFout.vanStatus(404).soort, HhFoutSoort.nietGevonden);
      expect(HhFout.vanStatus(500).soort, HhFoutSoort.server);
      expect(HhFout.vanStatus(503).soort, HhFoutSoort.server);
      expect(HhFout.vanStatus(418).soort, HhFoutSoort.onbekend);
    });
  });

  group('HhFout.melding', () {
    test('elke soort heeft een Nederlandse zin', () {
      for (final soort in HhFoutSoort.values) {
        final melding = HhFout(soort).melding;
        expect(melding, isNotEmpty, reason: '$soort');
        expect(melding, isNot(contains('Exception')), reason: '$soort');
      }
    });

    test('vaste vertalingen', () {
      expect(
        const HhFout(HhFoutSoort.geenVerbinding).melding,
        TekstenNl.foutGeenVerbinding,
      );
      expect(
        const HhFout(HhFoutSoort.ongeldigeInlog).melding,
        TekstenNl.foutOngeldigeInlog,
      );
      expect(
        const HhFout(HhFoutSoort.emailNietBevestigd).melding,
        TekstenNl.foutEmailNietBevestigd,
      );
      expect(
        const HhFout(HhFoutSoort.nietIngelogd).melding,
        TekstenNl.foutSessieVerlopen,
      );
    });
  });
}
