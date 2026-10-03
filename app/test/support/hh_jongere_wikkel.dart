import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heitjehulp_app/app/app.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/core/pb/fake_ouder_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_profiel_gateway.dart';
import 'package:heitjehulp_app/design/components/hh_knop.dart';
import 'package:heitjehulp_app/design/components/hh_scherm.dart';
import 'package:heitjehulp_app/design/dichtheid_scope.dart';
import 'package:heitjehulp_app/features/jongere/foto_kiezer.dart';
import 'package:heitjehulp_app/features/jongere/jongere_routes.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_profiel.dart';
import 'package:heitjehulp_app/features/jongere/model/hh_screening_status.dart';
import 'package:heitjehulp_app/features/jongere/screen/jongere_stub_screen.dart';
import 'package:heitjehulp_app/features/toegang/domein/werkgebied.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/l10n/teksten_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import 'hh_toegang_wikkel.dart';

/// De test-jongere uit hh_toegang_wikkel.
String get jongereId => testGebruiker(HhRol.jongere).id;

/// Kleinste geldige PNG (1x1), zodat Image.memory niets te klagen heeft.
final Uint8List testFotoBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
);

HhFoto testFoto([String naam = 'foto.png']) =>
    HhFoto(bytes: testFotoBytes, bestandsnaam: naam);

/// Geboortedatum van een helper van 13 en van een van 26 (in 2026).
final jongGeboren = DateTime.utc(2013, 3, 1);
final volwassenGeboren = DateTime.utc(2000, 5, 14);

/// Helper net na het aanmeldformulier: geboortedatum, nog geen profiel.
FakeProfielGateway fakeNieuweJongere({bool isMinderjarig = false}) =>
    FakeProfielGateway(
      accounts: {
        jongereId: HhAccountGegevens(
          geboortedatum: isMinderjarig ? jongGeboren : volwassenGeboren,
          wijkId: 'wijk-west',
        ),
      },
    );

/// Helper met een profiel in een gegeven staat.
FakeProfielGateway fakeJongereMet({
  required HhProfiel profiel,
  HhAccountGegevens account = const HhAccountGegevens(),
}) => FakeProfielGateway(
  profielen: {jongereId: profiel},
  accounts: {jongereId: account},
);

/// ID-foto staat er, nog niet verstuurd (status nieuw): J9 mag versturen.
FakeProfielGateway fakeJongereKlaarOmInTeDienen({bool isMinderjarig = false}) =>
    fakeJongereMet(
      profiel: HhProfiel(
        id: 'profiel-$jongereId',
        gebruikerId: jongereId,
        documentFoto: 'document_1.jpg',
      ),
      account: HhAccountGegevens(
        geboortedatum: isMinderjarig ? jongGeboren : volwassenGeboren,
        wijkId: 'wijk-west',
      ),
    );

/// Een volwassen helper met VOG gezien, in [status].
FakeProfielGateway fakeJongereMetStatus(HhScreeningStatus status) {
  final fake = FakeProfielGateway.goedgekeurd(jongereId);
  fake.zetStatus(jongereId, verificatiestatus: status);
  return fake;
}

/// Rond (goedgekeurd, VOG gezien), maar zonder wijk: buiten het
/// werkgebied, of het adres werd niet gevonden ([werkgebied] onbekend).
FakeProfielGateway fakeJongereBuitenGebied({
  HhWerkgebiedStatus werkgebied = HhWerkgebiedStatus.buiten,
}) {
  final fake = FakeProfielGateway.goedgekeurd(jongereId);
  fake.zetAccount(
    jongereId,
    HhAccountGegevens(
      geboortedatum: volwassenGeboren,
      werkgebiedStatus: werkgebied,
    ),
  );
  return fake;
}

/// Goedgekeurd, maar nog wachtend: onder 18 zonder ouder-toestemming
/// ([isMinderjarig]) of 18+ zonder VOG gezien.
FakeProfielGateway fakeJongereGoedgekeurdWachtend({
  bool isMinderjarig = false,
}) {
  final fake = FakeProfielGateway.goedgekeurd(jongereId);
  fake.zetVogGezien(jongereId, null);
  if (isMinderjarig) {
    fake.zetAccount(
      jongereId,
      HhAccountGegevens(geboortedatum: jongGeboren, wijkId: 'wijk-west'),
    );
  }
  return fake;
}

/// Een screeningscherm op zijn eigen route, met de echte jongere-routes en
/// een stub voor /jongere, maar zonder guard. Zo werken context.go en
/// context.push in de schermtests.
Widget hhJongereWikkel(
  String pad, {
  required FakeProfielGateway profielGateway,
  FakeFotoKiezer? fotoKiezer,
  FakeOuderGateway? ouderGateway,
  SessieState? sessie,
  bool urlOpenerLukt = true,
  HhDichtheid dichtheid = HhDichtheid.normaal,
  double tekstschaal = 1.0,
}) {
  final container = toegangContainer(
    gateway: fakeMetAlleRollen(),
    sessie: sessie ?? SessieIngelogd(testGebruiker(HhRol.jongere)),
    urlOpenerLukt: urlOpenerLukt,
    profielGateway: profielGateway,
    fotoKiezer: fotoKiezer ?? FakeFotoKiezer(),
    ouderGateway: ouderGateway,
  );
  final router = GoRouter(
    initialLocation: pad,
    routes: [
      GoRoute(
        path: HhPaden.jongere,
        builder: (context, state) => const JongereStubScreen(),
      ),
      ...jongereRoutes(),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      theme: hhThema(dichtheid),
      routerConfig: router,
      builder: (context, kind) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(tekstschaal)),
        child: HhDichtheidScope(dichtheid: dichtheid, child: kind!),
      ),
    ),
  );
}

/// De hele app met router en guard, met een eigen profiel-fake.
Future<ProviderContainer> pompJongereApp(
  WidgetTester tester, {
  required FakeProfielGateway profielGateway,
  FakeFotoKiezer? fotoKiezer,
  FakeOuderGateway? ouderGateway,
  GeheugenKeyValueStore? opslag,
  bool urlOpenerLukt = true,
}) async {
  final container = toegangContainer(
    gateway: fakeMetAlleRollen(),
    opslag: opslag,
    profielGateway: profielGateway,
    fotoKiezer: fotoKiezer ?? FakeFotoKiezer(),
    urlOpenerLukt: urlOpenerLukt,
    ouderGateway: ouderGateway,
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const HeitjeHulpApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Scrolt de knop in beeld en tikt erop.
Future<void> tikKnop(WidgetTester tester, String label) async {
  final knop = find.widgetWithText(HhKnop, label);
  await tester.ensureVisible(knop);
  await tester.tap(knop);
  await tester.pumpAndSettle();
}

Future<void> tikTekst(WidgetTester tester, String tekst) async {
  final doel = find.text(tekst).first;
  await tester.ensureVisible(doel);
  await tester.tap(doel);
  await tester.pumpAndSettle();
}

Future<void> vulVeld(WidgetTester tester, int index, String tekst) async {
  final veld = find.byType(TextField).at(index);
  await tester.ensureVisible(veld);
  await tester.enterText(veld, tekst);
}

/// Elke knop heeft een label en is een knop; elk invoerveld heeft een
/// label; elke terugknop zegt "Terug". Zelfde controle als in de M2-tests.
void controleerSemantiek(WidgetTester tester) {
  for (final knop in find.byType(HhKnop).evaluate()) {
    final semantiek = tester.getSemantics(find.byWidget(knop.widget));
    expect(semantiek.label, isNotEmpty, reason: 'knop zonder label');
    expect(
      semantiek.getSemanticsData().flagsCollection.isButton,
      isTrue,
      reason: 'knop ${semantiek.label} is geen knop voor de schermlezer',
    );
  }
  for (final terug in find.byType(HhTerugKnop).evaluate()) {
    final semantiek = tester.getSemantics(find.byWidget(terug.widget));
    expect(semantiek.label, TekstenNl.terug);
  }
  for (final veld in find.byType(TextField).evaluate()) {
    final semantiek = tester.getSemantics(find.byWidget(veld.widget));
    expect(semantiek.label, isNotEmpty, reason: 'invoerveld zonder label');
  }
}
