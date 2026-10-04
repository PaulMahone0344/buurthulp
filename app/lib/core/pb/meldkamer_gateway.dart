import '../../features/coordinator/model/hh_te_doen.dart';
import '../result.dart';
import 'pocketbase_gateway.dart';

/// Routes uit de hooks: kennismaking (B11, hh_meldkamer.pb.js), keuren (B4,
/// hh_klusplaatsen.pb.js) en ouder vrijgeven (B3, hh_ouder.pb.js).
String kennismakingRoute(String bewonerId) =>
    '/api/hh/meldkamer/kennismaking/$bewonerId';
String keurRoute(String klusId) => '/api/hh/klussen/$klusId/keuren';
const ouderVrijgevenRoute = '/api/hh/ouder/vrijgeven';

/// B11: de snelle handelingen van de meldkamer in de app. Fouten van de
/// server (409 met een Nederlandse melding) komen als Err; HhFout.melding
/// toont dan de algemene zin, [MeldkamerFout.serverMelding] de echte.
abstract interface class MeldkamerGateway {
  /// Alle vier lijsten van "Te doen" tegelijk.
  Future<Result<HhTeDoen>> teDoen();

  /// POST kennismaking: gesproken of geweigerd, met notitie.
  Future<Result<KennismakingUitkomst>> kennismaking(
    String bewonerId,
    KennismakingBesluit besluit,
    String notitie,
  );

  /// PATCH hh_profielen: goedgekeurd of afgewezen, met notitie.
  Future<Result<void>> beoordeelHelper(
    String profielId, {
    required bool goedkeuren,
    required String notitie,
  });

  /// POST /api/hh/ouder/vrijgeven.
  Future<Result<void>> ouderVrijgeven(String helperId);

  /// POST keuren: goedkeuren, of afkeuren met reden.
  Future<Result<void>> keurKlus(
    String klusId, {
    required bool goedkeuren,
    String reden = '',
  });
}

class PocketBaseMeldkamerGateway implements MeldkamerGateway {
  const PocketBaseMeldkamerGateway(this._gateway);

  final PocketBaseGateway _gateway;

  @override
  Future<Result<HhTeDoen>> teDoen() {
    return _gateway.voerUit((client) async {
      final antwoorden = await Future.wait([
        client
            .collection('hh_users')
            .getFullList(filter: HhTeBellen.filter, sort: 'created'),
        client
            .collection('hh_profielen')
            .getFullList(
              filter:
                  'gebruiker.rol = "jongere" && verificatiestatus = "in_behandeling"',
              sort: 'updated',
              expand: HhTeKeurenHelper.expand,
            ),
        client
            .collection('hh_ouder_toestemming')
            .getFullList(
              filter: 'status = "ingetrokken"',
              sort: 'updated',
              expand: HhOuderIngetrokken.expand,
            ),
        client
            .collection('hh_klussen')
            .getFullList(
              filter: HhTeKeurenKlus.filter,
              sort: 'created',
              expand: HhTeKeurenKlus.expand,
            ),
      ]);
      return HhTeDoen(
        bellen: [for (final r in antwoorden[0]) HhTeBellen.vanRecord(r)],
        helpers: [
          for (final r in antwoorden[1]) HhTeKeurenHelper.vanProfielRecord(r),
        ],
        ouders: [
          for (final r in antwoorden[2]) HhOuderIngetrokken.vanRecord(r),
        ],
        klussen: [for (final r in antwoorden[3]) HhTeKeurenKlus.vanRecord(r)],
      );
    });
  }

  @override
  Future<Result<KennismakingUitkomst>> kennismaking(
    String bewonerId,
    KennismakingBesluit besluit,
    String notitie,
  ) {
    return _gateway.voerUit((client) async {
      final antwoord = await client.send<Map<String, dynamic>>(
        kennismakingRoute(bewonerId),
        method: 'POST',
        body: {'besluit': besluit.name, 'notitie': notitie.trim()},
      );
      int getal(String veld) {
        final w = antwoord[veld];
        return w is num ? w.toInt() : 0;
      }

      return KennismakingUitkomst(
        geannuleerd: getal('geannuleerd'),
        lopend: getal('lopend'),
      );
    });
  }

  @override
  Future<Result<void>> beoordeelHelper(
    String profielId, {
    required bool goedkeuren,
    required String notitie,
  }) {
    return _gateway.voerUit((client) async {
      await client
          .collection('hh_profielen')
          .update(
            profielId,
            body: {
              'verificatiestatus': goedkeuren ? 'goedgekeurd' : 'afgewezen',
              'screening_notitie': notitie.trim(),
            },
          );
    });
  }

  @override
  Future<Result<void>> ouderVrijgeven(String helperId) {
    return _gateway.voerUit((client) async {
      await client.send<dynamic>(
        ouderVrijgevenRoute,
        method: 'POST',
        body: {'helper': helperId},
      );
    });
  }

  @override
  Future<Result<void>> keurKlus(
    String klusId, {
    required bool goedkeuren,
    String reden = '',
  }) {
    return _gateway.voerUit((client) async {
      await client.send<dynamic>(
        keurRoute(klusId),
        method: 'POST',
        body: goedkeuren
            ? {'besluit': 'goedkeuren'}
            : {'besluit': 'afkeuren', 'reden': reden.trim()},
      );
    });
  }
}
