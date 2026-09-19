import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/hh_fout.dart';
import '../../../../core/result.dart';
import '../../../jongere/klussen/model/hh_klus.dart';
import '../../../jongere/uitvoeren/provider/uitvoeren_providers.dart';
import '../../../toegang/model/hh_rol.dart';
import '../../../toegang/provider/sessie_providers.dart';

/// Alleen een ingelogde oudere heeft hulpvragen; anders leeg zonder verzoek.
String? _hulpvragerId(Ref ref) {
  final gebruiker = ref.watch(huidigeGebruikerProvider);
  if (gebruiker == null || gebruiker.rol != HhRol.hulpvrager) return null;
  return gebruiker.id;
}

/// O8: alle hulpvragen van de oudere. Een [HhFout] wordt een AsyncError;
/// het scherm toont de Nederlandse melding.
class MijnHulpvragenController extends AsyncNotifier<List<HhKlus>> {
  @override
  Future<List<HhKlus>> build() async {
    final id = _hulpvragerId(ref);
    if (id == null) return const [];
    return _laad(id);
  }

  Future<List<HhKlus>> _laad(String id) async {
    final result = await ref.read(uitvoerGatewayProvider).hulpvragen(id);
    switch (result) {
      case Ok<List<HhKlus>>(:final waarde):
        return waarde;
      case Err<List<HhKlus>>(:final fout):
        if (fout.soort == HhFoutSoort.nietIngelogd) {
          await ref.read(sessieControllerProvider.notifier).sessieVerlopen();
        }
        throw fout;
    }
  }

  /// Knop "Vernieuwen" en pull-to-refresh.
  Future<void> vernieuw() async {
    final id = _hulpvragerId(ref);
    if (id == null) return;
    state = await AsyncValue.guard(() => _laad(id));
  }
}

final mijnHulpvragenProvider =
    AsyncNotifierProvider<MijnHulpvragenController, List<HhKlus>>(
      MijnHulpvragenController.new,
    );
