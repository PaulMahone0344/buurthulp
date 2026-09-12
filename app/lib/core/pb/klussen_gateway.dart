import 'package:pocketbase/pocketbase.dart';

import '../../features/jongere/klussen/model/hh_klus.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'pocketbase_gateway.dart';

const hhKlussenCollectieJongere = 'hh_klussen';

/// De route uit de hook backend/pb_hooks/hh_klussen.pb.js (M5, keuze 4).
String accepteerRoute(String klusId) => '/api/hh/klussen/$klusId/accepteren';

/// Waarom de server een acceptatie weigerde.
enum AccepteerReden {
  /// 409: net door iemand anders aangenomen, niet meer open, of andere wijk.
  bezet,

  /// 403: geen jongere, niet goedgekeurd, of geen werkgebied.
  geenToegang,

  /// 404: de klus bestaat niet (meer).
  nietGevonden,
}

/// De uitkomst van "Klus aannemen". Geen [Result]: een 409 is geen fout van
/// de app maar een gewone uitkomst met een Nederlandse melding van de server.
sealed class AccepteerUitkomst {
  const AccepteerUitkomst();
}

final class Geaccepteerd extends AccepteerUitkomst {
  const Geaccepteerd();
}

final class Geweigerd extends AccepteerUitkomst {
  const Geweigerd(this.reden, {this.melding});

  final AccepteerReden reden;

  /// De melding van de server ("Deze klus is net door iemand anders
  /// aangenomen."), als die er was.
  final String? melding;
}

final class AccepteerFout extends AccepteerUitkomst {
  const AccepteerFout(this.fout);

  final HhFout fout;
}

/// Alles wat J11-J14 van de server nodig heeft: de open klussen in de wijk
/// (de list-rule filtert op wijk en goedkeuring), de eigen klussen, een
/// klus, en accepteren via de hook-route.
abstract interface class KlussenGateway {
  /// Open klussen zonder jongere, vroegste eerst.
  Future<Result<List<HhKlus>>> openKlussen();

  /// Klussen die aan [jongereId] zijn toegewezen, laatste eerst.
  Future<Result<List<HhKlus>>> mijnKlussen(String jongereId);

  Future<Result<HhKlus>> klus(String id);

  /// POST /api/hh/klussen/{id}/accepteren.
  Future<AccepteerUitkomst> accepteren(String klusId);
}

class PocketBaseKlussenGateway implements KlussenGateway {
  const PocketBaseKlussenGateway(this._gateway);

  final PocketBaseGateway _gateway;

  static const _miniatuur = '200x200';

  HhKlus _klusVan(PocketBase client, RecordModel record) => HhKlus.vanRecord(
    record,
    fotoUrl: (oudere, bestand) =>
        client.files.getURL(oudere, bestand, thumb: _miniatuur).toString(),
  );

  @override
  Future<Result<List<HhKlus>>> openKlussen() {
    return _gateway.voerUit((client) async {
      final records = await client
          .collection(hhKlussenCollectieJongere)
          .getFullList(
            filter: 'status = "open" && toegewezen_jongere = ""',
            sort: 'wanneer_van',
            expand: HhKlus.expand,
          );
      return [for (final r in records) _klusVan(client, r)];
    });
  }

  @override
  Future<Result<List<HhKlus>>> mijnKlussen(String jongereId) {
    return _gateway.voerUit((client) async {
      final records = await client
          .collection(hhKlussenCollectieJongere)
          .getFullList(
            filter: client.filter('toegewezen_jongere = {:id}', {
              'id': jongereId,
            }),
            sort: '-wanneer_van',
            expand: HhKlus.expand,
          );
      return [for (final r in records) _klusVan(client, r)];
    });
  }

  @override
  Future<Result<HhKlus>> klus(String id) {
    return _gateway.voerUit((client) async {
      final record = await client
          .collection(hhKlussenCollectieJongere)
          .getOne(id, expand: HhKlus.expand);
      return _klusVan(client, record);
    });
  }

  @override
  Future<AccepteerUitkomst> accepteren(String klusId) async {
    final result = await _gateway.voerUit<AccepteerUitkomst>((client) async {
      try {
        await client.send(accepteerRoute(klusId), method: 'POST');
        return const Geaccepteerd();
      } on ClientException catch (e) {
        final reden = switch (e.statusCode) {
          409 => AccepteerReden.bezet,
          403 => AccepteerReden.geenToegang,
          404 => AccepteerReden.nietGevonden,
          _ => null,
        };
        if (reden == null) rethrow;
        return Geweigerd(reden, melding: _meldingUit(e.response));
      }
    });
    return switch (result) {
      Ok<AccepteerUitkomst>(:final waarde) => waarde,
      Err<AccepteerUitkomst>(:final fout) => AccepteerFout(fout),
    };
  }

  /// De hook antwoordt {melding, reden}; PocketBase zelf {message}.
  static String? _meldingUit(Map<String, dynamic> antwoord) {
    final melding = antwoord['melding'];
    if (melding is String && melding.trim().isNotEmpty) return melding;
    return null;
  }
}
