import 'package:flutter/foundation.dart';

import '../model/hh_koppeling.dart';

/// Wat het familielid bij één oudere mag zien en doen. De server dwingt het
/// af (rules, script 41); de app verbergt alleen wat toch niet zou lukken.
@immutable
class FamilieZicht {
  const FamilieZicht({required this.kanMeekijken, required this.kanPlaatsen});

  /// F3: de hulpvragen van de oudere en hun status.
  final bool kanMeekijken;

  /// F2: hulp vragen namens de oudere.
  final bool kanPlaatsen;
}

FamilieZicht zichtVoor(HhKoppeling koppeling) => FamilieZicht(
  kanMeekijken:
      koppeling.isActief && koppeling.rechten.contains(FamilieRecht.meekijken),
  kanPlaatsen:
      koppeling.isActief && koppeling.rechten.contains(FamilieRecht.plaatsen),
);

/// F1: gekoppelde ouderen (actief) en lopende aanvragen apart.
({List<HhKoppeling> actief, List<HhKoppeling> aangevraagd}) deelKoppelingenIn(
  List<HhKoppeling> koppelingen,
) => (
  actief: [
    for (final k in koppelingen)
      if (k.isActief) k,
  ],
  aangevraagd: [
    for (final k in koppelingen)
      if (!k.isActief) k,
  ],
);

/// "Een oudere -> meteen door naar F3": het id van die ene oudere, of null.
String? meteenDoorNaar(List<HhKoppeling> koppelingen) {
  final actief = deelKoppelingenIn(koppelingen).actief;
  return actief.length == 1 ? actief.single.oudereId : null;
}
