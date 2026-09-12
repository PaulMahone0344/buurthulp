import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../key_value_store.dart';
import 'auth_gateway.dart';
import 'pocketbase_gateway.dart';

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
