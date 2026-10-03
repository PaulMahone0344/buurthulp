import 'package:http/http.dart' as http;

import '../../features/hulpvrager/model/hh_gegevens.dart';
import '../../features/hulpvrager/model/hh_klustype.dart';
import '../../features/hulpvrager/model/nieuwe_klus.dart';
import '../result.dart';
import 'pocketbase_gateway.dart';

const hhKlustypesCollectie = 'hh_klustypes';
const hhKlussenCollectie = 'hh_klussen';
const hhUsersCollectieVoorGegevens = 'hh_users';

/// Alles wat de hulpvraag-stroom (M4) van de server nodig heeft: de soorten
/// hulp, de eigen gegevens (lezen en partieel bijwerken) en een klus
/// plaatsen. Praat alleen tegen [PocketBaseGateway]; elke fout komt als
/// Nederlandse [HhFout] terug in een [Result].
///
/// M6: het schrijven van de logregel in hh_klus_status is hier weggehaald.
/// Dat doet de hook nu zelf bij het aanmaken van de klus (backend
/// OPEN-PUNT 16, app OPEN-PUNT M4:32); hh_klus_status.createRule staat
/// alleen nog open voor de coordinator.
abstract interface class KlusGateway {
  /// De categorieën die een bewoner kan kiezen (actief), in de volgorde
  /// van de tegels.
  Future<Result<List<HhKlustype>>> klustypes();

  /// De eigen hh_users-rij met adres en contactpersoon.
  Future<Result<HhGegevens>> mijnGegevens(String gebruikerId);

  /// Stuurt ALLEEN [velden] (backend OPEN-PUNT 10); nooit rol.
  Future<Result<HhGegevens>> gegevensBijwerken(
    String gebruikerId,
    Map<String, dynamic> velden,
  );

  /// Maakt de klus aan, met de foto als bestand, en geeft het nieuwe id
  /// terug.
  Future<Result<String>> klusAanmaken(NieuweKlus klus);
}

class PocketBaseKlusGateway implements KlusGateway {
  const PocketBaseKlusGateway(this._gateway);

  final PocketBaseGateway _gateway;

  @override
  Future<Result<List<HhKlustype>>> klustypes() {
    return _gateway.voerUit((client) async {
      final records = await client
          .collection(hhKlustypesCollectie)
          .getFullList(filter: 'actief = true', sort: 'volgorde,naam');
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
          .create(
            body: klus.alsBody,
            files: [
              http.MultipartFile.fromBytes(
                NieuweKlus.veldFoto,
                klus.foto.bytes,
                filename: klus.foto.bestandsnaam,
              ),
            ],
          );
      return record.id;
    });
  }
}
