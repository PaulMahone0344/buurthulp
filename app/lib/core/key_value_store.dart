import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Dunne opslaglaag voor het sessietoken en kleine voorkeuren.
/// Losgekoppeld van het pakket zodat tests een fake kunnen gebruiken.
abstract interface class KeyValueStore {
  Future<String?> lees(String sleutel);
  Future<void> schrijf(String sleutel, String waarde);
  Future<void> wis(String sleutel);
}

/// Productie: flutter_secure_storage (Keychain op iOS, Keystore op
/// Android). Nooit SharedPreferences voor een token.
class SecureKeyValueStore implements KeyValueStore {
  SecureKeyValueStore([FlutterSecureStorage? opslag])
    : _opslag = opslag ?? const FlutterSecureStorage();

  final FlutterSecureStorage _opslag;

  @override
  Future<String?> lees(String sleutel) => _opslag.read(key: sleutel);

  @override
  Future<void> schrijf(String sleutel, String waarde) =>
      _opslag.write(key: sleutel, value: waarde);

  @override
  Future<void> wis(String sleutel) => _opslag.delete(key: sleutel);
}

/// In-memory opslag voor tests en het dev-scherm.
class GeheugenKeyValueStore implements KeyValueStore {
  GeheugenKeyValueStore([Map<String, String>? begin]) : _waarden = {...?begin};

  final Map<String, String> _waarden;

  Map<String, String> get waarden => Map.unmodifiable(_waarden);

  @override
  Future<String?> lees(String sleutel) async => _waarden[sleutel];

  @override
  Future<void> schrijf(String sleutel, String waarde) async {
    _waarden[sleutel] = waarde;
  }

  @override
  Future<void> wis(String sleutel) async {
    _waarden.remove(sleutel);
  }
}
