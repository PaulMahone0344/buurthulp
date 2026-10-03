import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../features/chat/model/hh_bericht.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'pocketbase_gateway.dart';

/// Wat er van een verstuurd bericht terugkomt.
@immutable
sealed class VerstuurUitkomst {
  const VerstuurUitkomst();
}

/// Opgeslagen. [bericht] is wat de server bewaarde (na het filter).
final class Verstuurd extends VerstuurUitkomst {
  const Verstuurd(this.bericht);
  final HhBericht bericht;
}

/// De server weigerde: de chat is dicht (403 van de hook) of ik hoor niet
/// (meer) bij deze chat (400 van de rule). Het scherm haalt de klus opnieuw
/// op en toont dan "Deze chat is gesloten."
final class VerstuurGeweigerd extends VerstuurUitkomst {
  const VerstuurGeweigerd();
}

/// Geen verbinding, sessie verlopen of een andere fout.
final class VerstuurFout extends VerstuurUitkomst {
  const VerstuurFout(this.fout);
  final HhFout fout;
}

/// De chat per klus (B6, collectie hh_berichten). De server bepaalt wie
/// leest en schrijft (rule 111) en filtert (hook hh_chat.pb.js); de app
/// leest, volgt live, verstuurt en zet gelezen_op.
abstract interface class ChatGateway {
  /// Het gesprek bij [klusId] met helper [helperId], oudste eerst.
  Future<Result<List<HhBericht>>> berichten(
    String klusId, {
    required String helperId,
  });

  Future<VerstuurUitkomst> verstuur({
    required String klusId,
    required String afzenderId,
    required String tekst,
    HhBerichtSoort soort,
  });

  /// Zet gelezen_op (alleen dat veld; alleen de ontvanger mag het).
  Future<Result<HhBericht>> markeerGelezen(String berichtId, DateTime moment);

  /// Nieuwe en gewijzigde berichten bij [klusId] (realtime). Valt de
  /// verbinding weg, dan stopt de stroom; het scherm ververst bij
  /// terugkomen in de app.
  Stream<HhBericht> volg(String klusId);

  /// Ongelezen berichten van de ander, per klus, in het HUIDIGE gesprek
  /// (helper = de toegewezen helper). Voor de teller op de Chat-knop.
  Future<Result<Map<String, int>>> ongelezenPerKlus(String ikId);

  /// Elke wijziging in een bericht dat ik mag zien (voor de teller).
  Stream<void> volgAlle();
}

class PocketBaseChatGateway implements ChatGateway {
  const PocketBaseChatGateway(this._gateway);

  final PocketBaseGateway _gateway;

  static const _maxPerGesprek = 500;

  @override
  Future<Result<List<HhBericht>>> berichten(
    String klusId, {
    required String helperId,
  }) {
    return _gateway.voerUit((client) async {
      final pagina = await client
          .collection(HhBericht.collectie)
          .getList(
            perPage: _maxPerGesprek,
            skipTotal: true,
            filter: client.filter('klus = {:klus} && helper = {:helper}', {
              'klus': klusId,
              'helper': helperId,
            }),
            sort: 'created,id',
          );
      return [for (final r in pagina.items) HhBericht.vanRecord(r)];
    });
  }

  @override
  Future<VerstuurUitkomst> verstuur({
    required String klusId,
    required String afzenderId,
    required String tekst,
    HhBerichtSoort soort = HhBerichtSoort.tekst,
  }) async {
    final result = await _gateway.voerUit((client) async {
      final record = await client
          .collection(HhBericht.collectie)
          .create(
            body: {
              'klus': klusId,
              'afzender': afzenderId,
              'tekst': tekst,
              'soort': soort.code,
            },
          );
      return HhBericht.vanRecord(record);
    });
    return switch (result) {
      Ok<HhBericht>(:final waarde) => Verstuurd(waarde),
      Err<HhBericht>(:final fout)
          when fout.soort == HhFoutSoort.geenToegang ||
              fout.soort == HhFoutSoort.ongeldigeInvoer =>
        const VerstuurGeweigerd(),
      Err<HhBericht>(:final fout) => VerstuurFout(fout),
    };
  }

  @override
  Future<Result<HhBericht>> markeerGelezen(String berichtId, DateTime moment) {
    return _gateway.voerUit((client) async {
      final record = await client
          .collection(HhBericht.collectie)
          .update(
            berichtId,
            body: {HhBericht.veldGelezenOp: moment.toUtc().toIso8601String()},
          );
      return HhBericht.vanRecord(record);
    });
  }

  @override
  Future<Result<Map<String, int>>> ongelezenPerKlus(String ikId) {
    return _gateway.voerUit((client) async {
      final rijen = await client
          .collection(HhBericht.collectie)
          .getFullList(
            batch: 200,
            fields: 'id,klus',
            filter: client.filter(
              'afzender != {:ik} && gelezen_op = "" && '
              'helper = klus.toegewezen_jongere',
              {'ik': ikId},
            ),
          );
      final telling = <String, int>{};
      for (final r in rijen) {
        final klus = r.getStringValue('klus');
        telling[klus] = (telling[klus] ?? 0) + 1;
      }
      return Map.unmodifiable(telling);
    });
  }

  @override
  Stream<HhBericht> volg(String klusId) => _abonnement(
    filter: (client) => client.filter('klus = {:klus}', {'klus': klusId}),
    omzetten: HhBericht.vanRecord,
  );

  @override
  Stream<void> volgAlle() => _abonnement<void>(omzetten: (_) {});

  /// Eén realtime-abonnement op hh_berichten als stroom. Afmelden zodra de
  /// luisteraar stopt; mislukt aanmelden, dan sluit de stroom.
  Stream<T> _abonnement<T>({
    String? Function(PocketBase client)? filter,
    required T Function(RecordModel record) omzetten,
  }) {
    late final StreamController<T> stroom;
    Future<void> Function()? afmelden;

    Future<void> aanmelden() async {
      final result = await _gateway.voerUit<void>((client) async {
        final stop = await client.collection(HhBericht.collectie).subscribe(
          '*',
          (gebeurtenis) {
            final record = gebeurtenis.record;
            if (record == null || stroom.isClosed) return;
            if (gebeurtenis.action == 'delete') return;
            stroom.add(omzetten(record));
          },
          filter: filter?.call(client),
        );
        afmelden = () async => stop();
      });
      if (result case Err<void>()) {
        if (!stroom.isClosed) await stroom.close();
      }
    }

    stroom = StreamController<T>(
      onListen: () => unawaited(aanmelden()),
      onCancel: () async {
        final stop = afmelden;
        afmelden = null;
        if (stop != null) await stop();
      },
    );
    return stroom.stream;
  }
}
