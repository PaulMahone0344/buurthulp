import 'dart:async';

import '../../features/meldingen/model/hh_melding.dart';
import '../result.dart';
import 'pocketbase_gateway.dart';

/// Meldingen in de app (M8, laag 1). De server maakt ze (hook
/// hh_meldingen.pb.js); de app leest, volgt ze live en zet gelezen_op. Meer
/// mag de ontvanger niet (rule 31 en de hook).
abstract interface class MeldingenGateway {
  /// De meldingen van [ontvangerId], nieuwste eerst.
  Future<Result<List<HhMelding>>> meldingen(String ontvangerId, {int limiet});

  /// Zet gelezen_op op [moment] (UTC op de server). Alleen dat veld.
  Future<Result<HhMelding>> markeerGelezen(String meldingId, DateTime moment);

  /// Volgt nieuwe en gewijzigde meldingen van [ontvangerId] (realtime).
  /// Valt de verbinding weg, dan stopt de stroom; het scherm houdt
  /// pull-to-refresh.
  Stream<HhMelding> volg(String ontvangerId);
}

class PocketBaseMeldingenGateway implements MeldingenGateway {
  const PocketBaseMeldingenGateway(this._gateway);

  final PocketBaseGateway _gateway;

  @override
  Future<Result<List<HhMelding>>> meldingen(
    String ontvangerId, {
    int limiet = 50,
  }) {
    return _gateway.voerUit((client) async {
      final pagina = await client
          .collection(HhMelding.collectie)
          .getList(
            perPage: limiet,
            skipTotal: true,
            filter: client.filter('ontvanger = {:id}', {'id': ontvangerId}),
            sort: '-created,-id',
          );
      return [for (final r in pagina.items) HhMelding.vanRecord(r)];
    });
  }

  @override
  Future<Result<HhMelding>> markeerGelezen(String meldingId, DateTime moment) {
    return _gateway.voerUit((client) async {
      final record = await client
          .collection(HhMelding.collectie)
          .update(
            meldingId,
            body: {HhMelding.veldGelezenOp: moment.toUtc().toIso8601String()},
          );
      return HhMelding.vanRecord(record);
    });
  }

  @override
  Stream<HhMelding> volg(String ontvangerId) {
    late final StreamController<HhMelding> stroom;
    Future<void> Function()? afmelden;

    Future<void> aanmelden() async {
      final result = await _gateway.voerUit<void>((client) async {
        final stop = await client.collection(HhMelding.collectie).subscribe(
          '*',
          (gebeurtenis) {
            final record = gebeurtenis.record;
            if (record == null || stroom.isClosed) return;
            if (gebeurtenis.action == 'delete') return;
            stroom.add(HhMelding.vanRecord(record));
          },
          filter: client.filter('ontvanger = {:id}', {'id': ontvangerId}),
        );
        afmelden = () async => stop();
      });
      if (result case Err<void>()) {
        if (!stroom.isClosed) await stroom.close();
      }
    }

    stroom = StreamController<HhMelding>(
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
