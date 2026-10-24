import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/paden.dart';
import '../../../core/pb/gateway_providers.dart';
import '../model/sessie_state.dart';
import '../provider/sessie_providers.dart';

const _gezienSleutel = 'hh_kennismaking_gezien';

/// Of deze telefoon de kennismaking al heeft gezien. Null zolang het nog
/// uit de opslag komt. Lokaal bewaard, zoals "Grotere letters". Wie
/// inlogt heeft hem daarna ook "gezien": na uitloggen komt hij niet terug.
class KennismakingController extends Notifier<bool?> {
  @override
  bool? build() {
    ref.listen(sessieControllerProvider, (_, sessie) {
      if (sessie is SessieIngelogd && state != true) unawaited(markeer());
    });
    unawaited(_laad());
    return null;
  }

  Future<void> _laad() async {
    final bewaard = await ref.read(keyValueStoreProvider).lees(_gezienSleutel);
    // Kan intussen al op true staan (markeer was sneller).
    if (state == null) state = bewaard == 'true';
  }

  Future<void> markeer() async {
    state = true;
    await ref.read(keyValueStoreProvider).schrijf(_gezienSleutel, 'true');
  }
}

final kennismakingGezienProvider =
    NotifierProvider<KennismakingController, bool?>(KennismakingController.new);

/// De kennismaking komt vóór het welkomscherm, alleen voor wie uitgelogd
/// is en hem nog niet zag. Weten we dat nog niet ([gezien] null), dan
/// blijft de splash staan (expliciet de splash teruggeven: null zou de
/// volgende guard naar G2 laten sturen); zo flitst G2 niet even voorbij.
String? kennismakingRedirect(SessieState sessie, bool? gezien, String locatie) {
  if (sessie is! SessieUitgelogd) return null;
  return switch (locatie) {
    HhPaden.splash when gezien == null => HhPaden.splash,
    HhPaden.welkom when gezien == false => HhPaden.kennismaken,
    HhPaden.kennismaken when gezien == true => HhPaden.welkom,
    _ => null,
  };
}
