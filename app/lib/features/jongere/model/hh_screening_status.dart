import '../../../l10n/teksten_jongere_nl.dart';

/// De statusmachine van de screening: nieuw > in_behandeling > goedgekeurd
/// of afgewezen. Geldt voor hh_profielen.verificatiestatus en vog_status.
/// De server kent geen standaardwaarde op een keuzeveld; een leeg veld
/// telt als nieuw (backend 06-screening-rules.mjs doet hetzelfde).
enum HhScreeningStatus {
  nieuw('nieuw'),
  inBehandeling('in_behandeling'),
  goedgekeurd('goedgekeurd'),
  afgewezen('afgewezen');

  const HhScreeningStatus(this.code);

  final String code;

  static HhScreeningStatus vanCode(String? code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return HhScreeningStatus.nieuw;
  }

  String get naam => switch (this) {
    HhScreeningStatus.nieuw => TekstenJongereNl.statusNieuw,
    HhScreeningStatus.inBehandeling => TekstenJongereNl.statusInBehandeling,
    HhScreeningStatus.goedgekeurd => TekstenJongereNl.statusGoedgekeurd,
    HhScreeningStatus.afgewezen => TekstenJongereNl.statusAfgewezen,
  };

  /// Alleen vanuit nieuw mag de jongere zelf indienen (server-rule).
  bool get kanIndienen => this == HhScreeningStatus.nieuw;
}
