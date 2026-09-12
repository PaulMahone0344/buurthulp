import '../../features/toegang/model/hh_gebruiker.dart';
import '../../features/toegang/model/hh_rol.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'auth_gateway.dart';

/// Nep-account in het geheugen van de fake: wat de test erin stopt.
class FakeAccount {
  const FakeAccount({
    required this.gebruiker,
    required this.wachtwoord,
    required this.token,
  });

  final HhGebruiker gebruiker;
  final String wachtwoord;
  final String token;
}

/// Fake voor tests en het dev-scherm. Er gaat nooit een verzoek naar de
/// server. Gedrag is stuurbaar: [isOffline] laat alles mislukken met
/// geenVerbinding, [volgendeFout] laat de eerstvolgende aanroep mislukken,
/// [tokenIsVerlopen] laat sessieHerstellen met 401 antwoorden.
class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({Iterable<FakeAccount> accounts = const []}) {
    for (final account in accounts) {
      _accounts[account.gebruiker.email] = account;
    }
  }

  final Map<String, FakeAccount> _accounts = {};

  bool isOffline = false;
  bool tokenIsVerlopen = false;
  HhFout? volgendeFout;

  HhGebruiker? ingelogd;
  String? _token;

  /// Wat de laatste registratie precies meestuurde; tests controleren
  /// hierop dat rol en taal meegaan.
  Map<String, dynamic>? laatsteRegistratieBody;

  /// Wat de laatste bijwerking meestuurde (alleen gewijzigde velden).
  Map<String, dynamic>? laatsteUpdateBody;

  int aantalVerificatieAanvragen = 0;
  int wachtwoordResets = 0;
  final List<String> gewisteAccounts = [];

  FakeAccount? account(String email) => _accounts[email];

  HhFout? _neemFout() {
    if (isOffline) return const HhFout(HhFoutSoort.geenVerbinding);
    final fout = volgendeFout;
    volgendeFout = null;
    return fout;
  }

  @override
  Future<Result<HhGebruiker>> registreren({
    required String naam,
    required String email,
    required String wachtwoord,
    required HhRol rol,
    String? telefoon,
  }) async {
    laatsteRegistratieBody = {
      'naam': naam,
      'email': email,
      'rol': rol.code,
      'taal': HhTaal.nl.code,
      if (telefoon != null && telefoon.isNotEmpty) 'telefoon': telefoon,
    };
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    if (_accounts.containsKey(email)) {
      return Result.err(const HhFout(HhFoutSoort.emailBestaatAl));
    }
    final gebruiker = HhGebruiker(
      id: 'fake-${_accounts.length + 1}',
      naam: naam,
      email: email,
      rol: rol,
      telefoon: telefoon,
    );
    final account = FakeAccount(
      gebruiker: gebruiker,
      wachtwoord: wachtwoord,
      token: 'token-${gebruiker.id}',
    );
    _accounts[email] = account;
    aantalVerificatieAanvragen++;
    return _logIn(account);
  }

  @override
  Future<Result<HhGebruiker>> inloggen({
    required String email,
    required String wachtwoord,
  }) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final account = _accounts[email];
    if (account == null || account.wachtwoord != wachtwoord) {
      return Result.err(const HhFout(HhFoutSoort.ongeldigeInlog));
    }
    return _logIn(account);
  }

  Result<HhGebruiker> _logIn(FakeAccount account) {
    ingelogd = account.gebruiker;
    _token = account.token;
    return Result.ok(account.gebruiker);
  }

  @override
  Future<Result<void>> uitloggen() async {
    ingelogd = null;
    _token = null;
    return Result.ok(null);
  }

  @override
  Future<Result<HhGebruiker>> sessieHerstellen(String token) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    if (tokenIsVerlopen) {
      return Result.err(const HhFout(HhFoutSoort.nietIngelogd));
    }
    for (final account in _accounts.values) {
      if (account.token == token) return _logIn(account);
    }
    return Result.err(const HhFout(HhFoutSoort.nietIngelogd));
  }

  @override
  Future<Result<void>> verificatieAanvragen(String email) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    aantalVerificatieAanvragen++;
    return Result.ok(null);
  }

  @override
  Future<Result<void>> wachtwoordResetAanvragen(String email) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    wachtwoordResets++;
    return Result.ok(null);
  }

  @override
  Future<Result<HhGebruiker>> bijwerken(
    String id,
    Map<String, dynamic> velden,
  ) async {
    laatsteUpdateBody = Map.unmodifiable(velden);
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final huidig = ingelogd;
    if (huidig == null || huidig.id != id) {
      return Result.err(const HhFout(HhFoutSoort.nietGevonden));
    }
    final bijgewerkt = huidig.copyWith(
      naam: velden['naam'] as String?,
      taal: velden.containsKey('taal')
          ? HhTaal.vanCode(velden['taal'] as String?)
          : null,
      telefoon: velden.containsKey('telefoon')
          ? () => velden['telefoon'] as String?
          : null,
    );
    final oud = _accounts[huidig.email]!;
    _accounts[huidig.email] = FakeAccount(
      gebruiker: bijgewerkt,
      wachtwoord: oud.wachtwoord,
      token: oud.token,
    );
    ingelogd = bijgewerkt;
    return Result.ok(bijgewerkt);
  }

  @override
  Future<Result<void>> accountWissen(String id) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final huidig = ingelogd;
    if (huidig == null || huidig.id != id) {
      return Result.err(const HhFout(HhFoutSoort.nietGevonden));
    }
    _accounts.remove(huidig.email);
    gewisteAccounts.add(id);
    ingelogd = null;
    _token = null;
    return Result.ok(null);
  }

  @override
  Future<Result<String>> huidigToken() async => Result.ok(_token ?? '');
}
