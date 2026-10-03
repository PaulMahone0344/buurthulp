import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/paden.dart';
import '../toegang/model/hh_rol.dart';
import '../toegang/model/sessie_state.dart';
import 'domein/helper_wacht.dart';
import 'klussen/paden_klussen.dart';
import 'model/hh_screening_status.dart';
import 'model/screening_stap.dart';
import 'ouder/model/hh_ouder_stand.dart';
import 'paden_jongere.dart';

/// Uitbreiding van de router-guard (M3, B2). Loopt pas als
/// [toegangRedirect] niets te zeggen had, dus alleen met een ingelogde
/// gebruiker op een pad dat bij zijn rol hoort.
///
/// - Een helper (rol jongere) die nog niet verstuurde of is afgewezen komt
///   vanaf /jongere (en vanaf elk klussenpad) op "Je aanmelding" (J9).
/// - Een helper die nog wacht (nagekeken, ouder-toestemming, VOG) blijft op
///   Start (/jongere, met de gele balk) en de tabs Mijn klussen, Profiel en
///   Instellingen; een klus openen kan niet (terug naar Start).
/// - Zolang de gegevens laden (of niet konden laden) blijft hij waar hij is;
///   de schermen tonen de laadstaat of de fout.
/// - Een andere rol op een aanmeld- of klussenpad gaat naar zijn eigen
///   rolroute (M4 OPEN-PUNT 39).
String? screeningRedirect(
  SessieState sessie,
  AsyncValue<ScreeningGegevens> stand,
  String locatie, {
  DateTime Function() klok = DateTime.now,
}) {
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
  if (stand is! AsyncData<ScreeningGegevens>) return null;
  final wacht = helperWacht(stand.value, klok());
  if (wacht.isAanmelden) {
    return moetEerstNaarOuder(stand.value, klok())
        ? HhPadenOuder.ouder
        : HhPadenJongere.overzicht;
  }
  if (wacht.heeftBalk && locatie.startsWith('${HhPadenKlussen.klus}/')) {
    return HhPaden.jongere;
  }
  return null;
}

/// B3: net aangemeld, onder 18 en er ging nog geen mail naar de ouder: dan
/// eerst de stap "Ouder" (die stuurt de mail meteen). Zonder stand (route
/// nog niet op de server) gewoon naar "Je aanmelding", zoals in B2.
bool moetEerstNaarOuder(ScreeningGegevens gegevens, DateTime vandaag) =>
    gegevens.verificatiestatus == HhScreeningStatus.nieuw &&
    gegevens.isMinderjarigOp(vandaag) == true &&
    gegevens.ouder?.status == HhOuderStatus.geen;
