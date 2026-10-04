import 'package:pocketbase/pocketbase.dart';

import '../../features/jongere/model/hh_profiel.dart' show HhProfiel;
import '../../features/reacties/model/hh_reactie.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'pocketbase_gateway.dart';

/// De routes uit backend/pb_hooks/hh_reacties.pb.js (B5).
String reageerRoute(String klusId) => '/api/hh/klussen/$klusId/reageren';
String reactiesRoute(String klusId) => '/api/hh/klussen/$klusId/reacties';
String kiesRoute(String klusId) => '/api/hh/klussen/$klusId/kiezen';
String intrekRoute(String reactieId) => '/api/hh/reacties/$reactieId/intrekken';
const hhBeschikbaarPad = '/api/hh/beschikbaar';

/// Uitkomst van "Ik wil helpen".
sealed class ReageerUitkomst {
  const ReageerUitkomst();
}

final class Gereageerd extends ReageerUitkomst {
  const Gereageerd({required this.status, this.melding = ''});

  /// open (18+) of wachtOpOuder (helper onder 18).
  final HhReactieStatus status;
  final String melding;
}

/// De server weigerde met een eigen melding: bezet, leeftijd, oudermee
/// (eerste klus: vinkje "Mijn ouder gaat mee"), algereageerd, limiet, ...
final class ReageerGeweigerd extends ReageerUitkomst {
  const ReageerGeweigerd(this.reden, this.melding);
  final String reden;
  final String melding;

  bool get vraagtOuderMee => reden == 'oudermee';

  /// B5: helpers onder 18 kunnen nog niet reageren (schakelaar op de server).
  bool get isOnder18Dicht => reden == 'onder18';
}

final class ReageerFout extends ReageerUitkomst {
  const ReageerFout(this.fout);
  final HhFout fout;
}

/// Uitkomst van "Kies [naam]".
sealed class KiesUitkomst {
  const KiesUitkomst();
}

final class Gekozen extends KiesUitkomst {
  const Gekozen({required this.helperVoornaam, this.melding = ''});
  final String helperVoornaam;
  final String melding;
}

/// klusbezet (al gekozen), reactieweg (helper niet meer beschikbaar),
/// helperbezet (heeft op dat moment al een klus).
final class KiesGeweigerd extends KiesUitkomst {
  const KiesGeweigerd(this.reden, this.melding);
  final String reden;
  final String melding;
}

final class KiesFout extends KiesUitkomst {
  const KiesFout(this.fout);
  final HhFout fout;
}

/// B5: reageren, kiezen, intrekken en "Ik kan nu helpen".
abstract interface class ReactieGateway {
  /// POST .../reageren. [bericht] mag leeg zijn (max 200; de server filtert
  /// nummers en links). [ouderGaatMee]: het vinkje bij de eerste klus.
  Future<ReageerUitkomst> reageren(
    String klusId, {
    String bericht = '',
    bool ouderGaatMee = false,
  });

  /// De eigen reacties van [helperId], nieuwste eerst.
  Future<Result<List<HhReactie>>> mijnReacties(String helperId);

  Future<Result<void>> intrekken(String reactieId);

  /// GET .../reacties: de kaarten voor KiesHelper (bewoner).
  Future<Result<List<HhReactieKaart>>> reactiesVoorKlus(String klusId);

  Future<KiesUitkomst> kiezen(String klusId, String reactieId);

  /// "Ik kan nu helpen" aan (nu + 3 uur) of uit. Geeft het nieuwe
  /// eindmoment, of null als hij uit staat.
  Future<Result<DateTime?>> zetBeschikbaar(bool aan);

  /// Hoeveel helpers kunnen nu (alleen een aantal; bewoner).
  Future<Result<int>> aantalBeschikbaar({
    required String klustypeId,
    DateTime? van,
    DateTime? tot,
  });
}

class PocketBaseReactieGateway implements ReactieGateway {
  const PocketBaseReactieGateway(this._gateway);

  final PocketBaseGateway _gateway;

  @override
  Future<ReageerUitkomst> reageren(
    String klusId, {
    String bericht = '',
    bool ouderGaatMee = false,
  }) async {
    final result = await _gateway.voerUit<ReageerUitkomst>((client) async {
      try {
        final antwoord = _alsMap(
          await client.send(
            reageerRoute(klusId),
            method: 'POST',
            body: {'bericht': bericht.trim(), 'ouder_gaat_mee': ouderGaatMee},
          ),
        );
        return Gereageerd(
          status: HhReactieStatus.vanCode('${antwoord['status'] ?? ''}'),
          melding: '${antwoord['melding'] ?? ''}',
        );
      } on ClientException catch (e) {
        final w = _weigering(e);
        if (w == null) rethrow;
        return ReageerGeweigerd(w.$1, w.$2);
      }
    });
    return switch (result) {
      Ok<ReageerUitkomst>(:final waarde) => waarde,
      Err<ReageerUitkomst>(:final fout) => ReageerFout(fout),
    };
  }

  @override
  Future<Result<List<HhReactie>>> mijnReacties(String helperId) {
    return _gateway.voerUit((client) async {
      final records = await client
          .collection(HhReactie.collectie)
          .getFullList(
            filter: client.filter('helper = {:id}', {'id': helperId}),
            sort: '-created',
          );
      return [for (final r in records) HhReactie.vanRecord(r)];
    });
  }

  @override
  Future<Result<void>> intrekken(String reactieId) {
    return _gateway.voerUit((client) async {
      await client.send(intrekRoute(reactieId), method: 'POST');
    });
  }

  @override
  Future<Result<List<HhReactieKaart>>> reactiesVoorKlus(String klusId) {
    return _gateway.voerUit((client) async {
      final antwoord = _alsMap(await client.send(reactiesRoute(klusId)));
      final lijst = antwoord['reacties'];
      if (lijst is! List) return const <HhReactieKaart>[];
      return [
        for (final k in lijst)
          if (k is Map) HhReactieKaart.vanJson(_alsMap(k)),
      ];
    });
  }

  @override
  Future<KiesUitkomst> kiezen(String klusId, String reactieId) async {
    final result = await _gateway.voerUit<KiesUitkomst>((client) async {
      try {
        final antwoord = _alsMap(
          await client.send(
            kiesRoute(klusId),
            method: 'POST',
            body: {'reactie': reactieId},
          ),
        );
        return Gekozen(
          helperVoornaam: '${antwoord['helper_voornaam'] ?? ''}',
          melding: '${antwoord['melding'] ?? ''}',
        );
      } on ClientException catch (e) {
        final w = _weigering(e);
        if (w == null) rethrow;
        return KiesGeweigerd(w.$1, w.$2);
      }
    });
    return switch (result) {
      Ok<KiesUitkomst>(:final waarde) => waarde,
      Err<KiesUitkomst>(:final fout) => KiesFout(fout),
    };
  }

  @override
  Future<Result<DateTime?>> zetBeschikbaar(bool aan) {
    return _gateway.voerUit((client) async {
      final antwoord = _alsMap(
        await client.send(hhBeschikbaarPad, method: 'POST', body: {'aan': aan}),
      );
      return HhProfiel.datumVanServer('${antwoord['beschikbaar_tot'] ?? ''}');
    });
  }

  @override
  Future<Result<int>> aantalBeschikbaar({
    required String klustypeId,
    DateTime? van,
    DateTime? tot,
  }) {
    return _gateway.voerUit((client) async {
      final antwoord = _alsMap(
        await client.send(
          hhBeschikbaarPad,
          query: {
            'klustype': klustypeId,
            if (van != null) 'van': van.toUtc().toIso8601String(),
            if (tot != null) 'tot': tot.toUtc().toIso8601String(),
          },
        ),
      );
      final aantal = antwoord['aantal'];
      return aantal is num ? aantal.toInt() : 0;
    });
  }

  /// Een weigering van de hook zelf: {melding, reden}. 401, geen verbinding
  /// en fouten zonder eigen melding gaan de gewone weg (HhFout).
  static (String, String)? _weigering(ClientException e) {
    final data = _alsMap(e.response);
    final reden = '${data['reden'] ?? ''}';
    final melding = '${data['melding'] ?? ''}';
    if (reden.isEmpty || melding.isEmpty || e.statusCode == 401) return null;
    return (reden, melding);
  }

  static Map<String, dynamic> _alsMap(Object? waarde) {
    if (waarde is Map<String, dynamic>) return waarde;
    if (waarde is Map) return waarde.map((k, v) => MapEntry('$k', v));
    return const {};
  }
}
