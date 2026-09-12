import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../../features/jongere/model/hh_profiel.dart';
import '../result.dart';
import 'auth_gateway.dart' show hhUsersCollectie;
import 'pocketbase_gateway.dart';

const hhProfielenCollectie = 'hh_profielen';
const hhWijkenCollectie = 'hh_wijken';
const hhKlustypesCollectie = 'hh_klustypes';

/// Velden op hh_profielen die de eigenaar nooit mag meesturen (server-rule,
/// backend 06-screening-rules.mjs). verificatiestatus staat er niet in: die
/// mag een keer mee, van nieuw naar in_behandeling.
const hhProfielGeblokkeerdeVelden = {
  'gebruiker',
  'vog_status',
  'iban_geverifieerd',
  'sterren_gemiddeld',
  'klussen_aantal',
};

/// Alles rond de screening van de jongere (M3): het eigen hh_profielen-
/// record, de accountvelden foto/geboortedatum/wijk op hh_users, de twee
/// foto-uploads en de referentiedata (wijken, klustypes). Stuurt altijd
/// ALLEEN de gewijzigde velden (backend OPEN-PUNT 10).
abstract interface class ProfielGateway {
  /// Het eigen profiel, of null als het nog niet bestaat.
  Future<Result<HhProfiel?>> haalProfiel(String gebruikerId);

  Future<Result<HhProfiel>> maakProfielAan(
    String gebruikerId,
    Map<String, dynamic> velden,
  );

  Future<Result<HhProfiel>> werkProfielBij(
    String profielId,
    Map<String, dynamic> velden,
  );

  /// [veld] is document_foto of selfie.
  Future<Result<HhProfiel>> uploadProfielFoto({
    required String profielId,
    required String veld,
    required Uint8List bytes,
    required String bestandsnaam,
  });

  Future<Result<HhAccountGegevens>> haalAccountGegevens(String gebruikerId);

  /// Alleen geboortedatum en wijk; nooit rol.
  Future<Result<HhAccountGegevens>> werkAccountBij(
    String gebruikerId,
    Map<String, dynamic> velden,
  );

  Future<Result<HhAccountGegevens>> uploadAccountFoto({
    required String gebruikerId,
    required Uint8List bytes,
    required String bestandsnaam,
  });

  /// Alleen actieve wijken, gesorteerd op gemeente en wijk.
  Future<Result<List<HhWijk>>> haalWijken();

  Future<Result<List<HhKlustype>>> haalKlustypes();
}

class PocketBaseProfielGateway implements ProfielGateway {
  const PocketBaseProfielGateway(this._gateway);

  final PocketBaseGateway _gateway;

  RecordService _profielen(PocketBase client) =>
      client.collection(hhProfielenCollectie);

  RecordService _users(PocketBase client) =>
      client.collection(hhUsersCollectie);

  static bool _zonderGeblokkeerde(Map<String, dynamic> velden) =>
      velden.keys.every((k) => !hhProfielGeblokkeerdeVelden.contains(k));

  @override
  Future<Result<HhProfiel?>> haalProfiel(String gebruikerId) {
    return _gateway.voerUit((client) async {
      try {
        final record = await _profielen(client).getFirstListItem(
          client.filter('gebruiker = {:id}', {'id': gebruikerId}),
        );
        return HhProfiel.vanRecord(record);
      } on ClientException catch (e) {
        // Geen profiel is geen fout: de jongere maakt het in J1 aan.
        if (e.statusCode == 404) return null;
        rethrow;
      }
    });
  }

  @override
  Future<Result<HhProfiel>> maakProfielAan(
    String gebruikerId,
    Map<String, dynamic> velden,
  ) {
    assert(_zonderGeblokkeerde(velden), 'geblokkeerd veld in create');
    assert(
      !velden.containsKey('verificatiestatus'),
      'verificatiestatus mag niet mee bij aanmaken',
    );
    return _gateway.voerUit((client) async {
      final record = await _profielen(
        client,
      ).create(body: {'gebruiker': gebruikerId, ...velden});
      return HhProfiel.vanRecord(record);
    });
  }

  @override
  Future<Result<HhProfiel>> werkProfielBij(
    String profielId,
    Map<String, dynamic> velden,
  ) {
    assert(_zonderGeblokkeerde(velden), 'geblokkeerd veld in update');
    return _gateway.voerUit((client) async {
      final record = await _profielen(client).update(profielId, body: velden);
      return HhProfiel.vanRecord(record);
    });
  }

  @override
  Future<Result<HhProfiel>> uploadProfielFoto({
    required String profielId,
    required String veld,
    required Uint8List bytes,
    required String bestandsnaam,
  }) {
    assert(veld == 'document_foto' || veld == 'selfie', 'onbekend fotoveld');
    return _gateway.voerUit((client) async {
      final record = await _profielen(client).update(
        profielId,
        files: [
          http.MultipartFile.fromBytes(veld, bytes, filename: bestandsnaam),
        ],
      );
      return HhProfiel.vanRecord(record);
    });
  }

  @override
  Future<Result<HhAccountGegevens>> haalAccountGegevens(String gebruikerId) {
    return _gateway.voerUit((client) async {
      final record = await _users(client).getOne(gebruikerId);
      return HhAccountGegevens.vanRecord(record);
    });
  }

  @override
  Future<Result<HhAccountGegevens>> werkAccountBij(
    String gebruikerId,
    Map<String, dynamic> velden,
  ) {
    assert(!velden.containsKey('rol'), 'rol mag nooit mee in een update');
    return _gateway.voerUit((client) async {
      final record = await _users(client).update(gebruikerId, body: velden);
      return HhAccountGegevens.vanRecord(record);
    });
  }

  @override
  Future<Result<HhAccountGegevens>> uploadAccountFoto({
    required String gebruikerId,
    required Uint8List bytes,
    required String bestandsnaam,
  }) {
    return _gateway.voerUit((client) async {
      final record = await _users(client).update(
        gebruikerId,
        files: [
          http.MultipartFile.fromBytes('foto', bytes, filename: bestandsnaam),
        ],
      );
      return HhAccountGegevens.vanRecord(record);
    });
  }

  @override
  Future<Result<List<HhWijk>>> haalWijken() {
    return _gateway.voerUit((client) async {
      final records = await client
          .collection(hhWijkenCollectie)
          .getFullList(filter: 'actief = true', sort: 'gemeente,wijk');
      return [for (final r in records) HhWijk.vanRecord(r)];
    });
  }

  @override
  Future<Result<List<HhKlustype>>> haalKlustypes() {
    return _gateway.voerUit((client) async {
      final records = await client
          .collection(hhKlustypesCollectie)
          .getFullList(sort: 'naam');
      return [for (final r in records) HhKlustype.vanRecord(r)];
    });
  }
}
