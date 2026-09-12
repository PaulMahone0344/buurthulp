import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/paden.dart';
import '../toegang/model/hh_rol.dart';
import '../toegang/model/sessie_state.dart';
import 'model/screening_stap.dart';
import 'paden_jongere.dart';

/// Uitbreiding van de router-guard (M3). Loopt pas als [toegangRedirect]
/// niets te zeggen had, dus alleen met een ingelogde gebruiker op een pad
/// dat bij zijn rol hoort.
///
/// - Een jongere zonder profiel of met een andere status dan goedgekeurd
///   komt vanaf /jongere op het screeningoverzicht (J9). Zolang het profiel
///   nog laadt (of niet kon laden) blijft hij op de landing; die toont de
///   laadstaat of de fout.
/// - Een andere rol op een screeningpad gaat naar zijn eigen rolroute.
String? screeningRedirect(
  SessieState sessie,
  AsyncValue<ScreeningGegevens> stand,
  String locatie,
) {
  if (sessie is! SessieIngelogd) return null;
  final gebruiker = sessie.gebruiker;
  if (gebruiker.rol != HhRol.jongere) {
    return HhPadenJongere.isScreeningPad(locatie) ? gebruiker.rol.pad : null;
  }
  if (locatie != HhPaden.jongere) return null;
  return switch (stand) {
    AsyncData<ScreeningGegevens>(:final value) when !value.isGoedgekeurd =>
      HhPadenJongere.overzicht,
    _ => null,
  };
}
