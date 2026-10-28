import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/jongere/klussen/model/hh_klus.dart';
import 'package:heitjehulp_app/l10n/teksten_klus_nl.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/domein/hulpvraag_indeling.dart';
import 'package:heitjehulp_app/l10n/teksten_uitvoeren_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../support/hh_uitvoeren_wikkel.dart';

void main() {
  group('indelingVanHulpvraag', () {
    test('concept en open horen bij Open', () {
      for (final status in [HhKlusStatus.concept, HhKlusStatus.open]) {
        expect(
          indelingVanHulpvraag(uitvoerKlus(status: status, metJongere: false)),
          HulpvraagTab.open,
          reason: status.name,
        );
      }
    });

    test('geaccepteerd, onderweg en bezig horen bij Gepland', () {
      for (final status in [
        HhKlusStatus.geaccepteerd,
        HhKlusStatus.onderweg,
        HhKlusStatus.bezig,
      ]) {
        expect(
          indelingVanHulpvraag(uitvoerKlus(status: status)),
          HulpvraagTab.gepland,
          reason: status.name,
        );
      }
    });

    test('afgerond, geannuleerd en probleem horen bij Afgerond', () {
      for (final status in [
        HhKlusStatus.afgerond,
        HhKlusStatus.geannuleerd,
        HhKlusStatus.probleem,
      ]) {
        expect(
          indelingVanHulpvraag(uitvoerKlus(status: status)),
          HulpvraagTab.afgerond,
          reason: status.name,
        );
      }
    });

    test('elke status valt in precies één tabblad', () {
      for (final status in HhKlusStatus.values) {
        final tab = indelingVanHulpvraag(uitvoerKlus(status: status));
        expect(HulpvraagTab.values.contains(tab), isTrue, reason: status.name);
      }
    });
  });

  group('deelHulpvragenIn', () {
    test('verdeelt over de drie tabbladen', () {
      final per = deelHulpvragenIn([
        uitvoerKlus(id: 'a', status: HhKlusStatus.open, metJongere: false),
        uitvoerKlus(id: 'b', status: HhKlusStatus.onderweg),
        uitvoerKlus(id: 'c', status: HhKlusStatus.afgerond),
        uitvoerKlus(id: 'd', status: HhKlusStatus.geannuleerd),
      ]);
      expect(per[HulpvraagTab.open]!.map((k) => k.id), ['a']);
      expect(per[HulpvraagTab.gepland]!.map((k) => k.id), ['b']);
      expect(per[HulpvraagTab.afgerond]!.map((k) => k.id), ['c', 'd']);
    });

    test('open en gepland lopen op in de tijd, afgerond loopt af', () {
      final vroeg = uitvoerNu.add(const Duration(hours: 1));
      final laat = uitvoerNu.add(const Duration(days: 2));
      final per = deelHulpvragenIn([
        uitvoerKlus(
          id: 'laat',
          status: HhKlusStatus.open,
          metJongere: false,
          wanneerVan: laat,
        ),
        uitvoerKlus(
          id: 'vroeg',
          status: HhKlusStatus.open,
          metJongere: false,
          wanneerVan: vroeg,
        ),
        uitvoerKlus(
          id: 'oud',
          status: HhKlusStatus.afgerond,
          wanneerVan: vroeg,
        ),
        uitvoerKlus(
          id: 'nieuw',
          status: HhKlusStatus.afgerond,
          wanneerVan: laat,
        ),
      ]);
      expect(per[HulpvraagTab.open]!.map((k) => k.id), ['vroeg', 'laat']);
      expect(per[HulpvraagTab.afgerond]!.map((k) => k.id), ['nieuw', 'oud']);
    });

    test('lege lijst geeft drie lege tabbladen', () {
      final per = deelHulpvragenIn(const []);
      expect(per.keys, HulpvraagTab.values);
      expect(per.values.every((l) => l.isEmpty), isTrue);
    });
  });

  group('statusZin', () {
    test('zonder helper: we zoeken iemand voor je', () {
      expect(
        statusZin(uitvoerKlus(status: HhKlusStatus.open, metJongere: false)),
        TekstenUitvoerenNl.o7GeenJongere,
      );
    });

    test('met jongere: de voornaam staat in de zin', () {
      expect(
        statusZin(uitvoerKlus(status: HhKlusStatus.onderweg)),
        'Sanne is onderweg naar je.',
      );
      expect(
        statusZin(uitvoerKlus(status: HhKlusStatus.bezig)),
        'Sanne is bij je aan het werk.',
      );
      expect(
        statusZin(uitvoerKlus(status: HhKlusStatus.geaccepteerd)),
        'Sanne komt je helpen.',
      );
      expect(
        statusZin(uitvoerKlus(status: HhKlusStatus.afgerond)),
        'Sanne heeft de klus gedaan.',
      );
    });

    test('B11: wacht op het belletje van de meldkamer', () {
      final klus = HhKlus.vanRecord(
        RecordModel.fromJson({
          'id': 'k1',
          'collectionId': 'c',
          'collectionName': 'hh_klussen',
          'status': 'open',
          'klus_goedgekeurd_op': '',
          'wacht_op_kennismaking': true,
        }),
      );
      expect(statusZin(klus), TekstenKlusNl.wachtOpBelletje);
    });

    test('geen enkele zin bevat een cijfer (ouderenregel)', () {
      for (final status in HhKlusStatus.values) {
        final zin = statusZin(uitvoerKlus(status: status));
        expect(zin, isNot(matches(RegExp(r'\d'))), reason: status.name);
        expect(zin, isNotEmpty, reason: status.name);
      }
    });
  });

  group('isOverigeKlus', () {
    test('alleen de categorie Overig, hoofdletters maken niet uit', () {
      expect(isOverigeKlus(uitvoerKlus()), isFalse);
      expect(isOverigeKlus(uitvoerKlus(klustypeNaam: 'Overig')), isTrue);
      expect(isOverigeKlus(uitvoerKlus(klustypeNaam: 'overig ')), isTrue);
    });
  });
}
