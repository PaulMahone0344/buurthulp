// M12 — dezelfde schermsweep als schermen_sweep_test, maar met gevulde
// fakes: lijsten met klussen, meldingen en koppelingen, en de
// detailschermen die een id nodig hebben (klusdetail, uitvoeren,
// beoordelen, hulpvraag-status, oudere bij familie, coordinator-klus en
// -incident). Lege lijsten verbergen juist de langste regels.

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/pb/fake_beoordeling_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_coordinator_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_familie_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_klus_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_klussen_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_meldingen_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_uitvoer_gateway.dart';
import 'package:heitjehulp_app/features/coordinator/paden_coordinator.dart';
import 'package:heitjehulp_app/features/familie/paden_familie.dart';
import 'package:heitjehulp_app/features/hulpvrager/beoordelen/paden_beoordelen.dart';
import 'package:heitjehulp_app/features/hulpvrager/paden_hulpvrager.dart';
import 'package:heitjehulp_app/features/hulpvrager/provider/hulpvrager_providers.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/paden_status.dart';
import 'package:heitjehulp_app/features/hulpvrager/veiligheid/paden_veiligheid.dart';
import 'package:heitjehulp_app/features/jongere/klussen/paden_klussen.dart';
import 'package:heitjehulp_app/features/jongere/reputatie/paden_reputatie.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/paden_uitvoeren.dart';
import 'package:heitjehulp_app/features/meldingen/paden_meldingen.dart';
import 'package:heitjehulp_app/features/jongere/klussen/model/hh_klus.dart';
import 'package:heitjehulp_app/features/meldingen/model/hh_melding.dart';
import 'package:heitjehulp_app/theme.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';

import '../support/hh_coordinator_wikkel.dart';
import '../support/hh_familie_wikkel.dart';
import '../support/hh_hulpvrager_wikkel.dart';
import '../support/hh_jongere_wikkel.dart';
import '../support/hh_klussen_wikkel.dart';
import '../support/hh_meldingen_wikkel.dart';
import '../support/hh_uitvoeren_wikkel.dart';
import 'sweep_steun.dart';

// Lange teksten met opzet: dit is waar een regel het eerst afbreekt.
const langeOmschrijving =
    'Weekboodschappen bij de Jumbo aan de Stationsstraat, lijstje ligt op '
    'de keukentafel naast de fruitschaal, graag ook de apotheek meenemen.';

List<HhKlus> ouderenKlussen() => [
  uitvoerKlus(id: 'k-g', omschrijving: langeOmschrijving),
  uitvoerKlus(id: 'k-o', status: HhKlusStatus.open, metJongere: false),
  uitvoerKlus(id: 'k-af', status: HhKlusStatus.afgerond),
];

List<HhMelding> meldingen(String ontvanger) => [
  testMelding(id: 'm1', ontvanger: ontvanger),
  testMelding(
    id: 'm2',
    ontvanger: ontvanger,
    titel: 'Uw hulpvraag is aangenomen door Sanne',
    tekst: langeOmschrijving,
    gelezen: true,
  ),
];

void main() {
  testWidgets('schermen met data passen op 320/390/430 bij 100 en 200%', (
    tester,
  ) async {
    final bevindingen = <String>[];

    // Jongere: open klus, eigen klus onderweg, afgeronde klus.
    bevindingen.addAll(
      await sweep(
        tester,
        rol: HhRol.jongere,
        paden: [
          HhPaden.jongere,
          HhPadenKlussen.mijnKlussen,
          HhPadenKlussen.klusDetail('k1'),
          HhPadenUitvoeren.uitvoeren('k-u'),
          HhPadenReputatie.beoordelen('k-af'),
          HhPadenMeldingen.overzicht,
        ],
        data: SweepData(
          klussen: () => FakeKlussenGateway(
            jongereId: jongereId,
            klussen: [
              testKlus(id: 'k1', omschrijving: langeOmschrijving),
              testKlus(
                id: 'k2',
                status: HhKlusStatus.geaccepteerd,
                toegewezenJongereId: jongereId,
              ),
            ],
          ),
          uitvoer: () => FakeUitvoerGateway(
            ikBenId: jongereId,
            klussen: [
              uitvoerKlus(id: 'k-u', status: HhKlusStatus.onderweg),
              uitvoerKlus(id: 'k-af', status: HhKlusStatus.afgerond),
            ],
            logregels: uitvoerLogregels('k-u', HhKlusStatus.onderweg),
          ),
          beoordeling: () => FakeBeoordelingGateway(
            ikBenId: jongereId,
            klussen: [uitvoerKlus(id: 'k-af', status: HhKlusStatus.afgerond)],
          ),
          meldingen: () =>
              FakeMeldingenGateway(meldingen: meldingen(jongereId)),
        ),
      ),
    );

    // Hulpvrager (groot): lijst, status, beoordelen, probleem bij een klus.
    bevindingen.addAll(
      await sweep(
        tester,
        rol: HhRol.hulpvrager,
        paden: [
          HhPaden.hulpvrager,
          HhPadenStatus.hulpvragen,
          HhPadenStatus.hulpvraag('k-g'),
          HhPadenBeoordelen.beoordelen('k-af'),
          HhPadenVeiligheid.probleemBij('k-g'),
          HhPadenHulpvrager.hulpVragenWat,
          HhPadenHulpvrager.gegevens,
          HhPadenMeldingen.overzicht,
        ],
        data: SweepData(
          uitvoer: () =>
              FakeUitvoerGateway(ikBenId: oudereId, klussen: ouderenKlussen()),
          beoordeling: () => FakeBeoordelingGateway(
            ikBenId: oudereId,
            klussen: ouderenKlussen(),
          ),
          meldingen: () => FakeMeldingenGateway(meldingen: meldingen(oudereId)),
          extra: () => [
            klusGatewayProvider.overrideWithValue(
              FakeKlusGateway(
                klustypes: testKlustypes,
                gegevens: {oudereId: testGegevens()},
              ),
            ),
          ],
        ),
      ),
    );

    // Familie: actieve koppeling met de test-oudere.
    bevindingen.addAll(
      await sweep(
        tester,
        rol: HhRol.familie,
        paden: [
          HhPaden.familie,
          HhPadenFamilie.oudere(oudereId),
          HhPadenFamilie.hulpvraag(oudereId, 'k-g'),
        ],
        data: SweepData(
          familie: () => FakeFamilieGateway(koppelingen: [testKoppeling()]),
          uitvoer: () =>
              FakeUitvoerGateway(ikBenId: familieId, klussen: ouderenKlussen()),
        ),
      ),
    );

    // Coordinator: open en toegewezen klus, een incident.
    bevindingen.addAll(
      await sweep(
        tester,
        rol: HhRol.coordinator,
        paden: [
          HhPaden.coordinator,
          HhPadenCoordinator.klussen,
          HhPadenCoordinator.klusDetail('c1'),
          HhPadenCoordinator.incidentDetail('i1'),
        ],
        data: SweepData(
          coordinator: () => FakeCoordinatorGateway(
            incidenten: [
              testIncident(
                id: 'i1',
                klusId: 'c1',
                klusOmschrijving: langeOmschrijving,
              ),
            ],
            klussen: [
              testCoordinatorKlus(id: 'c1', omschrijving: langeOmschrijving),
              testCoordinatorKlus(
                id: 'c2',
                status: HhKlusStatus.geaccepteerd,
                toegewezenJongereId: 'j2',
                toegewezenJongereNaam: 'Mohammed El Amrani-Verhoeven',
              ),
            ],
          ),
        ),
      ),
    );

    for (final b in bevindingen) {
      // ignore: avoid_print
      print(b);
    }
    expect(bevindingen, isEmpty, reason: '${bevindingen.length} layoutfouten');
  });
}
