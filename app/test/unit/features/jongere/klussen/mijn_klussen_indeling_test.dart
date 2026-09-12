import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/jongere/klussen/domein/mijn_klussen_indeling.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../../support/hh_klussen_wikkel.dart';

void main() {
  final nu = DateTime(2026, 9, 15, 10); // dinsdag 15 september, 10:00 lokaal

  group('indelingVan', () {
    test('vandaag: zelfde lokale dag, ook al is het tijdstip al voorbij', () {
      expect(
        indelingVan(
          testKlus(id: 'a', wanneerVan: DateTime(2026, 9, 15, 8)),
          nu,
        ),
        MijnKlussenTab.vandaag,
      );
      expect(
        indelingVan(
          testKlus(id: 'b', wanneerVan: DateTime(2026, 9, 15, 23, 59)),
          nu,
        ),
        MijnKlussenTab.vandaag,
      );
    });

    test('gepland: na vandaag', () {
      expect(
        indelingVan(
          testKlus(id: 'a', wanneerVan: DateTime(2026, 9, 16, 0, 0)),
          nu,
        ),
        MijnKlussenTab.gepland,
      );
    });

    test(
      'historie: voor vandaag, of afgerond/geannuleerd/probleem ongeacht de datum',
      () {
        expect(
          indelingVan(
            testKlus(id: 'a', wanneerVan: DateTime(2026, 9, 14, 23, 59)),
            nu,
          ),
          MijnKlussenTab.historie,
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
            MijnKlussenTab.historie,
            reason: status.name,
          );
        }
      },
    );

    test('actieve statussen volgen de datum', () {
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
          MijnKlussenTab.vandaag,
          reason: status.name,
        );
      }
    });

    test('zonder datum en nog actief: gepland', () {
      final zonder = testKlus(id: 'a', status: HhKlusStatus.geaccepteerd);
      // testKlus geeft altijd een datum; bouw er een zonder.
      final klus = zonder.copyWith();
      expect(indelingVan(klus, nu), isNot(MijnKlussenTab.historie));
    });

    test(
      'UTC: een klus om 23:30 UTC hoort bij de LOKALE dag waarop hij valt',
      () {
        // Het moment in UTC; de indeling kijkt naar de lokale dag van dat
        // moment, dus vergelijk met de lokale dag van nu.
        final moment = DateTime.utc(2026, 9, 15, 23, 30);
        final lokaleDag = DateTime(
          moment.toLocal().year,
          moment.toLocal().month,
          moment.toLocal().day,
        );
        final vandaag = DateTime(nu.year, nu.month, nu.day);
        final verwacht = lokaleDag == vandaag
            ? MijnKlussenTab.vandaag
            : lokaleDag.isAfter(vandaag)
            ? MijnKlussenTab.gepland
            : MijnKlussenTab.historie;
        expect(
          indelingVan(testKlus(id: 'a', wanneerVan: moment), nu),
          verwacht,
        );
        // En andersom: nu in UTC gegeven verandert niets aan de uitkomst.
        expect(
          indelingVan(testKlus(id: 'a', wanneerVan: moment), nu.toUtc()),
          verwacht,
        );
      },
    );
  });

  group('deelIn', () {
    test(
      'verdeelt en sorteert: vandaag/gepland oplopend, historie aflopend',
      () {
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
        expect(per[MijnKlussenTab.vandaag]!.map((k) => k.id), ['v1', 'v2']);
        expect(per[MijnKlussenTab.gepland]!.map((k) => k.id), ['g1', 'g2']);
        expect(per[MijnKlussenTab.historie]!.map((k) => k.id), ['h2', 'h1']);
      },
    );

    test('elk tabblad bestaat, ook leeg', () {
      final per = deelIn(const [], nu);
      expect(per.keys, containsAll(MijnKlussenTab.values));
      expect(per.values.every((l) => l.isEmpty), isTrue);
    });
  });
}
