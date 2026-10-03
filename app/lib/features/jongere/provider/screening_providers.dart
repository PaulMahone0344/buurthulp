import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hh_fout.dart';
import '../../../core/pb/gateway_providers.dart';
import '../../../core/pb/ouder_gateway.dart';
import '../../../core/result.dart';
import '../../toegang/model/hh_gebruiker.dart';
import '../../toegang/model/hh_rol.dart';
import '../../toegang/provider/sessie_providers.dart';
import '../../hulpvrager/provider/hulpvrager_providers.dart' show klokProvider;
import '../domein/helper_wacht.dart';
import '../model/hh_profiel.dart';
import '../model/hh_screening_status.dart';
import '../model/screening_stap.dart';
import '../ouder/model/hh_ouder_stand.dart';
import '../../toegang/domein/aanmelding.dart' show isMinderjarig;

/// Houdt profiel en accountvelden van de ingelogde helper (rol jongere) bij. Laadt zodra
/// een jongere is ingelogd; voor elke andere rol (of niemand) is de staat
/// leeg zonder serververzoek. Een mislukte lading is een AsyncError met de
/// [HhFout] als error; de schermen tonen dan fout.melding.
class ScreeningController extends AsyncNotifier<ScreeningGegevens> {
  @override
  Future<ScreeningGegevens> build() async {
    final gebruiker = ref.watch(huidigeGebruikerProvider);
    if (gebruiker == null || gebruiker.rol != HhRol.jongere) {
      return const ScreeningGegevens();
    }
    return _laad(gebruiker.id);
  }

  Future<ScreeningGegevens> _laad(String gebruikerId) async {
    final gateway = ref.read(profielGatewayProvider);
    final (profiel, account) = await (
      gateway.haalProfiel(gebruikerId),
      gateway.haalAccountGegevens(gebruikerId),
    ).wait;
    final gegevens = switch ((profiel, account)) {
      (
        Ok<HhProfiel?>(waarde: final p),
        Ok<HhAccountGegevens>(waarde: final a),
      ) =>
        ScreeningGegevens(profiel: p, account: a),
      (Err<HhProfiel?>(:final fout), _) => throw fout,
      (_, Err<HhAccountGegevens>(:final fout)) => throw fout,
    };
    return ScreeningGegevens(
      profiel: gegevens.profiel,
      account: gegevens.account,
      ouder: await _laadOuder(gegevens.account),
    );
  }

  /// B3: alleen onder 18 (zonder toestemming hoeft het niet, maar de stand
  /// "ingetrokken" of "gegeven" is ook dan nuttig). Lukt het niet (route
  /// nog niet op de server, geen verbinding), dan null: de app valt terug
  /// op ouder_toestemming_op, zoals in B2.
  Future<HhOuderStand?> _laadOuder(HhAccountGegevens account) async {
    final geboren = account.geboortedatum;
    if (geboren == null || !isMinderjarig(geboren, ref.read(klokProvider)())) {
      return null;
    }
    final result = await ref.read(ouderGatewayProvider).haalStand();
    return switch (result) {
      Ok<HhOuderStand>(:final waarde) => waarde,
      Err<HhOuderStand>() => null,
    };
  }

  /// B3: (opnieuw) een mail met code naar de ouder. Met [ouderEmail] wordt
  /// dat het nieuwe adres. De stand wordt meteen bijgewerkt.
  Future<OuderVerstuurUitkomst> stuurOuderMail({String? ouderEmail}) async {
    final uitkomst = await ref
        .read(ouderGatewayProvider)
        .verstuur(ouderEmail: ouderEmail);
    switch (uitkomst) {
      case OuderVerstuurd(:final stand):
        final huidig = state.value;
        if (huidig != null) state = AsyncData(huidig.copyWith(ouder: stand));
      case OuderVerstuurFout(:final fout)
          when fout.soort == HhFoutSoort.nietIngelogd:
        await ref.read(sessieControllerProvider.notifier).sessieVerlopen();
      case OuderVerstuurFout() || OuderGeweigerd():
        break;
    }
    return uitkomst;
  }

  /// Opnieuw laden, bijvoorbeeld na een fout of na een statuswijziging
  /// door de meldkamer.
  Future<void> vernieuw() async {
    final gebruiker = _jongere;
    if (gebruiker == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _laad(gebruiker.id));
  }

  /// Stuurt ALLEEN [velden]. Bestaat het profiel nog niet, dan wordt het
  /// aangemaakt met deze velden.
  Future<Result<void>> werkProfielBij(Map<String, dynamic> velden) async {
    final gebruiker = _jongere;
    final huidig = state.value;
    if (gebruiker == null || huidig == null) return _nietIngelogd;
    final gateway = ref.read(profielGatewayProvider);
    final profiel = huidig.profiel;
    final result = profiel == null
        ? await gateway.maakProfielAan(gebruiker.id, velden)
        : await gateway.werkProfielBij(profiel.id, velden);
    return _verwerk(result, (p) => huidig.copyWith(profiel: p));
  }

  /// De ID-foto (document_foto). Zonder profiel wordt het eerst leeg
  /// aangemaakt.
  Future<Result<void>> uploadIdFoto({
    required Uint8List bytes,
    required String bestandsnaam,
  }) async {
    final gebruiker = _jongere;
    var huidig = state.value;
    if (gebruiker == null || huidig == null) return _nietIngelogd;
    if (huidig.profiel == null) {
      final aangemaakt = await werkProfielBij(const {});
      if (aangemaakt case Err<void>(:final fout)) return Result.err(fout);
      huidig = state.value;
      if (huidig?.profiel == null) return _nietIngelogd;
    }
    final result = await ref
        .read(profielGatewayProvider)
        .uploadIdFoto(
          profielId: huidig!.profiel!.id,
          bytes: bytes,
          bestandsnaam: bestandsnaam,
        );
    final basis = huidig;
    return _verwerk(result, (p) => basis.copyWith(profiel: p));
  }

  /// J9: nieuw -> in_behandeling. Alleen dat ene veld gaat mee.
  Future<Result<void>> terControleAanbieden() => werkProfielBij({
    'verificatiestatus': HhScreeningStatus.inBehandeling.code,
  });

  Future<Result<void>> _verwerk<T>(
    Result<T> result,
    ScreeningGegevens Function(T waarde) bijwerken,
  ) async {
    switch (result) {
      case Ok<T>(:final waarde):
        state = AsyncData(bijwerken(waarde));
        return Result.ok(null);
      case Err<T>(:final fout):
        if (fout.soort == HhFoutSoort.nietIngelogd) {
          await ref.read(sessieControllerProvider.notifier).sessieVerlopen();
        }
        return Result.err(fout);
    }
  }

  Result<void> get _nietIngelogd =>
      Result.err(const HhFout(HhFoutSoort.nietIngelogd));

  /// De ingelogde jongere, of null (niemand of een andere rol).
  HhGebruiker? get _jongere {
    final gebruiker = ref.read(huidigeGebruikerProvider);
    if (gebruiker == null || gebruiker.rol != HhRol.jongere) return null;
    return gebruiker;
  }
}

final screeningControllerProvider =
    AsyncNotifierProvider<ScreeningController, ScreeningGegevens>(
      ScreeningController.new,
    );

/// Referentiedata: wijken (naam bij een klus) en klustypes (filterbalk). Een Err wordt een AsyncError met de
/// [HhFout] als error.
final wijkenProvider = FutureProvider<List<HhWijk>>((ref) async {
  final result = await ref.watch(profielGatewayProvider).haalWijken();
  return switch (result) {
    Ok<List<HhWijk>>(:final waarde) => waarde,
    Err<List<HhWijk>>(:final fout) => throw fout,
  };
});

final klustypesProvider = FutureProvider<List<HhKlustype>>((ref) async {
  final result = await ref.watch(profielGatewayProvider).haalKlustypes();
  return switch (result) {
    Ok<List<HhKlustype>>(:final waarde) => waarde,
    Err<List<HhKlustype>>(:final fout) => throw fout,
  };
});

/// Waar de ingelogde helper op wacht (B2), of null zolang zijn gegevens
/// laden of niet konden laden.
final helperWachtProvider = Provider<HelperWacht?>((ref) {
  final nu = ref.watch(klokProvider)();
  return switch (ref.watch(screeningControllerProvider)) {
    AsyncData<ScreeningGegevens>(:final value) => helperWacht(value, nu),
    _ => null,
  };
});

/// De melding voor een AsyncError uit deze providers.
String meldingVanFout(Object? error) => error is HhFout
    ? error.melding
    : const HhFout(HhFoutSoort.onbekend).melding;
