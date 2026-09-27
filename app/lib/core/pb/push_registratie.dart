import '../result.dart';
import 'pocketbase_gateway.dart';

const hhPushTokensCollectie = 'hh_push_tokens';

/// LAAG 2 VAN M8 (echte push naar het toestel) is NIET gebouwd: daarvoor
/// zijn een Firebase-project, een Apple-sleutel en een verzender nodig die
/// RS256 kan tekenen (de PocketBase-JSVM kan dat niet). Zie OPEN-PUNTEN-M8.
///
/// Wel klaar: deze interface. Laag 2 levert een implementatie die bij het
/// toestel een token vraagt (Firebase Messaging) en hem via
/// [PushTokenOpslag] in hh_push_tokens zet. Tot die tijd draait de app met
/// [LegePushRegistratie]: er komt niets aan op het toestel, meldingen staan
/// alleen IN de app.
abstract interface class PushRegistratie {
  /// Vraag een token aan het toestel en bewaar het voor [gebruikerId].
  Future<void> registreerToken(String gebruikerId);

  /// Bij uitloggen: het token van dit toestel weer weghalen.
  Future<void> verwijderToken();
}

/// Doet niets. Laag 1 heeft geen toestel-token nodig.
class LegePushRegistratie implements PushRegistratie {
  const LegePushRegistratie();

  @override
  Future<void> registreerToken(String gebruikerId) async {}

  @override
  Future<void> verwijderToken() async {}
}

enum PushPlatform {
  ios('ios'),
  android('android');

  const PushPlatform(this.code);

  final String code;
}

/// De opslag van tokens in hh_push_tokens (rules: alleen eigen rijen). Laag
/// 2 gebruikt dit; laag 1 roept het nergens aan.
abstract interface class PushTokenOpslag {
  /// Bewaart [token] voor [gebruikerId]. Staat hij er al (uniek op token),
  /// dan wordt hij bijgewerkt in plaats van dubbel aangemaakt.
  Future<Result<void>> bewaar({
    required String gebruikerId,
    required String token,
    required PushPlatform platform,
  });

  Future<Result<void>> verwijder(String token);
}

class PocketBasePushTokenOpslag implements PushTokenOpslag {
  const PocketBasePushTokenOpslag(this._gateway);

  final PocketBaseGateway _gateway;

  @override
  Future<Result<void>> bewaar({
    required String gebruikerId,
    required String token,
    required PushPlatform platform,
  }) {
    return _gateway.voerUit<void>((client) async {
      final bestaand = await client
          .collection(hhPushTokensCollectie)
          .getList(
            perPage: 1,
            skipTotal: true,
            filter: client.filter('token = {:token}', {'token': token}),
          );
      final body = {
        'gebruiker': gebruikerId,
        'token': token,
        'platform': platform.code,
      };
      if (bestaand.items.isEmpty) {
        await client.collection(hhPushTokensCollectie).create(body: body);
      } else {
        await client
            .collection(hhPushTokensCollectie)
            .update(bestaand.items.first.id, body: body);
      }
    });
  }

  @override
  Future<Result<void>> verwijder(String token) {
    return _gateway.voerUit<void>((client) async {
      final bestaand = await client
          .collection(hhPushTokensCollectie)
          .getList(
            perPage: 1,
            skipTotal: true,
            filter: client.filter('token = {:token}', {'token': token}),
          );
      for (final r in bestaand.items) {
        await client.collection(hhPushTokensCollectie).delete(r.id);
      }
    });
  }
}
