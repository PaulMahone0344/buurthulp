// B11: "Te doen" van de meldkamer in de a11y-sweep: geen overloop op
// 320/390/430 bij 100 en 200 procent tekst, en op 390 bij 100 procent de
// richtlijnen voor labels, tikvlak en contrast. Alle vier de lijsten vol,
// met lange namen en een klus die op het belletje wacht.

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/pb/fake_meldkamer_gateway.dart';
import 'package:heitjehulp_app/features/coordinator/model/hh_te_doen.dart';
import 'package:heitjehulp_app/features/coordinator/paden_coordinator.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';

import 'sweep_steun.dart';

FakeMeldkamerGateway _vol() => FakeMeldkamerGateway(
  stand: HhTeDoen(
    bellen: const [
      HhTeBellen(
        id: 'b1',
        naam: 'Mevrouw Wilhelmina van der Heijden-Bakker',
        telefoon: '06 1234 5678',
        plaats: 'Wadenoijen',
      ),
      HhTeBellen(id: 'b2', naam: 'Kees', telefoon: '', plaats: ''),
    ],
    helpers: [
      HhTeKeurenHelper(
        profielId: 'p1',
        gebruikerId: 'u1',
        naam: 'Mohammed-Amin Abdelkader',
        geboortedatum: DateTime.utc(2010, 3, 1),
        aangemeldOp: null,
      ),
    ],
    ouders: const [HhOuderIngetrokken(helperId: 'h1', naam: 'Daan')],
    klussen: const [
      HhTeKeurenKlus(
        id: 'k1',
        bewonerNaam: 'Mevrouw Wilhelmina van der Heijden-Bakker',
        soort: 'boodschappen',
        omschrijving:
            'Elke week de boodschappen halen bij de supermarkt aan de '
            'Westluidensestraat en ze in de keuken op tafel zetten.',
        wanneerVan: null,
        wanneerTot: null,
        wachtOpBelletje: true,
      ),
    ],
  ),
);

void main() {
  testWidgets('Te doen past op 320/390/430 bij 100 en 200%', (tester) async {
    final bevindingen = await sweep(
      tester,
      rol: HhRol.coordinator,
      paden: [HhPadenCoordinator.teDoen],
      data: const SweepData(meldkamer: _vol),
    );
    expect(bevindingen, isEmpty, reason: bevindingen.join('\n'));
  });
}
