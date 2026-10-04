import 'dart:async';

import 'package:pocketbase/pocketbase.dart';

import '../../features/jongere/klussen/model/hh_klus.dart';
import '../../features/jongere/uitvoeren/model/hh_klus_logregel.dart';
import '../../features/jongere/xp/model/hh_xp.dart';
import '../../theme.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'pocketbase_gateway.dart';

const hhKlussenCollectieUitvoer = 'hh_klussen';

/// De drie M6-routes uit backend/pb_hooks/hh_klussen.pb.js.
String statusRoute(String klusId) => '/api/hh/klussen/$klusId/status';
String annuleerRoute(String klusId) => '/api/hh/klussen/$klusId/annuleren';
String belRoute(String klusId) => '/api/hh/klussen/$klusId/bel';

/// Waarom de server een statusstap, een annulering of een belverzoek
/// weigerde. Geen fout van de app: een gewone uitkomst met een Nederlandse
/// melding van de server.
enum UitvoerReden {
  /// 409: de stap kan nu niet meer (iemand was eerder, of de klus staat
  /// ergens anders). Bij bellen: de klus is nog niet aangenomen.
  nietMeerMogelijk,

  /// 409 bij annuleren van een klus die al bezig is: dat wordt "probleem
  /// melden" (M8).
  isBezig,

  /// 409 bij bellen: er is geen telefoonnummer bekend.
  geenNummer,

  /// 403: wel ingelogd, maar deze klus is niet van jou.
  geenToegang,

  /// 404: de klus bestaat niet (meer).
  nietGevonden,

  /// 400: de reden is te kort of te lang.
  ongeldigeReden,
}

sealed class UitvoerUitkomst {
  const UitvoerUitkomst();
}

/// De stap of annulering is gezet; [status] is de nieuwe status.
final class UitvoerGelukt extends UitvoerUitkomst {
  const UitvoerGelukt(this.status, {this.beloning});

  final HhKlusStatus status;

  /// B9: na "afgerond" stuurt de server de beloning mee (+XP, niveau,
  /// nieuwe badges) voor HBeloning. Anders null.
  final HhBeloning? beloning;
}

final class UitvoerGeweigerd extends UitvoerUitkomst {
  const UitvoerGeweigerd(this.reden, {this.melding});

  final UitvoerReden reden;

  /// De melding van de server, als die er was.
  final String? melding;
}

final class UitvoerFout extends UitvoerUitkomst {
  const UitvoerFout(this.fout);

  final HhFout fout;
}

/// Het antwoord van de belroute: het nummer waar de kiezer heen gaat en de
/// naam die de app in de bevestigregel zet. Het nummer wordt nooit als tekst
/// getoond (M6, keuze 4).
sealed class BelUitkomst {
  const BelUitkomst();
}

final class BelNummer extends BelUitkomst {
  const BelNummer({required this.nummer, required this.naam});

  final String nummer;
  final String naam;
}

final class BelGeweigerd extends BelUitkomst {
  const BelGeweigerd(this.reden, {this.melding});

  final UitvoerReden reden;
  final String? melding;
}

final class BelFout extends BelUitkomst {
  const BelFout(this.fout);

  final HhFout fout;
}

/// Alles wat J15, J16, O7 en O8 van de server nodig hebben.
abstract interface class UitvoerGateway {
  /// POST /api/hh/klussen/{id}/status — één stap vooruit.
  Future<UitvoerUitkomst> zetStatus(String klusId, HhKlusStatus naar);

  /// POST /api/hh/klussen/{id}/annuleren — reden verplicht.
  Future<UitvoerUitkomst> annuleer(String klusId, String reden);

  /// GET /api/hh/klussen/{id}/bel.
  Future<BelUitkomst> belNummer(String klusId);

  /// De logregels van één klus, oudste eerst.
  Future<Result<List<HhKlusLogregel>>> logregels(String klusId);

  /// Eén klus, met de jongere erbij (O7).
  Future<Result<HhKlus>> klus(String klusId);

  /// De hulpvragen van [hulpvragerId], laatste eerst (O8).
  Future<Result<List<HhKlus>>> hulpvragen(String hulpvragerId);

  /// Volgt één klus live (PocketBase realtime). Elke wijziging levert de
  /// bijgewerkte klus op. Valt de verbinding weg, dan stopt de stroom; de
  /// schermen houden hun knop "Vernieuwen" en pull-to-refresh.
  Stream<HhKlus> volgKlus(String klusId);
}

class PocketBaseUitvoerGateway implements UitvoerGateway {
  const PocketBaseUitvoerGateway(this._gateway);

  final PocketBaseGateway _gateway;

  static const _miniatuur = '200x200';

  HhKlus _klusVan(PocketBase client, RecordModel record) => HhKlus.vanRecord(
    record,
    fotoUrl: (persoon, bestand) =>
        client.files.getURL(persoon, bestand, thumb: _miniatuur).toString(),
  );

  @override
  Future<UitvoerUitkomst> zetStatus(String klusId, HhKlusStatus naar) {
    return _stuur(
      statusRoute(klusId),
      body: {'naar': naar.name},
      standaard: naar,
    );
  }

  @override
  Future<UitvoerUitkomst> annuleer(String klusId, String reden) {
    return _stuur(
      annuleerRoute(klusId),
      body: {'reden': reden},
      standaard: HhKlusStatus.geannuleerd,
    );
  }

  /// Beide routes antwoorden hetzelfde: 200 {klus, status} of een
  /// weigering met {melding, reden}.
  Future<UitvoerUitkomst> _stuur(
    String pad, {
    required Map<String, dynamic> body,
    required HhKlusStatus standaard,
  }) async {
    final result = await _gateway.voerUit<UitvoerUitkomst>((client) async {
      try {
        final antwoord = await client.send(pad, method: 'POST', body: body);
        return UitvoerGelukt(
          _statusUit(antwoord) ?? standaard,
          beloning: HhBeloning.vanJson(_alsMap(antwoord)['beloning']),
        );
      } on ClientException catch (e) {
        final uitkomst = _weigeringUit(e);
        if (uitkomst == null) rethrow;
        return uitkomst;
      }
    });
    return switch (result) {
      Ok<UitvoerUitkomst>(:final waarde) => waarde,
      Err<UitvoerUitkomst>(:final fout) => UitvoerFout(fout),
    };
  }

  @override
  Future<BelUitkomst> belNummer(String klusId) async {
    final result = await _gateway.voerUit<BelUitkomst>((client) async {
      try {
        final antwoord = await client.send(belRoute(klusId), method: 'GET');
        final kaart = _alsMap(antwoord);
        final nummer = '${kaart['nummer'] ?? ''}'.trim();
        if (nummer.isEmpty) {
          return const BelGeweigerd(UitvoerReden.geenNummer);
        }
        return BelNummer(nummer: nummer, naam: '${kaart['naam'] ?? ''}'.trim());
      } on ClientException catch (e) {
        final uitkomst = _weigeringUit(e);
        if (uitkomst is! UitvoerGeweigerd) rethrow;
        return BelGeweigerd(uitkomst.reden, melding: uitkomst.melding);
      }
    });
    return switch (result) {
      Ok<BelUitkomst>(:final waarde) => waarde,
      Err<BelUitkomst>(:final fout) => BelFout(fout),
    };
  }

  @override
  Future<Result<List<HhKlusLogregel>>> logregels(String klusId) {
    return _gateway.voerUit((client) async {
      final records = await client
          .collection(HhKlusLogregel.collectie)
          .getFullList(
            filter: client.filter('klus = {:id}', {'id': klusId}),
            sort: HhKlusLogregel.sort,
          );
      return [for (final r in records) HhKlusLogregel.vanRecord(r)];
    });
  }

  @override
  Future<Result<HhKlus>> klus(String klusId) {
    return _gateway.voerUit((client) async {
      final record = await client
          .collection(hhKlussenCollectieUitvoer)
          .getOne(klusId, expand: HhKlus.expandMetJongere);
      return _klusVan(client, record);
    });
  }

  @override
  Future<Result<List<HhKlus>>> hulpvragen(String hulpvragerId) {
    return _gateway.voerUit((client) async {
      final records = await client
          .collection(hhKlussenCollectieUitvoer)
          .getFullList(
            filter: client.filter('hulpvrager = {:id}', {'id': hulpvragerId}),
            sort: '-wanneer_van,-created',
            expand: HhKlus.expandMetJongere,
          );
      return [for (final r in records) _klusVan(client, r)];
    });
  }

  @override
  Stream<HhKlus> volgKlus(String klusId) {
    late final StreamController<HhKlus> stroom;
    Future<void> Function()? afmelden;

    Future<void> aanmelden() async {
      final result = await _gateway.voerUit<void>((client) async {
        final stop = await client
            .collection(hhKlussenCollectieUitvoer)
            .subscribe(klusId, (gebeurtenis) {
              final record = gebeurtenis.record;
              if (record == null || stroom.isClosed) return;
              stroom.add(_klusVan(client, record));
            }, expand: HhKlus.expandMetJongere);
        afmelden = () async => stop();
      });
      // Geen verbinding of geen toegang: de stroom stopt netjes. De
      // schermen blijven werken met "Vernieuwen" en pull-to-refresh.
      if (result case Err<void>()) {
        if (!stroom.isClosed) await stroom.close();
      }
    }

    stroom = StreamController<HhKlus>(
      onListen: () => unawaited(aanmelden()),
      onCancel: () async {
        final stop = afmelden;
        afmelden = null;
        if (stop != null) await stop();
      },
    );
    return stroom.stream;
  }

  static HhKlusStatus? _statusUit(Object? antwoord) {
    final code = '${_alsMap(antwoord)['status'] ?? ''}';
    if (code.isEmpty) return null;
    for (final status in HhKlusStatus.values) {
      if (status.name == code) return status;
    }
    return null;
  }

  /// De hook antwoordt {melding, reden}; PocketBase zelf {message}.
  static UitvoerUitkomst? _weigeringUit(ClientException e) {
    final antwoord = _alsMap(e.response);
    final melding = antwoord['melding'];
    final serverMelding = melding is String && melding.trim().isNotEmpty
        ? melding
        : null;
    final reden = '${antwoord['reden'] ?? ''}';
    final soort = switch (e.statusCode) {
      400 => UitvoerReden.ongeldigeReden,
      403 => UitvoerReden.geenToegang,
      404 => UitvoerReden.nietGevonden,
      409 => switch (reden) {
        'bezig' => UitvoerReden.isBezig,
        'geennummer' => UitvoerReden.geenNummer,
        _ => UitvoerReden.nietMeerMogelijk,
      },
      _ => null,
    };
    if (soort == null) return null;
    return UitvoerGeweigerd(soort, melding: serverMelding);
  }

  static Map<String, dynamic> _alsMap(Object? antwoord) {
    if (antwoord is Map<String, dynamic>) return antwoord;
    if (antwoord is Map) return antwoord.map((k, v) => MapEntry('$k', v));
    return const {};
  }
}
