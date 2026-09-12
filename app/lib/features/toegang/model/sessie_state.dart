import '../../../core/hh_fout.dart';
import 'hh_gebruiker.dart';

/// Waarom iemand uitgelogd is; bepaalt de melding op G3.
enum UitlogReden {
  /// Gewoon niet ingelogd, of zelf uitgelogd.
  geen,

  /// 401 van de server: token verlopen of ingetrokken.
  sessieVerlopen,

  /// Account zojuist gewist (G7).
  accountGewist,
}

/// De toestanden van de sessie. [SessieOnbekend] alleen tijdens het
/// opstarten, tot het bewaarde token is gecontroleerd; daarna altijd
/// uitgelogd, bezig of ingelogd.
sealed class SessieState {
  const SessieState();
}

/// Nog aan het controleren of er een bewaard token is. Met [fout] gevuld
/// is de controle mislukt door geen verbinding: het token blijft bewaard
/// en de splash biedt opnieuw proberen aan.
final class SessieOnbekend extends SessieState {
  const SessieOnbekend({this.fout});

  final HhFout? fout;
}

final class SessieUitgelogd extends SessieState {
  const SessieUitgelogd({this.reden = UitlogReden.geen});

  final UitlogReden reden;
}

/// Registreren, inloggen of herstellen loopt.
final class SessieBezig extends SessieState {
  const SessieBezig();
}

final class SessieIngelogd extends SessieState {
  const SessieIngelogd(this.gebruiker);

  final HhGebruiker gebruiker;
}
