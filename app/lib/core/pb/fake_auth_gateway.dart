import '../../features/toegang/domein/aanmelding.dart';
import '../../features/toegang/domein/werkgebied.dart';
import '../../features/toegang/model/hh_gebruiker.dart';
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
  Future<Result<HhGebruiker>> registreren(HhAanmelding aanmelding) async {
    final email = aanmelding.email;
    laatsteRegistratieBody = {
      ...aanmelding.velden,
      'naam': aanmelding.naam,
      'email': email,
      'rol': aanmelding.rol.code,
      'taal': HhTaal.nl.code,
    };
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    if (_accounts.containsKey(email)) {
      return Result.err(const HhFout(HhFoutSoort.emailBestaatAl));
    }
    final gebruiker = HhGebruiker(
      id: 'fake-${_accounts.length + 1}',
      naam: aanmelding.naam,
      email: email,
      rol: aanmelding.rol,
      // Zoals de server (B2): een postcode in de buurt van Tiel (40xx) geeft
      // de regio-wijk, al het andere ligt buiten het werkgebied.
      wijkId: _isBijTiel(aanmelding) ? fakeRegioWijk : '',
      werkgebiedStatus: _isBijTiel(aanmelding)
          ? HhWerkgebiedStatus.binnen
          : HhWerkgebiedStatus.buiten,
    );
    final account = FakeAccount(
      gebruiker: gebruiker,
      wachtwoord: aanmelding.wachtwoord,
      token: 'token-${gebruiker.id}',
    );
    _accounts[email] = account;
    aantalVerificatieAanvragen++;
    return _logIn(account);
  }

  /// Id van de wijk "Tiel en omstreken" in de fakes.
  static const fakeRegioWijk = 'wijk-regio';

  static bool _isBijTiel(HhAanmelding aanmelding) =>
      '${aanmelding.velden['postcode'] ?? ''}'.startsWith('40');

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
