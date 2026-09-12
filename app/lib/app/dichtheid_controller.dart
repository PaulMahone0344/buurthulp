import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/toegang/provider/sessie_providers.dart';
import '../theme.dart';

/// De dichtheid volgt de rol (app OPEN-PUNT 10, opgelost in M2):
/// ingelogd als hulpvrager = groot, elke andere rol normaal. Voor het
/// inloggen geldt de rol die op G2 is gekozen: groot zodra "Ik zoek hulp"
/// is gekozen, anders normaal. Niemand zet de dichtheid nog met de hand;
/// een instelbare maat (G9) komt later.
final dichtheidProvider = Provider<HhDichtheid>((ref) {
  final gebruiker = ref.watch(huidigeGebruikerProvider);
  if (gebruiker != null) return gebruiker.rol.dichtheid;
  final gekozen = ref.watch(gekozenRolProvider);
  return gekozen?.dichtheid ?? HhDichtheid.normaal;
});
