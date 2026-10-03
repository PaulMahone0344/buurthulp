import '../../toegang/domein/aanmelding.dart';
import '../../toegang/domein/werkgebied.dart';
import '../model/hh_screening_status.dart';
import '../ouder/model/hh_ouder_stand.dart';
import '../model/screening_stap.dart';

/// Waar een helper op wacht voordat hij klussen ziet (B2). De app toont
/// het eerste ontbrekende ding; de server houdt hetzelfde tegen (80-rules
/// en de accepteer-hook).
enum HelperWacht {
  /// Nog niet verstuurd: hij hoort op "Je aanmelding" (J9).
  aanmelden,

  /// Afgewezen door de meldkamer: ook J9 (met "Bel ons").
  afgewezen,

  /// Geen wijk: buiten het werkgebied (Tiel + 20 km). Geen klussen.
  nietInBuurt,

  /// Geen wijk omdat de server het adres niet kon vinden (geocoding
  /// mislukt); de meldkamer ziet de markering.
  adresOnbekend,

  /// Verstuurd, de meldkamer kijkt hem na (in_behandeling). Ook bij een
  /// goedgekeurde helper zonder geboortedatum (dat lost de meldkamer op).
  nagekeken,

  /// Onder de 18 en de ouder gaf nog geen toestemming (B3: ook tijdens het
  /// nakijken; eerst de ouder, dan de meldkamer).
  ouder,

  /// B3: de ouder trok zijn toestemming in.
  ouderIngetrokken,

  /// 18 of ouder en de meldkamer zag de VOG nog niet.
  vog,

  /// Alles rond: klussen.
  klaar;

  /// Hoort de helper op de aanmeldschermen (J9) in plaats van Start?
  bool get isAanmelden => this == aanmelden || this == afgewezen;

  /// Ziet hij Start met de gele balk (en geen klussen)?
  bool get heeftBalk =>
      this == nietInBuurt ||
      this == adresOnbekend ||
      this == nagekeken ||
      this == ouder ||
      this == ouderIngetrokken ||
      this == vog;
}

HelperWacht helperWacht(ScreeningGegevens gegevens, DateTime vandaag) {
  switch (gegevens.verificatiestatus) {
    case HhScreeningStatus.nieuw:
      return HelperWacht.aanmelden;
    case HhScreeningStatus.afgewezen:
      return HelperWacht.afgewezen;
    case HhScreeningStatus.inBehandeling:
    case HhScreeningStatus.goedgekeurd:
      break;
  }
  // Zonder wijk ziet hij nooit klussen: dat eerst zeggen.
  if (gegevens.account.wijkId.isEmpty) {
    return gegevens.account.werkgebiedStatus == HhWerkgebiedStatus.onbekend
        ? HelperWacht.adresOnbekend
        : HelperWacht.nietInBuurt;
  }
  final geboren = gegevens.account.geboortedatum;
  final isJong = geboren != null && isMinderjarig(geboren, vandaag);
  // B3: onder 18 eerst de ouder (de server kijkt naar ouder_toestemming_op).
  if (isJong && gegevens.account.ouderToestemmingOp == null) {
    return gegevens.ouder?.status == HhOuderStatus.ingetrokken
        ? HelperWacht.ouderIngetrokken
        : HelperWacht.ouder;
  }
  if (gegevens.verificatiestatus == HhScreeningStatus.inBehandeling) {
    return HelperWacht.nagekeken;
  }
  if (geboren == null) return HelperWacht.nagekeken;
  if (isJong) return HelperWacht.klaar;
  return gegevens.profiel?.vogGezienOp == null
      ? HelperWacht.vog
      : HelperWacht.klaar;
}
