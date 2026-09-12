import '../../core/config.dart';
import '../../l10n/teksten_nl.dart';

/// Pure controles voor de formulieren van G3, G4 en G6. De client-controle
/// is voor de gebruiker; de server-controle is de echte.
final _emailPatroon = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? valideerNaam(String waarde) =>
    waarde.trim().isEmpty ? TekstenNl.validatieNaamVerplicht : null;

String? valideerEmail(String waarde) {
  final schoon = waarde.trim();
  if (schoon.isEmpty) return TekstenNl.validatieEmailVerplicht;
  if (!_emailPatroon.hasMatch(schoon)) return TekstenNl.validatieEmailOngeldig;
  return null;
}

String? valideerWachtwoord(String waarde) =>
    waarde.length < HhConfig.wachtwoordMinLengte
    ? TekstenNl.validatieWachtwoordTeKort
    : null;
