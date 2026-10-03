import '../../../app/paden.dart';
import '../../../l10n/teksten_nl.dart';

/// De drie rollen (B3: de familie-rol is weg; een oud account met rol
/// "familie" kan niet meer inloggen, zie HhGebruiker.vanRecord). De [code] is precies
/// de keuzewaarde van hh_users.rol op de server.
enum HhRol {
  hulpvrager('hulpvrager'),
  jongere('jongere'),
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

  /// Alleen bewoner en helper registreren zichzelf (backend OPEN-PUNT 9).
  bool get kanZelfRegistreren => this != HhRol.coordinator;

  /// Waar deze rol landt na inloggen.
  String get pad => switch (this) {
    HhRol.hulpvrager => HhPaden.hulpvrager,
    HhRol.jongere => HhPaden.jongere,
    HhRol.coordinator => HhPaden.coordinator,
  };

  String get naam => switch (this) {
    HhRol.hulpvrager => TekstenNl.rolHulpvrager,
    HhRol.jongere => TekstenNl.rolJongere,
    HhRol.coordinator => TekstenNl.rolCoordinator,
  };
}
