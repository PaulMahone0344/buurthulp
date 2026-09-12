import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pb/gateway_providers.dart';

const _meldingenSleutel = 'hh_meldingen_aan';

/// De meldingen-schakelaar uit G7. Wordt in M2 alleen bewaard (lokaal;
/// hh_users heeft er geen veld voor) en stuurt nog geen push. Standaard
/// aan, zodat een gebruiker die er nooit naar kijkt niets mist.
class MeldingenVoorkeurController extends Notifier<bool> {
  @override
  bool build() {
    unawaited(_laad());
    return true;
  }

  Future<void> _laad() async {
    final bewaard = await ref
        .read(keyValueStoreProvider)
        .lees(_meldingenSleutel);
    if (bewaard != null) state = bewaard == 'true';
  }

  Future<void> zet(bool aan) async {
    state = aan;
    await ref.read(keyValueStoreProvider).schrijf(_meldingenSleutel, '$aan');
  }
}

final meldingenVoorkeurProvider =
    NotifierProvider<MeldingenVoorkeurController, bool>(
      MeldingenVoorkeurController.new,
    );
