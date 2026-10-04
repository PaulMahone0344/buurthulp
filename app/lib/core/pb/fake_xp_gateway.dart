import '../../features/jongere/xp/model/hh_xp.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'xp_gateway.dart';

/// Fake voor tests: nooit een verzoek naar de server. Geeft [overzicht] en
/// [verklaring] terug; [isOffline] en [volgendeFout] laten het mislukken.
class FakeXpGateway implements XpGateway {
  FakeXpGateway({HhXpOverzicht? overzicht, HhVerklaring? verklaring})
    : overzicht = overzicht ?? const HhXpOverzicht(),
      verklaring =
          verklaring ??
          const HhVerklaring(code: 'ABCDE-FGH23', voornaam: 'Daan');

  HhXpOverzicht overzicht;
  HhVerklaring verklaring;
  bool isOffline = false;
  HhFout? volgendeFout;
  int overzichtGeladen = 0;
  int verklaringenGemaakt = 0;

  HhFout? _neemFout() {
    if (isOffline) return const HhFout(HhFoutSoort.geenVerbinding);
    final fout = volgendeFout;
    volgendeFout = null;
    return fout;
  }

  @override
  Future<Result<HhXpOverzicht>> mijnOverzicht() async {
    overzichtGeladen++;
    final fout = _neemFout();
    if (fout != null) return Err(fout);
    return Ok(overzicht);
  }

  @override
  Future<Result<HhVerklaring>> maakVerklaring() async {
    final fout = _neemFout();
    if (fout != null) return Err(fout);
    verklaringenGemaakt++;
    return Ok(verklaring);
  }
}
