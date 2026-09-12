import 'package:pocketbase/pocketbase.dart';

import '../../features/toegang/model/hh_gebruiker.dart';
import '../../features/toegang/model/hh_rol.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'pocketbase_gateway.dart';

const hhUsersCollectie = 'hh_users';

/// Alles rond het account: registreren, inloggen, uitloggen, verversen,
/// verificatie en wachtwoord-reset aanvragen, eigen record bijwerken en
/// account wissen. Praat alleen tegen [PocketBaseGateway].
abstract interface class AuthGateway {
  /// Maakt het account aan, logt meteen in en vraagt de bevestigingsmail
  /// aan (best-effort). Stuurt altijd rol en taal = nl mee (backend
  /// OPEN-PUNTEN 8 en 9). [rol] mag geen coordinator zijn.
  Future<Result<HhGebruiker>> registreren({
    required String naam,
    required String email,
    required String wachtwoord,
    required HhRol rol,
    String? telefoon,
  });

  Future<Result<HhGebruiker>> inloggen({
    required String email,
    required String wachtwoord,
  });

  Future<Result<void>> uitloggen();

  /// Zet een bewaard token in de authStore en ververst het meteen. Een
  /// poging; een Err betekent dat de aanroeper beslist (token bewaren bij
  /// geen verbinding, wissen bij 401).
  Future<Result<HhGebruiker>> sessieHerstellen(String token);

  Future<Result<void>> verificatieAanvragen(String email);

  Future<Result<void>> wachtwoordResetAanvragen(String email);

  /// Stuurt ALLEEN [velden] naar de server, nooit het hele record
  /// (backend OPEN-PUNT 10: rol mag niet in het verzoek zitten).
  Future<Result<HhGebruiker>> bijwerken(String id, Map<String, dynamic> velden);

  /// Verwijdert het eigen hh_users-record (backend OPEN-PUNT 21).
  Future<Result<void>> accountWissen(String id);

  /// Het token uit de authStore, om na inloggen of verversen in de eigen
  /// opslag te bewaren. Leeg als niemand is ingelogd.
  Future<Result<String>> huidigToken();
}

class PocketBaseAuthGateway implements AuthGateway {
  const PocketBaseAuthGateway(this._gateway);

  final PocketBaseGateway _gateway;

  RecordService _users(PocketBase client) =>
      client.collection(hhUsersCollectie);

  @override
  Future<Result<HhGebruiker>> registreren({
    required String naam,
    required String email,
    required String wachtwoord,
    required HhRol rol,
    String? telefoon,
  }) {
    assert(rol.kanZelfRegistreren, 'coordinator registreert niet zelf');
    return _gateway.voerUit((client) async {
      await _users(client).create(
        body: {
          'naam': naam,
          'email': email,
          'password': wachtwoord,
          'passwordConfirm': wachtwoord,
          'rol': rol.code,
          'taal': HhTaal.nl.code,
          'emailVisibility': false,
          if (telefoon != null && telefoon.isNotEmpty) 'telefoon': telefoon,
        },
      );
      final auth = await _users(client).authWithPassword(email, wachtwoord);
      // Best-effort: het account bestaat al, ook als deze mail niet wegkomt.
      try {
        await _users(client).requestVerification(email);
      } on ClientException {
        // Genegeerd; G5 heeft een knop om de mail opnieuw te sturen.
      }
      return HhGebruiker.vanRecord(auth.record);
    });
  }

  @override
  Future<Result<HhGebruiker>> inloggen({
    required String email,
    required String wachtwoord,
  }) async {
    final result = await _gateway.voerUit((client) async {
      final auth = await _users(client).authWithPassword(email, wachtwoord);
      return HhGebruiker.vanRecord(auth.record);
    });
    // "Failed to authenticate." komt als 400 zonder velddata; verkeerd
    // wachtwoord en onbekend adres zijn niet te onderscheiden en dat is
    // ook de bedoeling. 403 is de server die op bevestiging wacht.
    return switch (result) {
      Err<HhGebruiker>(:final fout)
          when fout.soort == HhFoutSoort.ongeldigeInvoer =>
        Result.err(HhFout(HhFoutSoort.ongeldigeInlog, detail: fout.detail)),
      Err<HhGebruiker>(:final fout)
          when fout.soort == HhFoutSoort.geenToegang =>
        Result.err(HhFout(HhFoutSoort.emailNietBevestigd, detail: fout.detail)),
      _ => result,
    };
  }

  @override
  Future<Result<void>> uitloggen() {
    return _gateway.voerUit((client) async => client.authStore.clear());
  }

  @override
  Future<Result<HhGebruiker>> sessieHerstellen(String token) {
    return _gateway.voerUit((client) async {
      client.authStore.save(token, null);
      final auth = await _users(client).authRefresh();
      return HhGebruiker.vanRecord(auth.record);
    });
  }

  @override
  Future<Result<void>> verificatieAanvragen(String email) {
    return _gateway.voerUit(
      (client) => _users(client).requestVerification(email),
    );
  }

  @override
  Future<Result<void>> wachtwoordResetAanvragen(String email) {
    return _gateway.voerUit(
      (client) => _users(client).requestPasswordReset(email),
    );
  }

  @override
  Future<Result<HhGebruiker>> bijwerken(
    String id,
    Map<String, dynamic> velden,
  ) {
    assert(!velden.containsKey('rol'), 'rol mag nooit mee in een update');
    return _gateway.voerUit((client) async {
      final record = await _users(client).update(id, body: velden);
      return HhGebruiker.vanRecord(record);
    });
  }

  @override
  Future<Result<void>> accountWissen(String id) {
    return _gateway.voerUit((client) async {
      await _users(client).delete(id);
      client.authStore.clear();
    });
  }

  @override
  Future<Result<String>> huidigToken() {
    return _gateway.voerUit((client) async => client.authStore.token);
  }
}
