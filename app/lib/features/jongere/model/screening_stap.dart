import 'package:flutter/foundation.dart';

import '../../../l10n/teksten_aanmelden_nl.dart';
import '../../../l10n/teksten_jongere_nl.dart';
import '../../toegang/domein/aanmelding.dart';
import '../paden_jongere.dart';
import 'hh_profiel.dart';
import 'hh_screening_status.dart';

/// Alles wat de aanmeldschermen van de helper nodig hebben, in een object:
/// het profiel (null zolang het nog niet bestaat) en de accountvelden uit
/// hh_users.
@immutable
class ScreeningGegevens {
  const ScreeningGegevens({
    this.profiel,
    this.account = const HhAccountGegevens(),
  });

  final HhProfiel? profiel;
  final HhAccountGegevens account;

  /// Zonder profiel is de status nieuw: er is nog niets ingediend.
  HhScreeningStatus get verificatiestatus =>
      profiel?.verificatiestatus ?? HhScreeningStatus.nieuw;

  bool get isGoedgekeurd => verificatiestatus == HhScreeningStatus.goedgekeurd;

  /// Onder de 18 op [vandaag]. Zonder geboortedatum: null (onbekend).
  bool? isMinderjarigOp(DateTime vandaag) {
    final geboren = account.geboortedatum;
    return geboren == null ? null : isMinderjarig(geboren, vandaag);
  }

  ScreeningGegevens copyWith({HhProfiel? profiel, HhAccountGegevens? account}) {
    return ScreeningGegevens(
      profiel: profiel ?? this.profiel,
      account: account ?? this.account,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ScreeningGegevens &&
      other.profiel == profiel &&
      other.account == account;

  @override
  int get hashCode => Object.hash(profiel, account);
}

/// Wat een helper na het aanmeldformulier nog doet (B2): een foto van zijn
/// ID (verplicht), zijn VOG (alleen 18+, de meldkamer kijkt hem na) en
/// "Over mij" (mag leeg). Selfie, IBAN, werkgebied, beschikbaarheid en
/// klussoorten zijn geen stap meer.
enum ScreeningStap {
  identiteit,
  vog,
  overMij;

  /// De stappen voor deze helper: VOG alleen vanaf 18 (of als de leeftijd
  /// onbekend is; dan beslist de meldkamer).
  static List<ScreeningStap> voor(
    ScreeningGegevens gegevens,
    DateTime vandaag,
  ) => [
    ScreeningStap.identiteit,
    if (gegevens.isMinderjarigOp(vandaag) != true) ScreeningStap.vog,
    ScreeningStap.overMij,
  ];

  String get titel => switch (this) {
    ScreeningStap.identiteit => TekstenJongereNl.j2Titel,
    ScreeningStap.vog => TekstenJongereNl.j4Titel,
    ScreeningStap.overMij => TekstenAanmeldenNl.overMijNietVerplicht,
  };

  String get pad => switch (this) {
    ScreeningStap.identiteit => HhPadenJongere.identiteit,
    ScreeningStap.vog => HhPadenJongere.vog,
    ScreeningStap.overMij => HhPadenJongere.overMij,
  };

  /// Alleen de ID-foto moet er zijn voordat de helper kan versturen. De VOG
  /// kan weken duren; daarvoor is de wachtbalk.
  bool get isVerplicht => this == ScreeningStap.identiteit;

  /// Is deze stap af, gezien de gegevens die nu op de server staan.
  bool isAf(ScreeningGegevens gegevens) {
    final profiel = gegevens.profiel;
    if (profiel == null) return false;
    return switch (this) {
      ScreeningStap.identiteit =>
        profiel.heeftDocumentFoto || profiel.isIdGecontroleerd,
      ScreeningStap.vog =>
        profiel.vogGezienOp != null || profiel.vogAangevraagdOp != null,
      ScreeningStap.overMij => profiel.overMij.trim().isNotEmpty,
    };
  }
}

/// Mag de knop "Aanmelding versturen" actief zijn: de ID-foto staat er en er
/// is nog niet ingediend (server-rule: alleen nieuw -> in_behandeling).
bool kanTerControleAanbieden(ScreeningGegevens gegevens) =>
    ScreeningStap.identiteit.isAf(gegevens) &&
    gegevens.verificatiestatus.kanIndienen;
