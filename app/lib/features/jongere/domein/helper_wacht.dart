import '../../toegang/domein/aanmelding.dart';
import '../model/hh_screening_status.dart';
import '../model/screening_stap.dart';

/// Waar een helper op wacht voordat hij klussen ziet (B2). De app toont
/// het eerste ontbrekende ding; de server houdt hetzelfde tegen (80-rules
/// en de accepteer-hook).
enum HelperWacht {
  /// Nog niet verstuurd: hij hoort op "Je aanmelding" (J9).
  aanmelden,

  /// Afgewezen door de meldkamer: ook J9 (met "Bel ons").
  afgewezen,

  /// Verstuurd, de meldkamer kijkt hem na (in_behandeling). Ook bij een
  /// goedgekeurde helper zonder geboortedatum (dat lost de meldkamer op).
  nagekeken,

  /// Onder de 18 en de ouder gaf nog geen toestemming.
  ouder,

  /// 18 of ouder en de meldkamer zag de VOG nog niet.
  vog,

  /// Alles rond: klussen.
  klaar;

  /// Hoort de helper op de aanmeldschermen (J9) in plaats van Start?
  bool get isAanmelden => this == aanmelden || this == afgewezen;

  /// Ziet hij Start met de gele balk (en geen klussen)?
  bool get heeftBalk => this == nagekeken || this == ouder || this == vog;
}

HelperWacht helperWacht(ScreeningGegevens gegevens, DateTime vandaag) {
  switch (gegevens.verificatiestatus) {
    case HhScreeningStatus.nieuw:
      return HelperWacht.aanmelden;
    case HhScreeningStatus.afgewezen:
      return HelperWacht.afgewezen;
    case HhScreeningStatus.inBehandeling:
      return HelperWacht.nagekeken;
    case HhScreeningStatus.goedgekeurd:
      break;
  }
  final geboren = gegevens.account.geboortedatum;
  if (geboren == null) return HelperWacht.nagekeken;
  if (isMinderjarig(geboren, vandaag)) {
    return gegevens.account.ouderToestemmingOp == null
        ? HelperWacht.ouder
        : HelperWacht.klaar;
  }
  return gegevens.profiel?.vogGezienOp == null
      ? HelperWacht.vog
      : HelperWacht.klaar;
}
