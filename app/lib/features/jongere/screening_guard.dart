import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/paden.dart';
import '../toegang/model/hh_rol.dart';
import '../toegang/model/sessie_state.dart';
import 'klussen/paden_klussen.dart';
import 'model/screening_stap.dart';
import 'paden_jongere.dart';

/// Uitbreiding van de router-guard (M3). Loopt pas als [toegangRedirect]
/// niets te zeggen had, dus alleen met een ingelogde gebruiker op een pad
/// dat bij zijn rol hoort.
///
/// - Een jongere zonder profiel of met een andere status dan goedgekeurd
///   komt vanaf /jongere (en vanaf elk M5-klussenpad: mijn klussen, klus,
///   profiel, instellingen) op het screeningoverzicht (J9). Zolang het
///   profiel nog laadt (of niet kon laden) blijft hij waar hij is; de
///   landing toont de laadstaat of de fout.
/// - Een andere rol op een screening- of klussenpad gaat naar zijn eigen
///   rolroute (M4 OPEN-PUNT 39, voor de paden van de jongere).
String? screeningRedirect(
  SessieState sessie,
  AsyncValue<ScreeningGegevens> stand,
  String locatie,
) {
  if (sessie is! SessieIngelogd) return null;
  final gebruiker = sessie.gebruiker;
  final isJongerePad =
      HhPadenJongere.isScreeningPad(locatie) ||
      HhPadenKlussen.isKlussenPad(locatie);
  if (gebruiker.rol != HhRol.jongere) {
    return isJongerePad ? gebruiker.rol.pad : null;
  }
  if (locatie != HhPaden.jongere && !HhPadenKlussen.isKlussenPad(locatie)) {
    return null;
  }
  return switch (stand) {
    AsyncData<ScreeningGegevens>(:final value) when !value.isGoedgekeurd =>
      HhPadenJongere.overzicht,
    _ => null,
  };
}
