import 'package:pocketbase/pocketbase.dart';

import '../../features/familie/model/hh_koppeling.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'pocketbase_gateway.dart';

/// De route uit backend/pb_hooks/hh_familie.pb.js.
const aanvraagRoute = '/api/hh/koppelingen/aanvragen';

sealed class AanvraagUitkomst {
  const AanvraagUitkomst();
}

/// Altijd hetzelfde vaste bericht, of het adres nu bestaat of niet.
final class AanvraagVerstuurd extends AanvraagUitkomst {
  const AanvraagVerstuurd(this.melding);

  final String melding;
}

enum AanvraagReden {
  /// 400: geen geldig e-mailadres.
  email,

  /// 429: vandaag al vijf keer aangevraagd.
  limiet,

  /// 403: geen familielid.
  rol,
}

final class AanvraagGeweigerd extends AanvraagUitkomst {
  const AanvraagGeweigerd(this.reden, {this.melding});

  final AanvraagReden reden;
  final String? melding;
}

final class AanvraagFout extends AanvraagUitkomst {
  const AanvraagFout(this.fout);

  final HhFout fout;
}

/// Alles rond familie (M9): aanvragen, de koppelingen van het familielid
/// (F1) en van de oudere (O12), toestemming geven en ontkoppelen. De
/// hulpvragen van de oudere komen via de uitvoer-gateway van M6; de rules
/// (script 41) bepalen wat het familielid daar ziet.
abstract interface class FamilieGateway {
  Future<AanvraagUitkomst> aanvragen(String emailOudere);

  /// De koppelingen van het familielid, met de naam van de oudere (die de
  /// server alleen bij een actieve koppeling meegeeft).
  Future<Result<List<HhKoppeling>>> vanFamilielid(String familielidId);

  /// De koppelingen van de oudere, met de naam van het familielid.
  Future<Result<List<HhKoppeling>>> vanOudere(String oudereId);

  /// "Ja": status actief met beide rechten.
  Future<Result<HhKoppeling>> geefToestemming(String koppelingId);

  /// "Nee" en "Ontkoppelen": de koppeling weg.
  Future<Result<void>> verwijder(String koppelingId);
}

class PocketBaseFamilieGateway implements FamilieGateway {
  const PocketBaseFamilieGateway(this._gateway);

  final PocketBaseGateway _gateway;

  @override
  Future<AanvraagUitkomst> aanvragen(String emailOudere) async {
    final result = await _gateway.voerUit<AanvraagUitkomst>((client) async {
      try {
        final antwoord = await client.send(
          aanvraagRoute,
          method: 'POST',
          body: {'email_oudere': emailOudere.trim()},
        );
        return AanvraagVerstuurd(_melding(antwoord) ?? '');
      } on ClientException catch (e) {
        final reden = switch (e.statusCode) {
          400 => AanvraagReden.email,
          403 => AanvraagReden.rol,
          429 => AanvraagReden.limiet,
          _ => null,
        };
        if (reden == null) rethrow;
        return AanvraagGeweigerd(reden, melding: _melding(e.response));
      }
    });
    return switch (result) {
      Ok<AanvraagUitkomst>(:final waarde) => waarde,
      Err<AanvraagUitkomst>(:final fout) => AanvraagFout(fout),
    };
  }

  static String? _melding(Object? antwoord) {
    if (antwoord is Map && antwoord['melding'] is String) {
      final m = (antwoord['melding'] as String).trim();
      return m.isEmpty ? null : m;
    }
    return null;
  }

  Future<Result<List<HhKoppeling>>> _lijst(
    String filter,
    Map<String, dynamic> params,
    String expand,
  ) {
    return _gateway.voerUit((client) async {
      final records = await client
          .collection(HhKoppeling.collectie)
          .getFullList(
            filter: client.filter(filter, params),
            expand: expand,
            sort: 'created',
          );
      return [for (final r in records) HhKoppeling.vanRecord(r)];
    });
  }

  @override
  Future<Result<List<HhKoppeling>>> vanFamilielid(String familielidId) =>
      _lijst('familielid = {:id}', {'id': familielidId}, 'oudere');

  @override
  Future<Result<List<HhKoppeling>>> vanOudere(String oudereId) =>
      _lijst('oudere = {:id}', {'id': oudereId}, 'familielid');

  @override
  Future<Result<HhKoppeling>> geefToestemming(String koppelingId) {
    return _gateway.voerUit((client) async {
      final record = await client
          .collection(HhKoppeling.collectie)
          .update(
            koppelingId,
            body: {
              'status': KoppelingStatus.actief.code,
              'rechten': [for (final r in FamilieRecht.values) r.code],
            },
            expand: 'familielid',
          );
      return HhKoppeling.vanRecord(record);
    });
  }

  @override
  Future<Result<void>> verwijder(String koppelingId) {
    return _gateway.voerUit<void>(
      (client) => client.collection(HhKoppeling.collectie).delete(koppelingId),
    );
  }
}
