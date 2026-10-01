import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/pb/gateway_providers.dart';
import '../../../../core/pb/incident_gateway.dart';
import '../../../../core/result.dart';
import '../../../jongere/uitvoeren/domein/klus_overgang.dart';
import '../../../jongere/uitvoeren/provider/uitvoeren_providers.dart';
import '../../../toegang/model/hh_rol.dart';
import '../../../toegang/provider/sessie_providers.dart';
import '../../../toegang/screen/hulp_screen.dart' show urlOpenerProvider;
import '../meldkamer_config.dart';

/// De echte incident-gateway; tests overriden hem met een
/// [FakeIncidentGateway].
final incidentGatewayProvider = Provider<IncidentGateway>(
  (ref) => PocketBaseIncidentGateway(ref.watch(pocketBaseGatewayProvider)),
);

/// De klus die bij de oudere nu loopt (aangenomen, onderweg of bezig), voor
/// "met de lopende klus erbij". Leeg als er geen is, als het laden mislukt
/// of voor een andere rol (de jongere geeft de klus mee vanaf J15).
final lopendeKlusProvider = FutureProvider.autoDispose<String>((ref) async {
  final gebruiker = ref.watch(huidigeGebruikerProvider);
  if (gebruiker == null || gebruiker.rol != HhRol.hulpvrager) return '';
  final result = await ref
      .read(uitvoerGatewayProvider)
      .hulpvragen(gebruiker.id);
  if (result case Ok(:final waarde)) {
    for (final klus in waarde) {
      if (isInUitvoering(klus.status)) return klus.id;
    }
  }
  return '';
});

/// Belt de meldkamer (tel:). Geeft false als het toestel niet kan bellen;
/// dan toont het scherm het nummer.
final belMeldkamerProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    final uri = Uri(scheme: 'tel', path: MeldkamerConfig.telefoon);
    try {
      return await ref.read(urlOpenerProvider)(uri);
    } on Exception {
      return false;
    }
  };
});
