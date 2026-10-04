import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/jongere/klussen/domein/mijn_klussen_indeling.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../../support/hh_klussen_wikkel.dart';

// B5: de tabbladen zijn nu Gereageerd / Gepland / Klaar (mockup HMijnKlussen).
// Een toegewezen klus staat bij Gepland (vandaag of later) of bij Klaar;
// Gereageerd komt uit de reacties (zie reactie_regels_test.dart).
void main() {
  final nu = DateTime(2026, 9, 15, 10); // dinsdag 15 september, 10:00 lokaal

  group('indelingVan', () {
    test('gepland: vandaag (ook als het tijdstip voorbij is) en later', () {
      for (final moment in [
        DateTime(2026, 9, 15, 8),
        DateTime(2026, 9, 15, 23, 59),
        DateTime(2026, 9, 16, 0, 0),
      ]) {
        expect(
          indelingVan(testKlus(id: 'a', wanneerVan: moment), nu),
          MijnKlussenTab.gepland,
          reason: '$moment',
        );
      }
    });

    test(
      'klaar: voor vandaag, of afgerond/geannuleerd/probleem ongeacht de datum',
      () {
        expect(
          indelingVan(
            testKlus(id: 'a', wanneerVan: DateTime(2026, 9, 14, 23, 59)),
            nu,
          ),
          MijnKlussenTab.klaar,
        );
        for (final status in [
          HhKlusStatus.afgerond,
          HhKlusStatus.geannuleerd,
          HhKlusStatus.probleem,
        ]) {
          expect(
            indelingVan(
              testKlus(
                id: 'b',
                status: status,
                wanneerVan: DateTime(2026, 9, 20),
              ),
              nu,
            ),
            MijnKlussenTab.klaar,
            reason: status.name,
          );
        }
      },
    );

    test('actieve statussen van vandaag: gepland', () {
      for (final status in [
        HhKlusStatus.geaccepteerd,
        HhKlusStatus.onderweg,
        HhKlusStatus.bezig,
      ]) {
        expect(
          indelingVan(
            testKlus(
              id: 'a',
              status: status,
              wanneerVan: DateTime(2026, 9, 15, 14),
            ),
            nu,
          ),
          MijnKlussenTab.gepland,
          reason: status.name,
        );
      }
    });

    test('nooit in Gereageerd (dat zijn reacties, geen klussen)', () {
      final klus = testKlus(id: 'a', status: HhKlusStatus.geaccepteerd);
      expect(indelingVan(klus, nu), isNot(MijnKlussenTab.gereageerd));
    });

    test(
      'UTC: een klus om 23:30 UTC hoort bij de LOKALE dag waarop hij valt',
      () {
        final moment = DateTime.utc(2026, 9, 15, 23, 30);
        final lokaleDag = DateTime(
          moment.toLocal().year,
          moment.toLocal().month,
          moment.toLocal().day,
        );
        final vandaag = DateTime(nu.year, nu.month, nu.day);
        final verwacht = lokaleDag.isBefore(vandaag)
            ? MijnKlussenTab.klaar
            : MijnKlussenTab.gepland;
        expect(
          indelingVan(testKlus(id: 'a', wanneerVan: moment), nu),
          verwacht,
        );
        expect(
          indelingVan(testKlus(id: 'a', wanneerVan: moment), nu.toUtc()),
          verwacht,
        );
      },
    );
  });

  group('deelIn', () {
    test('verdeelt en sorteert: gepland oplopend, klaar aflopend', () {
      final klussen = [
        testKlus(
          id: 'h1',
          status: HhKlusStatus.afgerond,
          wanneerVan: DateTime(2026, 9, 10),
        ),
        testKlus(
          id: 'h2',
          status: HhKlusStatus.afgerond,
          wanneerVan: DateTime(2026, 9, 12),
        ),
        testKlus(id: 'g2', wanneerVan: DateTime(2026, 9, 20)),
        testKlus(id: 'g1', wanneerVan: DateTime(2026, 9, 16)),
        testKlus(id: 'v2', wanneerVan: DateTime(2026, 9, 15, 16)),
        testKlus(id: 'v1', wanneerVan: DateTime(2026, 9, 15, 11)),
      ];
      final per = deelIn(klussen, nu);
      expect(per[MijnKlussenTab.gepland]!.map((k) => k.id), [
        'v1',
        'v2',
        'g1',
        'g2',
      ]);
      expect(per[MijnKlussenTab.klaar]!.map((k) => k.id), ['h2', 'h1']);
      expect(per[MijnKlussenTab.gereageerd], isEmpty);
    });

    test('elk tabblad bestaat, ook leeg', () {
      final per = deelIn(const [], nu);
      expect(per.keys, containsAll(MijnKlussenTab.values));
      expect(per.values.every((l) => l.isEmpty), isTrue);
    });

    test('de tabbladen heten Gereageerd, Gepland, Klaar (in die volgorde)', () {
      expect(MijnKlussenTab.values.map((t) => t.naam), [
        'Gereageerd',
        'Gepland',
        'Klaar',
      ]);
    });
  });
}
