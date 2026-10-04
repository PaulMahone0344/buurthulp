import 'package:pocketbase/pocketbase.dart';

import '../../features/adres/model/hh_adres.dart';
import '../result.dart';
import 'pocketbase_gateway.dart';

/// De route uit backend/pb_hooks/hh_adres.pb.js: adres-suggestie via PDOK.
const hhAdresPad = '/api/hh/adres';

/// Postcode + huisnummer (+ toevoeging) -> straat en plaats. Publiek: werkt
/// ook bij aanmelden, vóór er een account is.
abstract interface class AdresGateway {
  Future<AdresZoekUitkomst> zoek({
    required String postcode,
    required String huisnummer,
    String toevoeging = '',
  });
}

class PocketBaseAdresGateway implements AdresGateway {
  const PocketBaseAdresGateway(this._gateway);

  final PocketBaseGateway _gateway;

  @override
  Future<AdresZoekUitkomst> zoek({
    required String postcode,
    required String huisnummer,
    String toevoeging = '',
  }) async {
    final result = await _gateway.voerUit<AdresZoekUitkomst>((client) async {
      try {
        final antwoord = await client.send(
          hhAdresPad,
          query: {
            'postcode': postcode,
            'huisnummer': huisnummer,
            'toevoeging': toevoeging,
          },
        );
        return _lees(_alsMap(antwoord));
      } on ClientException catch (e) {
        final data = _alsMap(e.response);
        final melding = '${data['melding'] ?? ''}';
        if (e.statusCode == 429) return AdresLimiet(melding);
        if (e.statusCode == 400 && melding.isNotEmpty) {
          return AdresOngeldig('${data['reden'] ?? ''}', melding);
        }
        // Geen verbinding, 404 (route nog niet op de server) of 5xx: dan
        // mag aanmelden toch, ongecontroleerd.
        return const AdresDienstWeg();
      }
    });
    return switch (result) {
      Ok<AdresZoekUitkomst>(:final waarde) => waarde,
      Err<AdresZoekUitkomst>() => const AdresDienstWeg(),
    };
  }

  static AdresZoekUitkomst _lees(Map<String, dynamic> data) {
    final lijst = [
      for (final a in (data['adressen'] as List?) ?? const [])
        if (a is Map) HhAdres.vanJson(a.map((k, v) => MapEntry('$k', v))),
    ];
    if (data['gevonden'] == true && lijst.isNotEmpty) {
      return AdresGevonden(lijst);
    }
    final reden = '${data['reden'] ?? ''}';
    if (reden == 'dienst') return const AdresDienstWeg();
    return AdresNietGevonden('${data['melding'] ?? ''}', keuzes: lijst);
  }

  static Map<String, dynamic> _alsMap(Object? waarde) {
    if (waarde is Map<String, dynamic>) return waarde;
    if (waarde is Map) return waarde.map((k, v) => MapEntry('$k', v));
    return const {};
  }
}
