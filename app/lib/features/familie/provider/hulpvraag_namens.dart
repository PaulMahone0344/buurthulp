import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../toegang/model/hh_rol.dart';
import '../../toegang/provider/sessie_providers.dart';

/// F2: de M4-stroom (O2-O6) loopt namens deze oudere. De stroom zelf wordt
/// niet gekopieerd: de plaatser, de gegevens (adres) en het einde van de
/// stroom kijken naar [actieveNamensProvider].
@immutable
class HulpvraagNamens {
  const HulpvraagNamens({
    required this.oudereId,
    required this.oudereNaam,
    required this.naPlaatsen,
  });

  final String oudereId;
  final String oudereNaam;

  /// Waar de stroom na het plaatsen heen gaat (F3 van deze oudere) in plaats
  /// van O6.
  final String naPlaatsen;
}

class HulpvraagNamensController extends Notifier<HulpvraagNamens?> {
  @override
  HulpvraagNamens? build() => null;

  void zet(HulpvraagNamens namens) => state = namens;

  void wis() => state = null;
}

final hulpvraagNamensProvider =
    NotifierProvider<HulpvraagNamensController, HulpvraagNamens?>(
      HulpvraagNamensController.new,
    );

/// Alleen voor een ingelogd familielid. Logt er daarna op hetzelfde toestel
/// een oudere in, dan plaatst die gewoon voor zichzelf.
final actieveNamensProvider = Provider<HulpvraagNamens?>((ref) {
  final gebruiker = ref.watch(huidigeGebruikerProvider);
  if (gebruiker == null || gebruiker.rol != HhRol.familie) return null;
  return ref.watch(hulpvraagNamensProvider);
});
