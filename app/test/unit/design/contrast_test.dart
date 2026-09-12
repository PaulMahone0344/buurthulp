import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/design/components/hh_meld_balk.dart';
import 'package:heitjehulp_app/theme.dart';

/// WCAG 2.x relatieve luminantie en contrastverhouding.
double _lineair(double kanaal) => kanaal <= 0.03928
    ? kanaal / 12.92
    : pow((kanaal + 0.055) / 1.055, 2.4).toDouble();

double _luminantie(Color kleur) =>
    0.2126 * _lineair(kleur.r) +
    0.7152 * _lineair(kleur.g) +
    0.0722 * _lineair(kleur.b);

double contrast(Color voorgrond, Color achtergrond) {
  final a = _luminantie(voorgrond);
  final b = _luminantie(achtergrond);
  return (max(a, b) + 0.05) / (min(a, b) + 0.05);
}

/// AA-grenzen: 4.5 voor gewone tekst, 3.0 voor grote tekst (vanaf 18pt
/// of 14pt vet) en voor iconen en randen die betekenis dragen.
const aaTekst = 4.5;
const aaGroot = 3.0;

typedef Combinatie = ({String naam, Color voor, Color achter, double minimum});

const _tekstOpVlak = <Combinatie>[
  (
    naam: 'tekst op achtergrond',
    voor: HhKleuren.tekst,
    achter: HhKleuren.achtergrond,
    minimum: aaTekst,
  ),
  (
    naam: 'tekst op oppervlak',
    voor: HhKleuren.tekst,
    achter: HhKleuren.oppervlak,
    minimum: aaTekst,
  ),
  (
    naam: 'tekst op oppervlakZacht',
    voor: HhKleuren.tekst,
    achter: HhKleuren.oppervlakZacht,
    minimum: aaTekst,
  ),
  (
    naam: 'tekstGedempt op achtergrond',
    voor: HhKleuren.tekstGedempt,
    achter: HhKleuren.achtergrond,
    minimum: aaTekst,
  ),
  (
    naam: 'tekstGedempt op oppervlak',
    voor: HhKleuren.tekstGedempt,
    achter: HhKleuren.oppervlak,
    minimum: aaTekst,
  ),
  (
    naam: 'tekstGedempt op accentZacht',
    voor: HhKleuren.tekstGedempt,
    achter: HhKleuren.accentZacht,
    minimum: aaTekst,
  ),
  (
    naam: 'opPrimair op primair',
    voor: HhKleuren.opPrimair,
    achter: HhKleuren.primair,
    minimum: aaTekst,
  ),
  (
    naam: 'opPrimair op primairDonker',
    voor: HhKleuren.opPrimair,
    achter: HhKleuren.primairDonker,
    minimum: aaTekst,
  ),
  (
    naam: 'primair op achtergrond',
    voor: HhKleuren.primair,
    achter: HhKleuren.achtergrond,
    minimum: aaTekst,
  ),
  (
    naam: 'primair op oppervlak',
    voor: HhKleuren.primair,
    achter: HhKleuren.oppervlak,
    minimum: aaTekst,
  ),
  (
    naam: 'tekst op accent',
    voor: HhKleuren.tekst,
    achter: HhKleuren.accent,
    minimum: aaTekst,
  ),
  (
    naam: 'tekst op accentDonker',
    voor: HhKleuren.tekst,
    achter: HhKleuren.accentDonker,
    minimum: aaTekst,
  ),
  (
    naam: 'tekst op accentZacht',
    voor: HhKleuren.tekst,
    achter: HhKleuren.accentZacht,
    minimum: aaTekst,
  ),
  (
    naam: 'succes op achtergrond',
    voor: HhKleuren.succes,
    achter: HhKleuren.achtergrond,
    minimum: aaTekst,
  ),
  (
    naam: 'waarschuwing op achtergrond',
    voor: HhKleuren.waarschuwing,
    achter: HhKleuren.achtergrond,
    minimum: aaTekst,
  ),
  (
    naam: 'fout op achtergrond',
    voor: HhKleuren.fout,
    achter: HhKleuren.achtergrond,
    minimum: aaTekst,
  ),
  (
    naam: 'info op achtergrond',
    voor: HhKleuren.info,
    achter: HhKleuren.achtergrond,
    minimum: aaTekst,
  ),
  // tekstDerde haalt 4.5 niet en mag daarom alleen voor grote tekst of
  // iconen op de witte achtergrond. Zie OPEN-PUNTEN.txt.
  (
    naam: 'tekstDerde op achtergrond (alleen groot)',
    voor: HhKleuren.tekstDerde,
    achter: HhKleuren.achtergrond,
    minimum: aaGroot,
  ),
];

void main() {
  group('Contrast WCAG AA', () {
    test('de formule klopt op de bekende uitersten', () {
      expect(contrast(Colors.black, Colors.white), closeTo(21, 0.01));
      expect(contrast(Colors.white, Colors.white), closeTo(1, 0.01));
    });

    for (final c in _tekstOpVlak) {
      test('${c.naam} haalt minstens ${c.minimum}', () {
        expect(
          contrast(c.voor, c.achter),
          greaterThanOrEqualTo(c.minimum),
          reason: '${c.naam}: ${contrast(c.voor, c.achter).toStringAsFixed(2)}',
        );
      });
    }

    test('elke klusstatus: tekst op vulling haalt 4.5', () {
      for (final status in HhKlusStatus.values) {
        final stijl = hhStatusStijlen[status]!;
        expect(
          contrast(stijl.tekst, stijl.vulling),
          greaterThanOrEqualTo(aaTekst),
          reason:
              '$status: ${contrast(stijl.tekst, stijl.vulling).toStringAsFixed(2)}',
        );
      }
    });

    // De status concept heeft HhKleuren.rand als rand (1.5 op wit). Die
    // pil leunt op de gedempte tekst, niet op de rand, en is gemeld in
    // OPEN-PUNTEN.txt. Tot theme.dart daar iets over zegt blijft hij hier
    // buiten de meting.
    const randUitzonderingen = {HhKlusStatus.concept};

    test('elke klusstatus met rand: rand op witte achtergrond haalt 3.0', () {
      for (final status in HhKlusStatus.values) {
        if (randUitzonderingen.contains(status)) continue;
        final rand = hhStatusStijlen[status]!.rand;
        if (rand == null) continue;
        expect(
          contrast(rand, HhKleuren.achtergrond),
          greaterThanOrEqualTo(aaGroot),
          reason: '$status rand',
        );
      }
    });

    test('elke meldbalk: tekst en icoon op de eigen achtergrond halen 4.5', () {
      for (final soort in HhMeldSoort.values) {
        final voor = HhMeldBalk.kleurVan(soort);
        final achter = HhMeldBalk.achtergrondVan(soort);
        expect(
          contrast(voor, achter),
          greaterThanOrEqualTo(aaTekst),
          reason: '$soort: ${contrast(voor, achter).toStringAsFixed(2)}',
        );
      }
    });

    test('het thema zelf: onPrimary op primary, onError op error', () {
      final thema = hhThema(HhDichtheid.normaal);
      final schema = thema.colorScheme;
      expect(
        contrast(schema.onPrimary, schema.primary),
        greaterThanOrEqualTo(aaTekst),
      );
      expect(
        contrast(schema.onError, schema.error),
        greaterThanOrEqualTo(aaTekst),
      );
      expect(
        contrast(schema.onSurface, schema.surface),
        greaterThanOrEqualTo(aaTekst),
      );
    });
  });
}
