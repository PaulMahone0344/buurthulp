import 'package:pocketbase/pocketbase.dart';

import '../../features/jongere/ouder/model/hh_ouder_stand.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'pocketbase_gateway.dart';

/// De routes uit backend/pb_hooks/hh_ouder.pb.js (B3).
const hhOuderStatusPad = '/api/hh/ouder/status';
const hhOuderVersturenPad = '/api/hh/ouder/versturen';

/// Uitkomst van "mail naar mijn ouder".
sealed class OuderVerstuurUitkomst {
  const OuderVerstuurUitkomst();
}

final class OuderVerstuurd extends OuderVerstuurUitkomst {
  const OuderVerstuurd(this.stand);
  final HhOuderStand stand;
}

/// De server weigerde met een eigen melding (je-vorm): limiet (3 per dag),
/// email, eigenadres, algegeven, volwassen, mail (502).
final class OuderGeweigerd extends OuderVerstuurUitkomst {
  const OuderGeweigerd(this.reden, this.melding);
  final String reden;
  final String melding;
}

final class OuderVerstuurFout extends OuderVerstuurUitkomst {
  const OuderVerstuurFout(this.fout);
  final HhFout fout;
}

/// B3: ouder-toestemming vanuit de helper-app. De code gaat NOOIT naar de
/// app: de ouder vult hem in op de website (K2).
abstract interface class OuderGateway {
  Future<Result<HhOuderStand>> haalStand();

  /// Stuurt (opnieuw) een mail met code naar de ouder. Met [ouderEmail]
  /// wordt dat het nieuwe adres (ook op hh_users.ouder_email).
  Future<OuderVerstuurUitkomst> verstuur({String? ouderEmail});
}

class PocketBaseOuderGateway implements OuderGateway {
  const PocketBaseOuderGateway(this._gateway);

  final PocketBaseGateway _gateway;

  @override
  Future<Result<HhOuderStand>> haalStand() => _gateway.voerUit((client) async {
    final antwoord = await client.send(hhOuderStatusPad);
    return HhOuderStand.vanJson(_alsMap(antwoord));
  });

  @override
  Future<OuderVerstuurUitkomst> verstuur({String? ouderEmail}) async {
    final body = <String, dynamic>{
      if (ouderEmail != null && ouderEmail.trim().isNotEmpty)
        'ouder_email': ouderEmail.trim(),
    };
    final result = await _gateway.voerUit<OuderVerstuurUitkomst>((
      client,
    ) async {
      try {
        final antwoord = await client.send(
          hhOuderVersturenPad,
          method: 'POST',
          body: body,
        );
        return OuderVerstuurd(HhOuderStand.vanJson(_alsMap(antwoord)));
      } on ClientException catch (e) {
        final data = _alsMap(e.response);
        final reden = '${data['reden'] ?? ''}';
        final melding = '${data['melding'] ?? ''}';
        // Alleen een weigering van de hook zelf; 401 en geen verbinding
        // gaan de gewone weg (sessie verlopen, offline).
        if (reden.isEmpty || melding.isEmpty || e.statusCode == 401) rethrow;
        return OuderGeweigerd(reden, melding);
      }
    });
    return switch (result) {
      Ok<OuderVerstuurUitkomst>(:final waarde) => waarde,
      Err<OuderVerstuurUitkomst>(:final fout) => OuderVerstuurFout(fout),
    };
  }

  static Map<String, dynamic> _alsMap(Object? waarde) {
    if (waarde is Map<String, dynamic>) return waarde;
    if (waarde is Map) return waarde.map((k, v) => MapEntry('$k', v));
    return const {};
  }
}
