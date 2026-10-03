// M12 — gedeelde steun voor de schermsweeps: pompt de app voor één rol op
// een vaste breedte en tekstschaal, gaat naar een pad en vangt elke
// layoutfout die Flutter meldt, met de bronregel in lib/.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/app.dart';
import 'package:heitjehulp_app/app/router.dart';
import 'package:heitjehulp_app/core/key_value_store.dart';
import 'package:heitjehulp_app/core/pb/beoordeling_gateway.dart';
import 'package:heitjehulp_app/core/pb/coordinator_gateway.dart';
import 'package:heitjehulp_app/core/pb/familie_gateway.dart';
import 'package:heitjehulp_app/core/pb/klussen_gateway.dart';
import 'package:heitjehulp_app/core/pb/meldingen_gateway.dart';
import 'package:heitjehulp_app/core/pb/uitvoer_gateway.dart';
import 'package:heitjehulp_app/features/hulpvrager/provider/hulpvrager_providers.dart';
import 'package:heitjehulp_app/features/jongere/klussen/provider/klussen_providers.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/model/sessie_state.dart';

import '../support/hh_klussen_wikkel.dart';
import '../support/hh_toegang_wikkel.dart';

const breedtes = [320.0, 390.0, 430.0];
const hoogte = 760.0;
const tekstschalen = [1.0, 2.0];

const _log = bool.fromEnvironment('SWEEP_LOG');

/// De fakes van één scenario. Alles wat leeg blijft, krijgt de lege fake
/// uit [toegangOverrides]. Een functie, omdat elke pomp verse fakes nodig
/// heeft. [extra] is voor providers buiten toegangOverrides (bv. de
/// klus-gateway van de hulpvrager); nooit een provider die daar al in zit,
/// want Riverpod weigert een dubbele override.
class SweepData {
  const SweepData({
    this.klussen,
    this.uitvoer,
    this.beoordeling,
    this.meldingen,
    this.familie,
    this.coordinator,
    this.extra,
  });

  final KlussenGateway Function()? klussen;
  final UitvoerGateway Function()? uitvoer;
  final BeoordelingGateway Function()? beoordeling;
  final MeldingenGateway Function()? meldingen;
  final FamilieGateway Function()? familie;
  final CoordinatorGateway Function()? coordinator;
  final List<dynamic> Function()? extra;
}

/// Pompt de app voor één rol, gaat naar [pad] en geeft de layoutfouten
/// terug die Flutter tijdens het opbouwen meldde.
Future<List<String>> bekijk(
  WidgetTester tester, {
  required HhRol? rol,
  required String pad,
  required double breedte,
  required double tekstschaal,
  SweepData data = const SweepData(),
  HhRol? gekozenRol,
}) async {
  if (_log) {
    // ignore: avoid_print
    print('-> ${rol?.code} $pad @$breedte x$tekstschaal');
  }

  // Eerst de container: gaat hier iets mis, dan is FlutterError.onError
  // nog niet omgeleid en faalt de test netjes in plaats van te hangen.
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      ...toegangOverrides(
        gateway: fakeMetAlleRollen(),
        opslag: GeheugenKeyValueStore(),
        sessie: rol == null
            ? const SessieUitgelogd()
            : SessieIngelogd(testGebruiker(rol)),
        gekozenRol: gekozenRol ?? rol ?? HhRol.hulpvrager,
        klussenGateway: data.klussen?.call(),
        uitvoerGateway: data.uitvoer?.call(),
        beoordelingGateway: data.beoordeling?.call(),
        meldingenGateway: data.meldingen?.call(),
        familieGateway: data.familie?.call(),
        coordinatorGateway: data.coordinator?.call(),
      ),
      // Nooit het netwerk op: nep-kaarttegels en een vaste klok.
      kaartTegelsProvider.overrideWithValue(NepTegels.new),
      klokProvider.overrideWithValue(() => klussenNu),
      ...?data.extra?.call(),
    ],
  );

  final fouten = <String>[];
  final vorige = FlutterError.onError;
  FlutterError.onError = (details) {
    final regel = details.exceptionAsString().split('\n').first;
    final bron = RegExp(
      r'file:///[^\s:]+/lib/([^\s]+:\d+)',
    ).firstMatch(details.toString())?.group(1);
    fouten.add(bron == null ? regel : '$regel  [$bron]');
  };

  // Richtlijnen (labels, tikvlak, contrast) één keer per scherm: op 390
  // breed bij normale tekst. Dat is waar de app het vaakst gebruikt wordt.
  final richtlijnen = breedte == 390 && tekstschaal == 1.0;
  final semantiek = richtlijnen ? tester.ensureSemantics() : null;

  tester.view.physicalSize = Size(breedte, hoogte);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = tekstschaal;

  try {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const HeitjeHulpApp(),
      ),
    );
    await tester.pump();
    container.read(routerProvider).go(pad);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    if (richtlijnen) {
      for (final regel in [
        labeledTapTargetGuideline,
        androidTapTargetGuideline,
        textContrastGuideline,
      ]) {
        final uitkomst = await regel.evaluate(tester);
        if (!uitkomst.passed) {
          for (final r in (uitkomst.reason ?? '').split('\n\n')) {
            final kort = r.trim().split('\n').first;
            if (kort.isNotEmpty) fouten.add('richtlijn: $kort');
          }
        }
      }
    }
    if (_log) {
      final teksten = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
          .where((s) => s.trim().isNotEmpty)
          .take(6)
          .join(' | ');
      // ignore: avoid_print
      print('   ziet: $teksten');
    }
  } finally {
    FlutterError.onError = vorige;
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    semantiek?.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  }
  return fouten;
}

/// Loopt [paden] langs op alle breedtes en tekstschalen en geeft de
/// bevindingen als leesbare regels terug.
Future<List<String>> sweep(
  WidgetTester tester, {
  required HhRol? rol,
  required List<String> paden,
  SweepData data = const SweepData(),
  HhRol? gekozenRol,
}) async {
  final bevindingen = <String>[];
  for (final pad in paden) {
    for (final breedte in breedtes) {
      for (final schaal in tekstschalen) {
        final fouten = await bekijk(
          tester,
          rol: rol,
          pad: pad,
          breedte: breedte,
          tekstschaal: schaal,
          data: data,
          gekozenRol: gekozenRol,
        );
        for (final f in fouten.toSet()) {
          bevindingen.add(
            '${rol?.code ?? 'uitgelogd'} $pad @${breedte.toInt()} x$schaal: $f',
          );
        }
      }
    }
  }
  return bevindingen;
}
