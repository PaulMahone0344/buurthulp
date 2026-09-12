import '../../../app/paden.dart';
import '../../../l10n/teksten_nl.dart';
import '../../../theme.dart';

/// De vier rollen uit hoofdstuk 2 van het app-plan. De [code] is precies
/// de keuzewaarde van hh_users.rol op de server.
enum HhRol {
  hulpvrager('hulpvrager'),
  jongere('jongere'),
  familie('familie'),
  coordinator('coordinator');

  const HhRol(this.code);

  final String code;

  /// Null bij een onbekende waarde; de aanroeper beslist wat dan.
  static HhRol? vanCode(String? code) {
    for (final rol in values) {
      if (rol.code == code) return rol;
    }
    return null;
  }

  /// Alleen deze drie mogen zichzelf registreren (backend OPEN-PUNT 9).
  bool get kanZelfRegistreren => this != HhRol.coordinator;

  /// De hulpvrager krijgt de grote dichtheid; alle andere rollen normaal.
  HhDichtheid get dichtheid =>
      this == HhRol.hulpvrager ? HhDichtheid.groot : HhDichtheid.normaal;

  /// Waar deze rol landt na inloggen.
  String get pad => switch (this) {
    HhRol.hulpvrager => HhPaden.hulpvrager,
    HhRol.jongere => HhPaden.jongere,
    HhRol.familie => HhPaden.familie,
    HhRol.coordinator => HhPaden.coordinator,
  };

  String get naam => switch (this) {
    HhRol.hulpvrager => TekstenNl.rolHulpvrager,
    HhRol.jongere => TekstenNl.rolJongere,
    HhRol.familie => TekstenNl.rolFamilie,
    HhRol.coordinator => TekstenNl.rolCoordinator,
  };
}
