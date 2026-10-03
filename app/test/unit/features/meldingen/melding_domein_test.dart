import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/coordinator/paden_coordinator.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/paden_status.dart';
import 'package:heitjehulp_app/features/jongere/klussen/paden_klussen.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/paden_uitvoeren.dart';
import 'package:heitjehulp_app/features/meldingen/domein/melding_domein.dart';
import 'package:heitjehulp_app/features/meldingen/model/hh_melding.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/l10n/teksten_meldingen_nl.dart';

HhMelding _melding(
  HhMeldingSoort soort, {
  String id = 'm1',
  String klus = 'k1',
  String incident = '',
  String titel = '',
  DateTime? gemaakt,
  DateTime? gelezen,
}) => HhMelding(
  id: id,
  ontvangerId: 'u1',
  soort: soort,
  klusId: klus,
  incidentId: incident,
  titel: titel,
  gemaakt: gemaakt ?? DateTime(2026, 9, 15, 10),
  gelezenOp: gelezen,
);

void main() {
  group('soort van de server', () {
    test('elke code wordt een soort; onbekend blijft zichtbaar', () {
      for (final soort in HhMeldingSoort.values) {
        expect(HhMeldingSoort.vanCode(soort.code), soort);
      }
      expect(HhMeldingSoort.vanCode('iets_nieuws'), HhMeldingSoort.onbekend);
    });
  });

  group('titel per soort en rol (als de server geen titel meegaf)', () {
    test('de hook-titel gaat altijd voor', () {
      final m = _melding(HhMeldingSoort.onderweg, titel: 'Onderweg naar u');
      expect(titelVan(m, HhRol.hulpvrager), 'Onderweg naar u');
    });

    test('bewoner en helper krijgen allebei je', () {
      expect(
        titelVan(_melding(HhMeldingSoort.toegewezen), HhRol.hulpvrager),
        TekstenMeldingenNl.soortToegewezenOudere,
      );
      expect(
        titelVan(_melding(HhMeldingSoort.toegewezen), HhRol.jongere),
        TekstenMeldingenNl.soortToegewezenJongere,
      );
      expect(TekstenMeldingenNl.soortToegewezenOudere, contains('je'));
      expect(
        titelVan(_melding(HhMeldingSoort.nieuweKlus), HhRol.jongere),
        TekstenMeldingenNl.soortNieuweKlus,
      );
    });

    test('elke soort heeft voor elke rol een niet-lege titel', () {
      for (final soort in HhMeldingSoort.values) {
        for (final rol in HhRol.values) {
          expect(
            titelVan(_melding(soort), rol),
            isNotEmpty,
            reason: '$soort/$rol',
          );
        }
      }
    });
  });

  group('waar een tik naartoe gaat', () {
    test('jongere: nieuwe klus -> J13, lopend of afgerond -> J15', () {
      expect(
        doelVan(_melding(HhMeldingSoort.nieuweKlus), HhRol.jongere),
        HhPadenKlussen.klusDetail('k1'),
      );
      for (final soort in [
        HhMeldingSoort.toegewezen,
        HhMeldingSoort.onderweg,
        HhMeldingSoort.afgerond,
      ]) {
        expect(
          doelVan(_melding(soort), HhRol.jongere),
          HhPadenUitvoeren.uitvoeren('k1'),
        );
      }
      expect(
        doelVan(_melding(HhMeldingSoort.geannuleerd), HhRol.jongere),
        HhPadenKlussen.klusDetail('k1'),
      );
    });

    test('oudere: altijd O7 van de klus', () {
      expect(
        doelVan(_melding(HhMeldingSoort.onderweg), HhRol.hulpvrager),
        HhPadenStatus.hulpvraag('k1'),
      );
    });

    test('coordinator: een incident opent C1-detail', () {
      expect(
        doelVan(
          _melding(HhMeldingSoort.incident, incident: 'i1', klus: ''),
          HhRol.coordinator,
        ),
        HhPadenCoordinator.incidentDetail('i1'),
      );
    });

    test('zonder klus of zonder scherm: nergens heen', () {
      expect(
        doelVan(_melding(HhMeldingSoort.onderweg, klus: ''), HhRol.hulpvrager),
        isNull,
      );
      expect(
        doelVan(
          _melding(HhMeldingSoort.incident, incident: 'i1'),
          HhRol.familie,
        ),
        isNull,
      );
    });
  });

  group('lijst', () {
    test('ongelezen tellen', () {
      final lijst = [
        _melding(HhMeldingSoort.onderweg, id: 'a'),
        _melding(HhMeldingSoort.afgerond, id: 'b', gelezen: DateTime(2026)),
        _melding(HhMeldingSoort.toegewezen, id: 'c'),
      ];
      expect(ongelezenAantal(lijst), 2);
      expect(ongelezenAantal(const []), 0);
    });

    test('een melding uit realtime komt bovenaan, een update vervangt', () {
      final oud = _melding(
        HhMeldingSoort.toegewezen,
        id: 'a',
        gemaakt: DateTime(2026, 9, 15, 9),
      );
      final nieuw = _melding(
        HhMeldingSoort.onderweg,
        id: 'b',
        gemaakt: DateTime(2026, 9, 15, 11),
      );
      final lijst = voegIn([oud], nieuw);
      expect(lijst.map((m) => m.id), ['b', 'a']);

      final gelezen = voegIn(
        lijst,
        _melding(
          HhMeldingSoort.toegewezen,
          id: 'a',
          gemaakt: DateTime(2026, 9, 15, 9),
          gelezen: DateTime(2026, 9, 15, 12),
        ),
      );
      expect(gelezen, hasLength(2));
      expect(gelezen.last.isGelezen, isTrue);
    });

    test('tijd in gewone taal', () {
      final nu = DateTime(2026, 9, 15, 12);
      expect(meldingTijd(DateTime(2026, 9, 15, 10, 5), nu), 'vandaag 10:05');
      expect(
        meldingTijd(DateTime(2026, 9, 13, 9), nu),
        'zondag 13 september 09:00',
      );
    });
  });
}
