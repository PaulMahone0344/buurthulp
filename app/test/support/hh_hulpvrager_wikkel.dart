import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/app.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/core/pb/fake_auth_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_beoordeling_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_chat_gateway.dart';
import 'package:heitjehulp_app/features/chat/provider/chat_providers.dart';
import 'package:heitjehulp_app/core/pb/fake_incident_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_meldingen_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_klus_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_uitvoer_gateway.dart';
import 'package:heitjehulp_app/core/pb/gateway_providers.dart';
import 'package:heitjehulp_app/design/dichtheid_scope.dart';
import 'package:heitjehulp_app/features/hulpvrager/model/hh_gegevens.dart';
import 'package:heitjehulp_app/features/hulpvrager/model/hh_klustype.dart';
import 'package:heitjehulp_app/features/hulpvrager/provider/hulpvrager_providers.dart';
import 'package:heitjehulp_app/features/jongere/foto_kiezer.dart';
import 'package:heitjehulp_app/features/jongere/reputatie/provider/beoordeling_providers.dart';
import 'package:heitjehulp_app/features/hulpvrager/veiligheid/provider/veiligheid_providers.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/provider/uitvoeren_providers.dart';
import 'package:heitjehulp_app/features/meldingen/provider/meldingen_providers.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';
import 'package:heitjehulp_app/features/toegang/provider/sessie_providers.dart';
import 'package:heitjehulp_app/features/toegang/screen/hulp_screen.dart';
import 'package:heitjehulp_app/l10n/teksten_hulpvrager_nl.dart';
import 'package:heitjehulp_app/l10n/teksten_klus_nl.dart';
import 'package:heitjehulp_app/theme.dart';

import 'hh_toegang_wikkel.dart';

/// Een vaste "nu" voor de M4-tests: dinsdag 15 september 2026, 10:00.
final testNu = DateTime(2026, 9, 15, 10);

/// De 13 categorieën van B4 (backend/pb_hooks/hh_klusplaatsen_hulp.js),
/// plus één oud klustype van vóór B4 dat niet meer te kiezen is. Kleine
/// klusjes heeft een richtvergoeding, om het doorgeven van bedragen te
/// kunnen zien (op de server is die nu 0; prijzen komen in B7).
const testKlustypes = [
  HhKlustype(
    id: 'kt-tuin',
    naam: 'Tuin',
    icoon: 'yard',
    minLeeftijd: 13,
    volgorde: 1,
  ),
  HhKlustype(
    id: 'kt-auto',
    naam: 'Auto & fiets',
    icoon: 'pedal_bike',
    minLeeftijd: 13,
    volgorde: 2,
  ),
  HhKlustype(
    id: 'kt-schoonmaak',
    naam: 'Schoonmaak',
    icoon: 'cleaning_services',
    minLeeftijd: 16,
    volgorde: 3,
  ),
  HhKlustype(
    id: 'kt-opruimen',
    naam: 'Opruimen',
    icoon: 'inventory_2',
    minLeeftijd: 13,
    volgorde: 4,
  ),
  HhKlustype(
    id: 'kt-boodschappen',
    naam: 'Boodschappen',
    icoon: 'shopping_cart',
    minLeeftijd: 10,
    volgorde: 5,
  ),
  HhKlustype(
    id: 'kt-dieren',
    naam: 'Dieren',
    icoon: 'pets',
    minLeeftijd: 10,
    volgorde: 6,
  ),
  HhKlustype(
    id: 'kt-computer',
    naam: 'Computer',
    icoon: 'computer',
    minLeeftijd: 13,
    volgorde: 7,
  ),
  HhKlustype(
    id: 'kt-rondom',
    naam: 'Rondom huis',
    icoon: 'fence',
    minLeeftijd: 10,
    volgorde: 8,
  ),
  HhKlustype(
    id: 'kt-hand',
    naam: 'Helpende hand',
    icoon: 'favorite_border',
    minLeeftijd: 10,
    volgorde: 9,
  ),
  HhKlustype(
    id: 'kt-creatief',
    naam: 'Creatief',
    icoon: 'brush',
    minLeeftijd: 13,
    volgorde: 10,
  ),
  HhKlustype(
    id: 'kt-klusje',
    naam: 'Kleine klusjes',
    icoon: 'handyman',
    minLeeftijd: 10,
    volgorde: 11,
    richtvergoedingCenten: 1250,
  ),
  HhKlustype(
    id: 'kt-kennis',
    naam: 'Hulp & kennis',
    icoon: 'lightbulb',
    minLeeftijd: 13,
    volgorde: 12,
  ),
  HhKlustype(
    id: 'kt-overig',
    naam: 'Overig',
    icoon: 'more_horiz',
    minLeeftijd: 13,
    volgorde: 13,
  ),
  // Oud (M1-seed), niet actief: mag nooit als tegel verschijnen.
  HhKlustype(
    id: 'kt-vervoer',
    naam: 'vervoer',
    icoon: 'directions_car',
    minLeeftijd: 18,
    isActief: false,
  ),
];

/// Een kleine, echte png (1x1), als de foto van de klus.
final testKlusFoto = HhFoto(
  bytes: base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
  ),
  bestandsnaam: 'klus.png',
);

/// De gegevens van de nep-hulpvrager, met of zonder adres.
HhGegevens testGegevens({bool metAdres = true}) => HhGegevens(
  id: testGebruiker(HhRol.hulpvrager).id,
  naam: testGebruiker(HhRol.hulpvrager).naam,
  telefoon: '0344-100001',
  adres: metAdres ? 'Prins Bernhardlaan 12' : '',
  postcode: metAdres ? '4003 AB' : '',
  plaats: metAdres ? 'Tiel' : '',
  contactNaam: metAdres ? 'Dochter Jansen' : '',
  contactTelefoon: metAdres ? '0612345678' : '',
);

FakeKlusGateway fakeKlusGateway({
  List<HhKlustype> klustypes = testKlustypes,
  bool metAdres = true,
}) => FakeKlusGateway(
  klustypes: klustypes,
  gegevens: {
    testGebruiker(HhRol.hulpvrager).id: testGegevens(metAdres: metAdres),
  },
);

/// Zoals toegangContainer, plus de klus-fake en een vaste klok.
ProviderContainer hulpvragerContainer({
  required FakeKlusGateway klusGateway,
  FakeAuthGateway? authGateway,
  GeheugenKeyValueStore? opslag,
  SessieState? sessie,
  DateTime? nu,
  bool urlOpenerLukt = true,
  FakeUitvoerGateway? uitvoerGateway,
  FakeBeoordelingGateway? beoordelingGateway,
  FakeMeldingenGateway? meldingenGateway,
  FakeIncidentGateway? incidentGateway,
  FakeFotoKiezer? fotoKiezer,
  FakeChatGateway? chatGateway,
}) {
  final container = ProviderContainer(
    // Geen automatische retry (Riverpod 3): een fake die bewust faalt zou
    // anders een Timer achterlaten na het einde van de test.
    retry: (_, _) => null,
    overrides: [
      authGatewayProvider.overrideWithValue(authGateway ?? fakeMetAlleRollen()),
      klusGatewayProvider.overrideWithValue(klusGateway),
      uitvoerGatewayProvider.overrideWithValue(
        uitvoerGateway ?? FakeUitvoerGateway(),
      ),
      // M7: O7 en O8 vragen welke hulpvragen al beoordeeld zijn.
      beoordelingGatewayProvider.overrideWithValue(
        beoordelingGateway ?? FakeBeoordelingGateway(),
      ),
      // M8: de regel op O1 en O11. Standaard lege fakes zonder netwerk.
      meldingenGatewayProvider.overrideWithValue(
        meldingenGateway ?? FakeMeldingenGateway(),
      ),
      incidentGatewayProvider.overrideWithValue(
        incidentGateway ?? FakeIncidentGateway(),
      ),
      // B6: de Chat-knop op O7. Standaard een lege fake.
      chatGatewayProvider.overrideWithValue(chatGateway ?? FakeChatGateway()),
      klokProvider.overrideWithValue(() => nu ?? testNu),
      // B4: de klusfoto. Standaard kiest de fake meteen [testKlusFoto].
      fotoKiezerProvider.overrideWithValue(
        fotoKiezer ?? FakeFotoKiezer(volgende: testKlusFoto),
      ),
      keyValueStoreProvider.overrideWithValue(
        opslag ?? GeheugenKeyValueStore(),
      ),
      urlOpenerProvider.overrideWithValue((_) async => urlOpenerLukt),
      if (sessie != null)
        sessieControllerProvider.overrideWith(() => VasteSessie(sessie)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Een los M4-scherm in het thema, ingelogd als hulpvrager (tenzij anders),
/// zonder go_router. Voor navigatie-knoppen gebruik je pompHulpvragerApp.
Widget hhHulpvragerWikkel(
  Widget scherm, {
  required FakeKlusGateway klusGateway,
  SessieState? sessie,
  HhDichtheid dichtheid = HhDichtheid.groot,
  double tekstschaal = 1.0,
  bool urlOpenerLukt = true,
  ProviderContainer? container,
  FakeUitvoerGateway? uitvoerGateway,
}) {
  return UncontrolledProviderScope(
    container:
        container ??
        hulpvragerContainer(
          klusGateway: klusGateway,
          sessie: sessie ?? SessieIngelogd(testGebruiker(HhRol.hulpvrager)),
          urlOpenerLukt: urlOpenerLukt,
          uitvoerGateway: uitvoerGateway,
        ),
    child: MaterialApp(
      theme: hhThema(dichtheid),
      builder: (context, kind) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(tekstschaal)),
        child: HhDichtheidScope(dichtheid: dichtheid, child: kind!),
      ),
      home: scherm,
    ),
  );
}

/// De hele app met router en guard, ingelogd als hulpvrager via een
/// bewaard token. Landt op O1.
Future<ProviderContainer> pompHulpvragerApp(
  WidgetTester tester, {
  required FakeKlusGateway klusGateway,
  DateTime? nu,
  FakeUitvoerGateway? uitvoerGateway,
  FakeBeoordelingGateway? beoordelingGateway,
}) async {
  final opslag = GeheugenKeyValueStore({
    'hh_auth_token': testToken(HhRol.hulpvrager),
  });
  final container = hulpvragerContainer(
    klusGateway: klusGateway,
    opslag: opslag,
    nu: nu,
    uitvoerGateway: uitvoerGateway,
    beoordelingGateway: beoordelingGateway,
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

/// Vult "Klus plaatsen" helemaal in via de knoppen, zoals een bewoner:
/// categorie, omschrijving, foto (de fake kiest [testKlusFoto]), morgen
/// (standaard 10:00, tijdwiel niet gedraaid) en het nee-lijst-vinkje. Het
/// adres komt uit Mijn gegevens. Tikt NIET op "Klus plaatsen".
Future<void> vulKlusIn(
  WidgetTester tester, {
  String categorie = 'Kleine klusjes',
  String omschrijving = 'Lamp ophangen in de gang.',
}) async {
  Future<void> tik(Finder doel) async {
    await tester.ensureVisible(doel);
    await tester.tap(doel);
    await tester.pumpAndSettle();
  }

  await tik(find.text(categorie));
  final veld = find.byType(TextField).first;
  await tester.ensureVisible(veld);
  await tester.enterText(veld, omschrijving);
  await tester.pumpAndSettle();
  await tik(find.text(TekstenKlusNl.fotoKiezen));
  await tik(find.text(TekstenHulpvragerNl.dagMorgen));
  await tik(find.text(TekstenKlusNl.neeLijstAkkoord));
}
