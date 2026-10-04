import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hh_fout.dart';
import '../../../core/pb/gateway_providers.dart';
import '../../../core/result.dart';
import '../domein/aanmelding.dart';
import '../model/hh_gebruiker.dart';
import '../model/hh_rol.dart';
import '../model/sessie_state.dart';
import '../token_store.dart';

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(ref.watch(keyValueStoreProvider)),
);

/// Bewaakt de sessie: bewaard token -> verversen bij het opstarten, en
/// houdt token, opslag en state gelijk bij registreren, inloggen,
/// uitloggen, bijwerken en wissen.
class SessieController extends Notifier<SessieState> {
  @override
  SessieState build() {
    // Niet herstel(): die zet state, en dat mag niet tijdens build.
    unawaited(_herstel());
    return const SessieOnbekend();
  }

  /// Opnieuw proberen vanaf de splash (na geen verbinding).
  Future<void> herstel() async {
    state = const SessieOnbekend();
    await _herstel();
  }

  /// Een poging om de bewaarde sessie te herstellen. Geen verbinding laat
  /// het token staan (de splash biedt opnieuw proberen aan); elke andere
  /// fout wist het token en stuurt naar inloggen met een melding.
  Future<void> _herstel() async {
    final token = await ref.read(tokenStoreProvider).lees();
    if (token == null || token.isEmpty) {
      state = const SessieUitgelogd();
      return;
    }
    final result = await ref.read(authGatewayProvider).sessieHerstellen(token);
    switch (result) {
      case Ok<HhGebruiker>(:final waarde):
        await _bewaarToken();
        state = SessieIngelogd(waarde);
      case Err<HhGebruiker>(:final fout) when fout.isGeenVerbinding:
        state = SessieOnbekend(fout: fout);
      case Err<HhGebruiker>():
        await ref.read(tokenStoreProvider).wis();
        state = const SessieUitgelogd(reden: UitlogReden.sessieVerlopen);
    }
  }

  /// ADRES: haalt de eigen gebruiker opnieuw op (na een adreswijziging via
  /// Mijn gegevens: wijk, werkgebied en de gele balk volgen dan). Stil: bij
  /// een fout blijft de sessie zoals hij was, alleen een 401 logt uit.
  /// Roep dit pas aan als het scherm met de wijziging weg is (zie
  /// [vervangGebruiker]).
  Future<void> ververs() async {
    if (_ingelogdeGebruiker == null) return;
    final token = await ref.read(tokenStoreProvider).lees();
    if (token == null || token.isEmpty) return;
    final result = await ref.read(authGatewayProvider).sessieHerstellen(token);
    switch (result) {
      case Ok<HhGebruiker>(:final waarde):
        vervangGebruiker(waarde);
      case Err<HhGebruiker>(:final fout)
          when fout.soort == HhFoutSoort.nietIngelogd:
        await sessieVerlopen();
      case Err<HhGebruiker>():
        break;
    }
  }

  /// ADRES: stuurt [velden] naar de server zoals [bijwerken], maar laat de
  /// sessie nog staan; het scherm geeft de nieuwe gebruiker later door aan
  /// [vervangGebruiker]. Waarom: verandert de sessie terwijl Start eronder
  /// gepauzeerd staat, dan wil Riverpod 3 bij terugkomen midden in een build
  /// opnieuw bouwen ("markNeedsBuild called during build"). Een 401 logt uit.
  Future<Result<HhGebruiker>> bijwerkenUitgesteld(
    Map<String, dynamic> velden,
  ) async {
    final gebruiker = _ingelogdeGebruiker;
    if (gebruiker == null) {
      return Result.err(const HhFout(HhFoutSoort.nietIngelogd));
    }
    final result = await ref
        .read(authGatewayProvider)
        .bijwerken(gebruiker.id, velden);
    if (result case Err<HhGebruiker>(
      :final fout,
    ) when fout.soort == HhFoutSoort.nietIngelogd) {
      await sessieVerlopen();
    }
    return result;
  }

  /// Zet een (door de server teruggegeven) nieuwere versie van de ingelogde
  /// gebruiker in de sessie. Doet niets als er intussen iemand anders (of
  /// niemand) ingelogd is.
  void vervangGebruiker(HhGebruiker gebruiker) {
    if (_ingelogdeGebruiker?.id != gebruiker.id) return;
    state = SessieIngelogd(gebruiker);
  }

  Future<Result<void>> registreren(HhAanmelding aanmelding) {
    return _authenticeer(
      () => ref.read(authGatewayProvider).registreren(aanmelding),
    );
  }

  Future<Result<void>> inloggen({
    required String email,
    required String wachtwoord,
  }) {
    return _authenticeer(
      () => ref
          .read(authGatewayProvider)
          .inloggen(email: email, wachtwoord: wachtwoord),
    );
  }

  Future<Result<void>> _authenticeer(
    Future<Result<HhGebruiker>> Function() actie,
  ) async {
    state = const SessieBezig();
    final result = await actie();
    switch (result) {
      case Ok<HhGebruiker>(:final waarde):
        await _bewaarToken();
        state = SessieIngelogd(waarde);
        return Result.ok(null);
      case Err<HhGebruiker>(:final fout):
        state = const SessieUitgelogd();
        return Result.err(fout);
    }
  }

  Future<void> _bewaarToken() async {
    final result = await ref.read(authGatewayProvider).huidigToken();
    if (result case Ok<String>(:final waarde) when waarde.isNotEmpty) {
      await ref.read(tokenStoreProvider).bewaar(waarde);
    }
  }

  Future<void> uitloggen() async {
    await ref.read(authGatewayProvider).uitloggen();
    await ref.read(tokenStoreProvider).wis();
    state = const SessieUitgelogd();
  }

  /// Voor elke latere feature die een 401 terugkrijgt: token weg, terug
  /// naar inloggen met de melding "sessie verlopen".
  Future<void> sessieVerlopen() async {
    await ref.read(authGatewayProvider).uitloggen();
    await ref.read(tokenStoreProvider).wis();
    state = const SessieUitgelogd(reden: UitlogReden.sessieVerlopen);
  }

  /// Stuurt alleen [velden] naar de server en vervangt de gebruiker in
  /// de state met het antwoord. Een 401 logt uit.
  Future<Result<void>> bijwerken(Map<String, dynamic> velden) async {
    final gebruiker = _ingelogdeGebruiker;
    if (gebruiker == null) {
      return Result.err(const HhFout(HhFoutSoort.nietIngelogd));
    }
    final result = await ref
        .read(authGatewayProvider)
        .bijwerken(gebruiker.id, velden);
    switch (result) {
      case Ok<HhGebruiker>(:final waarde):
        state = SessieIngelogd(waarde);
        return Result.ok(null);
      case Err<HhGebruiker>(:final fout):
        return _verwerkFout(fout);
    }
  }

  Future<Result<void>> accountWissen() async {
    final gebruiker = _ingelogdeGebruiker;
    if (gebruiker == null) {
      return Result.err(const HhFout(HhFoutSoort.nietIngelogd));
    }
    final result = await ref
        .read(authGatewayProvider)
        .accountWissen(gebruiker.id);
    switch (result) {
      case Ok<void>():
        await ref.read(tokenStoreProvider).wis();
        state = const SessieUitgelogd(reden: UitlogReden.accountGewist);
        return Result.ok(null);
      case Err<void>(:final fout):
        return _verwerkFout(fout);
    }
  }

  Future<Result<void>> verificatieAanvragen(String email) =>
      ref.read(authGatewayProvider).verificatieAanvragen(email);

  Future<Result<void>> wachtwoordResetAanvragen(String email) =>
      ref.read(authGatewayProvider).wachtwoordResetAanvragen(email);

  Future<Result<void>> _verwerkFout(HhFout fout) async {
    if (fout.soort == HhFoutSoort.nietIngelogd) await sessieVerlopen();
    return Result.err(fout);
  }

  HhGebruiker? get _ingelogdeGebruiker => switch (state) {
    SessieIngelogd(:final gebruiker) => gebruiker,
    _ => null,
  };
}

final sessieControllerProvider =
    NotifierProvider<SessieController, SessieState>(SessieController.new);

/// De ingelogde gebruiker, of null.
final huidigeGebruikerProvider = Provider<HhGebruiker?>((ref) {
  return switch (ref.watch(sessieControllerProvider)) {
    SessieIngelogd(:final gebruiker) => gebruiker,
    _ => null,
  };
});

/// De rol die op G2 is gekozen, voordat er een account is. Bepaalt de
/// dichtheid tijdens registreren en welke rol G4 meestuurt.
class GekozenRolController extends Notifier<HhRol?> {
  @override
  HhRol? build() => null;

  void kies(HhRol? rol) => state = rol;
}

final gekozenRolProvider = NotifierProvider<GekozenRolController, HhRol?>(
  GekozenRolController.new,
);
