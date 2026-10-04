import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/hulpvrager/start/bewoner_agenda.dart';
import 'package:heitjehulp_app/features/jongere/klussen/model/hh_klus.dart';
import 'package:heitjehulp_app/theme.dart';

import '../../../support/hh_uitvoeren_wikkel.dart';

// Donderdag 1 oktober 2026, 10:00 (lokaal).
final _nu = DateTime(2026, 10, 1, 10);

void main() {
  final vandaag = uitvoerKlus(
    id: 'vandaag',
    status: HhKlusStatus.geaccepteerd,
    wanneerVan: DateTime(2026, 10, 1, 16),
  );
  final zondag = uitvoerKlus(
    id: 'zondag',
    status: HhKlusStatus.open,
    metJongere: false,
    wanneerVan: DateTime(2026, 10, 4, 11),
  );
  final volgendeWeek = uitvoerKlus(
    id: 'volgende',
    status: HhKlusStatus.open,
    metJongere: false,
    wanneerVan: DateTime(2026, 10, 8, 9),
  );
  final november = uitvoerKlus(
    id: 'nov',
    status: HhKlusStatus.geaccepteerd,
    wanneerVan: DateTime(2026, 11, 2, 9),
  );
  final gisteren = uitvoerKlus(
    id: 'gisteren',
    status: HhKlusStatus.geaccepteerd,
    wanneerVan: DateTime(2026, 9, 30, 9),
  );
  final klaar = uitvoerKlus(
    id: 'klaar',
    status: HhKlusStatus.afgerond,
    wanneerVan: DateTime(2026, 10, 2, 9),
  );
  final alle = [november, klaar, zondag, gisteren, volgendeWeek, vandaag];

  test('aankomend: open of gepland, vandaag of later, eerstvolgende eerst', () {
    expect(aankomendeKlussen(alle, _nu).map((k) => k.id), [
      'vandaag',
      'zondag',
      'volgende',
      'nov',
    ]);
  });

  test('de week loopt van maandag tot en met zondag', () {
    final week = weekVan(_nu);
    expect(week.first, DateTime(2026, 9, 28));
    expect(week.last, DateTime(2026, 10, 4));
    expect(week, hasLength(7));
    expect(
      weekVan(DateTime(2026, 10, 4, 23)).first,
      DateTime(2026, 9, 28),
      reason: 'zondag hoort bij dezelfde week',
    );
  });

  test('periode dag, week en maand', () {
    final a = aankomendeKlussen(alle, _nu);
    expect(
      a.where((k) => inPeriode(k, AgendaPeriode.dag, _nu)).map((k) => k.id),
      ['vandaag'],
    );
    expect(
      a.where((k) => inPeriode(k, AgendaPeriode.week, _nu)).map((k) => k.id),
      ['vandaag', 'zondag'],
    );
    expect(
      a.where((k) => inPeriode(k, AgendaPeriode.maand, _nu)).map((k) => k.id),
      ['vandaag', 'zondag', 'volgende'],
    );
    const zonderDatum = HhKlus(
      id: 'x',
      hulpvragerId: 'b',
      status: HhKlusStatus.open,
    );
    expect(inPeriode(zonderDatum, AgendaPeriode.maand, _nu), isTrue);
  });

  test('aantal per dag (stip in de weekstrook)', () {
    final a = aankomendeKlussen(alle, _nu);
    expect(aantalOpDag(a, DateTime(2026, 10, 1)), 1);
    expect(aantalOpDag(a, DateTime(2026, 10, 3)), 0);
  });

  test('nieuwe reacties tellen alleen op open klussen', () {
    expect(
      nieuweReacties([
        zondag.copyWith(reactiesAantal: 3),
        vandaag.copyWith(reactiesAantal: 2),
      ]),
      3,
    );
    expect(nieuweReacties(const []), 0);
  });

  test('status-woord: zoekt strijder, wordt nagekeken, bevestigd, bezig', () {
    expect(agendaStatus(zondag), AgendaStatus.zoektHelper);
    expect(
      agendaStatus(
        uitvoerKlus(
          status: HhKlusStatus.open,
          metJongere: false,
          wordtNagekeken: true,
        ),
      ),
      AgendaStatus.wordtNagekeken,
    );
    expect(agendaStatus(vandaag), AgendaStatus.bevestigd);
    expect(
      agendaStatus(uitvoerKlus(status: HhKlusStatus.onderweg)),
      AgendaStatus.bezig,
    );
  });
}
