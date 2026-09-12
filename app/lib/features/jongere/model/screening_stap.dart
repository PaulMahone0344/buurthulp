import 'package:flutter/foundation.dart';

import '../../../l10n/teksten_jongere_nl.dart';
import '../paden_jongere.dart';
import 'hh_profiel.dart';
import 'hh_screening_status.dart';

/// Alles wat de screeningschermen nodig hebben, in een object: het profiel
/// (null zolang het nog niet bestaat) en de accountvelden uit hh_users.
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

  HhScreeningStatus get vogStatus =>
      profiel?.vogStatus ?? HhScreeningStatus.nieuw;

  bool get isGoedgekeurd => verificatiestatus == HhScreeningStatus.goedgekeurd;

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

/// De acht stappen J1-J8. J9 is het overzicht en geen stap.
enum ScreeningStap {
  profiel,
  identiteit,
  selfie,
  vog,
  iban,
  werkgebied,
  beschikbaarheid,
  klussoorten;

  int get nummer => index + 1;

  static int get totaal => values.length;

  String get titel => switch (this) {
    ScreeningStap.profiel => TekstenJongereNl.j1Titel,
    ScreeningStap.identiteit => TekstenJongereNl.j2Titel,
    ScreeningStap.selfie => TekstenJongereNl.j3Titel,
    ScreeningStap.vog => TekstenJongereNl.j4Titel,
    ScreeningStap.iban => TekstenJongereNl.j5Titel,
    ScreeningStap.werkgebied => TekstenJongereNl.j6Titel,
    ScreeningStap.beschikbaarheid => TekstenJongereNl.j7Titel,
    ScreeningStap.klussoorten => TekstenJongereNl.j8Titel,
  };

  String get pad => switch (this) {
    ScreeningStap.profiel => HhPadenJongere.profiel,
    ScreeningStap.identiteit => HhPadenJongere.identiteit,
    ScreeningStap.selfie => HhPadenJongere.selfie,
    ScreeningStap.vog => HhPadenJongere.vog,
    ScreeningStap.iban => HhPadenJongere.iban,
    ScreeningStap.werkgebied => HhPadenJongere.werkgebied,
    ScreeningStap.beschikbaarheid => HhPadenJongere.beschikbaarheid,
    ScreeningStap.klussoorten => HhPadenJongere.klussoorten,
  };

  /// Waar "opslaan en verder" heen gaat: de volgende stap, na J8 het
  /// overzicht.
  String get volgendPad => this == ScreeningStap.klussoorten
      ? HhPadenJongere.overzicht
      : values[index + 1].pad;

  /// Is deze stap af, gezien de gegevens die nu op de server staan.
  bool isAf(ScreeningGegevens gegevens) {
    final profiel = gegevens.profiel;
    final account = gegevens.account;
    return switch (this) {
      ScreeningStap.profiel =>
        account.heeftFoto &&
            account.geboortedatum != null &&
            (profiel?.overMij.trim().isNotEmpty ?? false),
      ScreeningStap.identiteit => profiel?.heeftDocumentFoto ?? false,
      ScreeningStap.selfie => profiel?.heeftSelfie ?? false,
      ScreeningStap.vog =>
        profiel != null &&
            (profiel.vogAangevraagdOp != null ||
                profiel.vogStatus != HhScreeningStatus.nieuw),
      ScreeningStap.iban => profiel?.iban.isNotEmpty ?? false,
      ScreeningStap.werkgebied =>
        account.wijkId.isNotEmpty && (profiel?.straalKm ?? 0) > 0,
      ScreeningStap.beschikbaarheid =>
        !(profiel?.beschikbaarheid.isLeeg ?? true),
      ScreeningStap.klussoorten => profiel?.klustypeIds.isNotEmpty ?? false,
    };
  }

  static bool alleAf(ScreeningGegevens gegevens) =>
      values.every((stap) => stap.isAf(gegevens));
}

/// Mag de knop "Ter controle aanbieden" actief zijn: alle stappen af en
/// nog niet ingediend (server-rule: alleen nieuw -> in_behandeling).
bool kanTerControleAanbieden(ScreeningGegevens gegevens) =>
    ScreeningStap.alleAf(gegevens) && gegevens.verificatiestatus.kanIndienen;
