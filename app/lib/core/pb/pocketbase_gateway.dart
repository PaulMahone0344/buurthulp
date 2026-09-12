import 'dart:convert';

import 'package:pocketbase/pocketbase.dart';

import '../config.dart';
import '../hh_fout.dart';
import '../result.dart';

/// De enige plek die het pocketbase-pakket aanraakt. Elke latere
/// repository (klussen, profielen, ...) praat tegen deze interface, zodat
/// een wissel van backend maar een bestand raakt en tests nooit een
/// verzoek naar de server sturen.
abstract interface class PocketBaseGateway {
  Future<Result<T>> voerUit<T>(Future<T> Function(PocketBase client) actie);
}

class PocketBaseClientGateway implements PocketBaseGateway {
  PocketBaseClientGateway({PocketBase? client})
    : _client = client ?? PocketBase(HhConfig.baseUrl);

  final PocketBase _client;

  @override
  Future<Result<T>> voerUit<T>(
    Future<T> Function(PocketBase client) actie,
  ) async {
    try {
      return Result.ok(await actie(_client));
    } on ClientException catch (e) {
      return Result.err(vertaalClientException(e));
    } on FormatException catch (e) {
      return Result.err(HhFout(HhFoutSoort.onbekend, detail: e.message));
    } catch (e) {
      return Result.err(HhFout(HhFoutSoort.onbekend, detail: e.toString()));
    }
  }

  /// Een [ClientException] zonder statuscode (0) komt van een
  /// SocketException of time-out: geen verbinding.
  static HhFout vertaalClientException(ClientException e) {
    return HhFout.vanStatus(e.statusCode, antwoord: _alsMap(e.response));
  }

  static Map<String, dynamic> _alsMap(Object? antwoord) {
    if (antwoord is Map<String, dynamic>) return antwoord;
    if (antwoord is Map) return antwoord.map((k, v) => MapEntry('$k', v));
    if (antwoord is String && antwoord.isNotEmpty) {
      try {
        final ontleed = jsonDecode(antwoord);
        if (ontleed is Map<String, dynamic>) return ontleed;
      } on FormatException {
        // Geen JSON: dan is er ook geen veldinformatie.
      }
    }
    return const {};
  }
}
