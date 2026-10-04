import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../key_value_store.dart';
import 'adres_gateway.dart';
import 'auth_gateway.dart';
import 'ouder_gateway.dart';
import 'pocketbase_gateway.dart';
import 'profiel_gateway.dart';

/// De echte PocketBase-verbinding. Tests overriden [authGatewayProvider]
/// met een [FakeAuthGateway] en [keyValueStoreProvider] met een
/// [GeheugenKeyValueStore]; er gaat dan nooit iets naar de server.
final pocketBaseGatewayProvider = Provider<PocketBaseGateway>(
  (ref) => PocketBaseClientGateway(),
);

final authGatewayProvider = Provider<AuthGateway>(
  (ref) => PocketBaseAuthGateway(ref.watch(pocketBaseGatewayProvider)),
);

final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => SecureKeyValueStore(),
);

/// M3: screening van de jongere. Tests overriden met [FakeProfielGateway].
final profielGatewayProvider = Provider<ProfielGateway>(
  (ref) => PocketBaseProfielGateway(ref.watch(pocketBaseGatewayProvider)),
);

/// B3: ouder-toestemming (helper onder 18). Tests overriden met
/// [FakeOuderGateway].
final ouderGatewayProvider = Provider<OuderGateway>(
  (ref) => PocketBaseOuderGateway(ref.watch(pocketBaseGatewayProvider)),
);

/// ADRES: adres-suggestie via PDOK (GET /api/hh/adres). Tests overriden met
/// [FakeAdresGateway]; er gaat dan nooit een verzoek naar PDOK.
final adresGatewayProvider = Provider<AdresGateway>(
  (ref) => PocketBaseAdresGateway(ref.watch(pocketBaseGatewayProvider)),
);
