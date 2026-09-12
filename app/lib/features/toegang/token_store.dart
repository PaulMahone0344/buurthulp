import '../../core/key_value_store.dart';

const _tokenSleutel = 'hh_auth_token';

/// Bewaart het PocketBase-token in de [KeyValueStore] (secure storage in
/// productie). Nooit in een provider die bij een herstart weg is.
class TokenStore {
  const TokenStore(this._opslag);

  final KeyValueStore _opslag;

  Future<String?> lees() => _opslag.lees(_tokenSleutel);

  Future<void> bewaar(String token) => _opslag.schrijf(_tokenSleutel, token);

  Future<void> wis() => _opslag.wis(_tokenSleutel);
}
