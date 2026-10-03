import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/pb/gateway_providers.dart';
import '../theme.dart';

const _groteLettersSleutel = 'hh_grote_letters';

/// De schakelaar "Grotere letters" in Instellingen (3 okt, G9). Geen
/// verschil meer per rol: iedereen begint normaal en kiest zelf. Lokaal
/// bewaard, zoals de meldingen-schakelaar.
class GroteLettersController extends Notifier<bool> {
  @override
  bool build() {
    unawaited(_laad());
    return false;
  }

  Future<void> _laad() async {
    final bewaard = await ref
        .read(keyValueStoreProvider)
        .lees(_groteLettersSleutel);
    if (bewaard != null) state = bewaard == 'true';
  }

  Future<void> zet(bool aan) async {
    state = aan;
    await ref.read(keyValueStoreProvider).schrijf(_groteLettersSleutel, '$aan');
  }
}

final groteLettersProvider = NotifierProvider<GroteLettersController, bool>(
  GroteLettersController.new,
);

/// De dichtheid van de hele app: groot als "Grotere letters" aan staat.
final dichtheidProvider = Provider<HhDichtheid>(
  (ref) =>
      ref.watch(groteLettersProvider) ? HhDichtheid.groot : HhDichtheid.normaal,
);
