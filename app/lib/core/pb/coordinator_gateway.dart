import 'dart:async';

import 'package:pocketbase/pocketbase.dart';

import '../../features/coordinator/model/hh_coordinator_klus.dart';
import '../../features/coordinator/model/hh_incident.dart';
import '../../features/coordinator/model/hh_kandidaat.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'pocketbase_gateway.dart';

const hhIncidentenCollectie = 'hh_incidenten';
const hhKlussenCollectieCoordinator = 'hh_klussen';
const hhProfielenCollectieCoordinator = 'hh_profielen';

/// De twee routes uit de hook backend/pb_hooks/hh_coordinator.pb.js (M10).
String koppelRoute(String klusId) => '/api/hh/klussen/$klusId/koppelen';
String vrijgeefRoute(String klusId) => '/api/hh/klussen/$klusId/vrijgeven';

/// Wat de realtime-verbinding op hh_incidenten meldt.
enum IncidentWijzigingSoort { nieuw, gewijzigd, verwijderd }

class IncidentWijziging {
  const IncidentWijziging(this.soort, this.id, {this.incident});

  final IncidentWijzigingSoort soort;
  final String id;

  /// Null bij [IncidentWijzigingSoort.verwijderd].
  final HhIncident? incident;
}

/// Waarom de server koppelen of vrijgeven weigerde.
enum KoppelReden {
  /// 409 bezet: de klus is niet meer open.
  bezet,

  /// 409: de gekozen gebruiker is geen (goedgekeurde) jongere.
  jongereNietGeschikt,

  /// 409: deze klus staat niet op geaccepteerd of onderweg.
  nietVrijTeGeven,

  /// 403: deze rol mag dit niet.
  geenToegang,

  /// 404: de klus bestaat niet (meer).
  nietGevonden,

  /// 400: de app stuurde geen jongere of geen reden mee.
  ongeldigeInvoer,
}

/// De uitkomst van koppelen of vrijgeven. Geen [Result]: een 409 is geen
/// fout van de app maar een gewone uitkomst met een Nederlandse melding van
/// de server.
sealed class KoppelUitkomst {
  const KoppelUitkomst();
}

final class KoppelGelukt extends KoppelUitkomst {
  const KoppelGelukt({this.isAndereWijk = false});

  /// Alleen bij koppelen: de jongere woont in een andere wijk dan de
  /// oudere. De app waarschuwt daar vooraf al voor; dit is het antwoord
  /// van de server erop.
  final bool isAndereWijk;
}

final class KoppelGeweigerd extends KoppelUitkomst {
  const KoppelGeweigerd(this.reden, {this.melding});

  final KoppelReden reden;

  /// De melding van de server, als die er was.
  final String? melding;
}

final class KoppelFout extends KoppelUitkomst {
  const KoppelFout(this.fout);

  final HhFout fout;
}

/// Alles wat C1 en C2 van de server nodig hebben. De coordinator mag alles
/// lezen op de hh_-collecties, dus er zit geen filter op rechten in.
abstract interface class CoordinatorGateway {
  /// Alle meldingen, nieuwste eerst (C1).
  Future<Result<List<HhIncident>>> incidenten();

  /// Realtime op hh_incidenten. De stroom stopt zodra de laatste luisteraar
  /// weg is. Fouten (geen netwerk) komen als foutgebeurtenis binnen; de
  /// lijst zelf blijft staan.
  Stream<IncidentWijziging> incidentStroom();

  /// Zet de afhandeling op een melding (C1). Leeg is aan de app om te
  /// weigeren; de server kent geen verplichting.
  Future<Result<HhIncident>> handelAf(String incidentId, String afhandeling);

  /// Open klussen zonder jongere, OUDSTE eerst (C2): wat het langst ligt,
  /// staat bovenaan.
  Future<Result<List<HhCoordinatorKlus>>> openKlussen();

  Future<Result<HhCoordinatorKlus>> klus(String id);

  /// De goedgekeurde jongeren, voor de koppellijst.
  Future<Result<List<HhKandidaat>>> goedgekeurdeJongeren();

  /// POST /api/hh/klussen/{id}/koppelen.
  Future<KoppelUitkomst> koppelen(String klusId, String jongereId);

  /// POST /api/hh/klussen/{id}/vrijgeven.
  Future<KoppelUitkomst> vrijgeven(String klusId, String reden);
}

class PocketBaseCoordinatorGateway implements CoordinatorGateway {
  const PocketBaseCoordinatorGateway(this._gateway);

  final PocketBaseGateway _gateway;

  @override
  Future<Result<List<HhIncident>>> incidenten() {
    return _gateway.voerUit((client) async {
      final records = await client
          .collection(hhIncidentenCollectie)
          .getFullList(sort: '-created', expand: HhIncident.expand);
      return [for (final r in records) HhIncident.vanRecord(r)];
    });
  }

  @override
  Stream<IncidentWijziging> incidentStroom() {
    late StreamController<IncidentWijziging> controller;
    UnsubscribeFunc? stop;

    Future<void> start() async {
      final result = await _gateway.voerUit<UnsubscribeFunc>((client) {
        return client
            .collection(hhIncidentenCollectie)
            .subscribe('*', (e) {
              final record = e.record;
              if (record == null) return;
              final soort = switch (e.action) {
                'create' => IncidentWijzigingSoort.nieuw,
                'delete' => IncidentWijzigingSoort.verwijderd,
                _ => IncidentWijzigingSoort.gewijzigd,
              };
              controller.add(
                IncidentWijziging(
                  soort,
                  record.id,
                  incident: soort == IncidentWijzigingSoort.verwijderd
                      ? null
                      : HhIncident.vanRecord(record),
                ),
              );
            }, expand: HhIncident.expand);
      });
      switch (result) {
        case Ok<UnsubscribeFunc>(:final waarde):
          stop = waarde;
        case Err<UnsubscribeFunc>(:final fout):
          controller.addError(fout);
      }
    }

    controller = StreamController<IncidentWijziging>(
      onListen: start,
      onCancel: () async => stop?.call(),
    );
    return controller.stream;
  }

  @override
  Future<Result<HhIncident>> handelAf(String incidentId, String afhandeling) {
    return _gateway.voerUit((client) async {
      final record = await client
          .collection(hhIncidentenCollectie)
          .update(
            incidentId,
            body: {'afhandeling': afhandeling},
            expand: HhIncident.expand,
          );
      return HhIncident.vanRecord(record);
    });
  }

  @override
  Future<Result<List<HhCoordinatorKlus>>> openKlussen() {
    return _gateway.voerUit((client) async {
      final records = await client
          .collection(hhKlussenCollectieCoordinator)
          .getFullList(
            filter: 'status = "open" && toegewezen_jongere = ""',
            sort: 'created',
            expand: HhCoordinatorKlus.expand,
          );
      return [for (final r in records) HhCoordinatorKlus.vanRecord(r)];
    });
  }

  @override
  Future<Result<HhCoordinatorKlus>> klus(String id) {
    return _gateway.voerUit((client) async {
      final record = await client
          .collection(hhKlussenCollectieCoordinator)
          .getOne(id, expand: HhCoordinatorKlus.expand);
      return HhCoordinatorKlus.vanRecord(record);
    });
  }

  @override
  Future<Result<List<HhKandidaat>>> goedgekeurdeJongeren() {
    return _gateway.voerUit((client) async {
      final records = await client
          .collection(hhProfielenCollectieCoordinator)
          .getFullList(
            filter:
                'verificatiestatus = "goedgekeurd" && gebruiker.rol = "jongere"',
            sort: 'gebruiker.naam',
            expand: HhKandidaat.expand,
          );
      return [for (final r in records) ?HhKandidaat.vanProfielRecord(r)];
    });
  }

  @override
  Future<KoppelUitkomst> koppelen(String klusId, String jongereId) {
    return _stuur(koppelRoute(klusId), {'jongere': jongereId});
  }

  @override
  Future<KoppelUitkomst> vrijgeven(String klusId, String reden) {
    return _stuur(vrijgeefRoute(klusId), {'reden': reden});
  }

  /// Beide routes antwoorden op dezelfde manier: 200 met een body, of een
  /// statuscode met {melding, reden}.
  Future<KoppelUitkomst> _stuur(String pad, Map<String, String> body) async {
    final result = await _gateway.voerUit<KoppelUitkomst>((client) async {
      try {
        final antwoord = await client.send(pad, method: 'POST', body: body);
        return KoppelGelukt(
          isAndereWijk: antwoord is Map && antwoord['andere_wijk'] == true,
        );
      } on ClientException catch (e) {
        final reden = _redenVan(e.statusCode, _redenCodeUit(e.response));
        if (reden == null) rethrow;
        return KoppelGeweigerd(reden, melding: _meldingUit(e.response));
      }
    });
    return switch (result) {
      Ok<KoppelUitkomst>(:final waarde) => waarde,
      Err<KoppelUitkomst>(:final fout) => KoppelFout(fout),
    };
  }

  /// De hook zet naast de statuscode een korte reden in de body, zodat 409
  /// "bezet" te onderscheiden is van 409 "nietgoedgekeurd".
  static KoppelReden? _redenVan(int statuscode, String redenCode) {
    return switch (statuscode) {
      400 => KoppelReden.ongeldigeInvoer,
      403 => KoppelReden.geenToegang,
      404 => KoppelReden.nietGevonden,
      409 => switch (redenCode) {
        'jongeronbekend' ||
        'geenjongere' ||
        'nietgoedgekeurd' => KoppelReden.jongereNietGeschikt,
        'nietvrijtegeven' => KoppelReden.nietVrijTeGeven,
        _ => KoppelReden.bezet,
      },
      _ => null,
    };
  }

  static String _redenCodeUit(Map<String, dynamic> antwoord) {
    final reden = antwoord['reden'];
    return reden is String ? reden : '';
  }

  /// De hook antwoordt {melding, reden}; PocketBase zelf {message}.
  static String? _meldingUit(Map<String, dynamic> antwoord) {
    final melding = antwoord['melding'];
    if (melding is String && melding.trim().isNotEmpty) return melding;
    return null;
  }
}
