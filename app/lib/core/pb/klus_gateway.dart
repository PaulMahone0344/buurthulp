import '../../features/hulpvrager/model/hh_gegevens.dart';
import '../../features/hulpvrager/model/hh_klustype.dart';
import '../../features/hulpvrager/model/nieuwe_klus.dart';
import '../result.dart';
import 'pocketbase_gateway.dart';

const hhKlustypesCollectie = 'hh_klustypes';
const hhKlussenCollectie = 'hh_klussen';
const hhKlusStatusCollectie = 'hh_klus_status';
const hhUsersCollectieVoorGegevens = 'hh_users';

/// Alles wat de hulpvraag-stroom (M4) van de server nodig heeft: de soorten
/// hulp, de eigen gegevens (lezen en partieel bijwerken), een klus plaatsen
/// en een logregel schrijven. Praat alleen tegen [PocketBaseGateway]; elke
/// fout komt als Nederlandse [HhFout] terug in een [Result].
abstract interface class KlusGateway {
  /// Alle hh_klustypes, op naam gesorteerd.
  Future<Result<List<HhKlustype>>> klustypes();

  /// De eigen hh_users-rij met adres en contactpersoon.
  Future<Result<HhGegevens>> mijnGegevens(String gebruikerId);

  /// Stuurt ALLEEN [velden] (backend OPEN-PUNT 10); nooit rol.
  Future<Result<HhGegevens>> gegevensBijwerken(
    String gebruikerId,
    Map<String, dynamic> velden,
  );

  /// Maakt de klus aan en geeft het nieuwe id terug.
  Future<Result<String>> klusAanmaken(NieuweKlus klus);

  /// Een regel in hh_klus_status: [van] leeg bij de eerste regel.
  Future<Result<void>> statusLoggen({
    required String klusId,
    required String doorId,
    required String van,
    required String naar,
  });
}

class PocketBaseKlusGateway implements KlusGateway {
  const PocketBaseKlusGateway(this._gateway);

  final PocketBaseGateway _gateway;

  @override
  Future<Result<List<HhKlustype>>> klustypes() {
    return _gateway.voerUit((client) async {
      final records = await client
          .collection(hhKlustypesCollectie)
          .getFullList(sort: 'naam');
      return [for (final record in records) HhKlustype.vanRecord(record)];
    });
  }

  @override
  Future<Result<HhGegevens>> mijnGegevens(String gebruikerId) {
    return _gateway.voerUit((client) async {
      final record = await client
          .collection(hhUsersCollectieVoorGegevens)
          .getOne(gebruikerId);
      return HhGegevens.vanRecord(record);
    });
  }

  @override
  Future<Result<HhGegevens>> gegevensBijwerken(
    String gebruikerId,
    Map<String, dynamic> velden,
  ) {
    assert(!velden.containsKey('rol'), 'rol mag nooit mee in een update');
    return _gateway.voerUit((client) async {
      final record = await client
          .collection(hhUsersCollectieVoorGegevens)
          .update(gebruikerId, body: velden);
      return HhGegevens.vanRecord(record);
    });
  }

  @override
  Future<Result<String>> klusAanmaken(NieuweKlus klus) {
    return _gateway.voerUit((client) async {
      final record = await client
          .collection(hhKlussenCollectie)
          .create(body: klus.alsBody);
      return record.id;
    });
  }

  @override
  Future<Result<void>> statusLoggen({
    required String klusId,
    required String doorId,
    required String van,
    required String naar,
  }) {
    return _gateway.voerUit((client) async {
      await client
          .collection(hhKlusStatusCollectie)
          .create(
            body: {'klus': klusId, 'door': doorId, 'van': van, 'naar': naar},
          );
    });
  }
}
