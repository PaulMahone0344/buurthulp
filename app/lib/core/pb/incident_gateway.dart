import '../result.dart';
import 'pocketbase_gateway.dart';

const hhIncidentenCollectie = 'hh_incidenten';

/// De twee soorten die O11 meldt (hh_incidenten.soort kent ook overig; die
/// maakt de app niet).
enum IncidentSoort {
  nood('nood'),
  probleem('probleem');

  const IncidentSoort(this.code);

  final String code;
}

/// O11: een incident melden via de gewone API (createRule: melder =
/// jijzelf; met een klus alleen als je deelnemer bent). De hook maakt er
/// meldingen van voor de coordinatoren.
abstract interface class IncidentGateway {
  /// Geeft het id van het nieuwe incident.
  Future<Result<String>> meld({
    required String melderId,
    required IncidentSoort soort,
    String klusId = '',
    String omschrijving = '',
  });
}

class PocketBaseIncidentGateway implements IncidentGateway {
  const PocketBaseIncidentGateway(this._gateway);

  final PocketBaseGateway _gateway;

  @override
  Future<Result<String>> meld({
    required String melderId,
    required IncidentSoort soort,
    String klusId = '',
    String omschrijving = '',
  }) {
    return _gateway.voerUit((client) async {
      final record = await client
          .collection(hhIncidentenCollectie)
          .create(
            body: {
              'melder': melderId,
              'soort': soort.code,
              if (klusId.isNotEmpty) 'klus': klusId,
              if (omschrijving.trim().isNotEmpty)
                'omschrijving': omschrijving.trim(),
            },
          );
      return record.id;
    });
  }
}
