import 'package:pocketbase/pocketbase.dart';

import '../../features/jongere/reputatie/model/hh_beoordeling.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'auth_gateway.dart' show hhUsersCollectie;
import 'pocketbase_gateway.dart';

/// Waarom de server een beoordeling weigerde. Geen fout van de app: een
/// gewone uitkomst die het scherm in gewone taal uitlegt.
enum BeoordelingReden {
  /// 400 van de unieke index klus + van_gebruiker: deze kant heeft deze klus
  /// al beoordeeld ("U heeft al een beoordeling gegeven.").
  alGegeven,

  /// 400/403 van de createRule: de klus is nog niet afgerond, of je bent geen
  /// deelnemer, of naar_gebruiker is niet de andere deelnemer.
  nietToegestaan,

  /// 404: de beoordeling bestaat niet (meer) of is niet van jou.
  nietGevonden,
}

sealed class BeoordelingUitkomst {
  const BeoordelingUitkomst();
}

final class BeoordelingOpgeslagen extends BeoordelingUitkomst {
  const BeoordelingOpgeslagen(this.beoordeling);

  final HhBeoordeling beoordeling;
}

final class BeoordelingGeweigerd extends BeoordelingUitkomst {
  const BeoordelingGeweigerd(this.reden);

  final BeoordelingReden reden;
}

final class BeoordelingFout extends BeoordelingUitkomst {
  const BeoordelingFout(this.fout);

  final HhFout fout;
}

/// Alles wat J17, J19 en O9 van de server nodig hebben (M7). Maken en
/// wijzigen gaat via de gewone API: de rules van hh_beoordelingen dekken het.
/// De reputatie rekent de server uit (hook); de app leest hem alleen.
abstract interface class BeoordelingGateway {
  /// Nieuwe beoordeling. [vanId] moet de ingelogde gebruiker zijn; de rule
  /// eist dat expliciet.
  /// B5: [allesInOrde] is het antwoord op de geheime vraag ("Was alles in
  /// orde?" / "Voelde je je veilig?"); null = niet beantwoord. Alleen de
  /// meldkamer ziet het; "nee" maakt op de server een melding.
  Future<BeoordelingUitkomst> geef({
    required String klusId,
    required String vanId,
    required String naarId,
    required int sterren,
    String tekst = '',
    bool? allesInOrde,
    String geheimToelichting = '',
  });

  /// Eigen beoordeling aanpassen: alleen sterren en tekst (de updateRule
  /// verbiedt klus, van_ en naar_gebruiker), en (B5) eventueel de geheime
  /// vraag.
  Future<BeoordelingUitkomst> wijzig(
    String beoordelingId, {
    required int sterren,
    required String tekst,
    bool? allesInOrde,
    String geheimToelichting = '',
  });

  /// Alle beoordelingen die [vanId] gaf: welke klussen nog beoordeeld
  /// moeten worden, en wat er al stond bij wijzigen.
  Future<Result<List<HhBeoordeling>>> gegevenDoor(String vanId);

  /// De laatste beoordelingen met tekst die [naarId] kreeg (J19).
  Future<Result<List<HhBeoordeling>>> ontvangen(
    String naarId, {
    int limiet = 5,
  });

  /// sterren_gemiddeld en klussen_aantal van hh_users.
  Future<Result<HhReputatie>> reputatie(String gebruikerId);
}

class PocketBaseBeoordelingGateway implements BeoordelingGateway {
  const PocketBaseBeoordelingGateway(this._gateway);

  final PocketBaseGateway _gateway;

  @override
  Future<BeoordelingUitkomst> geef({
    required String klusId,
    required String vanId,
    required String naarId,
    required int sterren,
    String tekst = '',
    bool? allesInOrde,
    String geheimToelichting = '',
  }) {
    return _schrijf(
      (client) => client
          .collection(HhBeoordeling.collectie)
          .create(
            body: {
              'klus': klusId,
              'van_gebruiker': vanId,
              'naar_gebruiker': naarId,
              'sterren': sterren,
              'tekst': tekst.trim(),
              ..._geheim(allesInOrde, geheimToelichting),
            },
          ),
    );
  }

  /// B5: de geheime vraag alleen meesturen als hij beantwoord is.
  static Map<String, dynamic> _geheim(bool? allesInOrde, String toelichting) =>
      allesInOrde == null
      ? const {}
      : {
          'alles_in_orde': allesInOrde ? 'ja' : 'nee',
          'geheim_toelichting': allesInOrde ? '' : toelichting.trim(),
        };

  @override
  Future<BeoordelingUitkomst> wijzig(
    String beoordelingId, {
    required int sterren,
    required String tekst,
    bool? allesInOrde,
    String geheimToelichting = '',
  }) {
    return _schrijf(
      (client) => client
          .collection(HhBeoordeling.collectie)
          .update(
            beoordelingId,
            body: {
              'sterren': sterren,
              'tekst': tekst.trim(),
              ..._geheim(allesInOrde, geheimToelichting),
            },
          ),
    );
  }

  Future<BeoordelingUitkomst> _schrijf(
    Future<RecordModel> Function(PocketBase client) actie,
  ) async {
    final result = await _gateway.voerUit<BeoordelingUitkomst>((client) async {
      try {
        return BeoordelingOpgeslagen(
          HhBeoordeling.vanRecord(await actie(client)),
        );
      } on ClientException catch (e) {
        final reden = _redenUit(e);
        if (reden == null) rethrow;
        return BeoordelingGeweigerd(reden);
      }
    });
    return switch (result) {
      Ok<BeoordelingUitkomst>(:final waarde) => waarde,
      Err<BeoordelingUitkomst>(:final fout) => BeoordelingFout(fout),
    };
  }

  @override
  Future<Result<List<HhBeoordeling>>> gegevenDoor(String vanId) {
    return _gateway.voerUit((client) async {
      final records = await client
          .collection(HhBeoordeling.collectie)
          .getFullList(
            filter: client.filter('van_gebruiker = {:id}', {'id': vanId}),
            sort: '-created',
          );
      return [for (final r in records) HhBeoordeling.vanRecord(r)];
    });
  }

  @override
  Future<Result<List<HhBeoordeling>>> ontvangen(
    String naarId, {
    int limiet = 5,
  }) {
    return _gateway.voerUit((client) async {
      final pagina = await client
          .collection(HhBeoordeling.collectie)
          .getList(
            perPage: limiet,
            skipTotal: true,
            filter: client.filter('naar_gebruiker = {:id} && tekst != ""', {
              'id': naarId,
            }),
            sort: '-created',
          );
      return [for (final r in pagina.items) HhBeoordeling.vanRecord(r)];
    });
  }

  @override
  Future<Result<HhReputatie>> reputatie(String gebruikerId) {
    return _gateway.voerUit((client) async {
      final record = await client
          .collection(hhUsersCollectie)
          .getOne(
            gebruikerId,
            fields: 'id,${HhReputatie.veldSterren},${HhReputatie.veldKlussen}',
          );
      return HhReputatie.vanRecord(record);
    });
  }

  /// 400 met "not_unique" in de veldfouten is de unieke index; een 400
  /// zonder veldfouten of een 403 is de createRule; 404 bij wijzigen is "niet
  /// van jou of weg". De rest (geen verbinding, 401, 5xx) blijft een HhFout.
  static BeoordelingReden? _redenUit(ClientException e) {
    return switch (e.statusCode) {
      400 when _isDubbel(e.response) => BeoordelingReden.alGegeven,
      400 || 403 => BeoordelingReden.nietToegestaan,
      404 => BeoordelingReden.nietGevonden,
      _ => null,
    };
  }

  static bool _isDubbel(Map<String, dynamic> antwoord) {
    final data = antwoord['data'];
    if (data is! Map) return false;
    for (final veld in data.values) {
      if (veld is Map && '${veld['code']}'.contains('not_unique')) return true;
    }
    return false;
  }
}
