// M12 — loopt elk vast scherm van de app langs per rol, op 320, 390 en 430
// breed en met tekstschaal 1.0 en 2.0, en meldt elke layoutfout (overflow,
// afgekapte rij, onbegrensde hoogte). Vervangt de schermcheck van het
// overgeslagen M11.
//
// De test faalt pas aan het eind, met de volledige lijst, zodat één run
// laat zien waar het misgaat.

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/features/coordinator/paden_coordinator.dart';
import 'package:heitjehulp_app/features/hulpvrager/paden_hulpvrager.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/paden_status.dart';
import 'package:heitjehulp_app/features/hulpvrager/veiligheid/paden_veiligheid.dart';
import 'package:heitjehulp_app/features/jongere/klussen/paden_klussen.dart';
import 'package:heitjehulp_app/features/jongere/paden_jongere.dart';
import 'package:heitjehulp_app/features/meldingen/paden_meldingen.dart';
import 'package:heitjehulp_app/features/reacties/paden_reacties.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';

import 'sweep_steun.dart';

final schermenPerRol = <HhRol?, List<String>>{
  null: [
    HhPaden.welkom,
    HhPaden.inloggen,
    HhPaden.registreren,
    HhPaden.wachtwoordVergeten,
    HhPaden.hulp,
  ],
  HhRol.hulpvrager: [
    HhPaden.hulpvrager,
    HhPadenHulpvrager.hulpVragenWat,
    HhPadenHulpvrager.hulpVragenVerstuurd,
    HhPadenHulpvrager.gegevens,
    HhPadenStatus.hulpvragen,
    HhPadenVeiligheid.belOns,
    HhPadenVeiligheid.probleem,
    HhPadenMeldingen.overzicht,
    HhPaden.instellingen,
    HhPadenReacties.kies('k-sweep'), // B5 (leeg: geen reacties)
  ],
  HhRol.jongere: [
    HhPaden.jongere,
    HhPadenJongere.overzicht,
    HhPadenJongere.identiteit,
    HhPadenJongere.vog,
    HhPadenJongere.overMij,
    HhPadenJongere.binnen,
    HhPadenOuder.ouder, // B3
    HhPadenKlussen.mijnKlussen,
    HhPadenReacties.verstuurd('k-sweep', ouder: true), // B5
    HhPadenKlussen.profiel,
    HhPadenKlussen.instellingen,
    HhPadenMeldingen.overzicht,
  ],
  HhRol.coordinator: [
    HhPaden.coordinator,
    HhPadenCoordinator.klussen,
    HhPadenCoordinator.instellingen,
  ],
};

void main() {
  testWidgets('elk vast scherm past op 320/390/430 bij tekst 100 en 200%', (
    tester,
  ) async {
    final bevindingen = <String>[
      for (final MapEntry(key: rol, value: paden) in schermenPerRol.entries)
        ...await sweep(tester, rol: rol, paden: paden),
    ];
    for (final b in bevindingen) {
      // ignore: avoid_print
      print(b);
    }
    expect(bevindingen, isEmpty, reason: '${bevindingen.length} layoutfouten');
  });

  testWidgets('B2: aanmelden als strijder past ook (uitgelogd, rol strijder)', (
    tester,
  ) async {
    final bevindingen = await sweep(
      tester,
      rol: null,
      gekozenRol: HhRol.jongere,
      paden: const [HhPaden.registreren],
    );
    for (final b in bevindingen) {
      // ignore: avoid_print
      print(b);
    }
    expect(bevindingen, isEmpty, reason: '${bevindingen.length} layoutfouten');
  });
}
