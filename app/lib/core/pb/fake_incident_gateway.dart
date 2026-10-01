import '../hh_fout.dart';
import '../result.dart';
import 'incident_gateway.dart';

/// Eén gemeld incident zoals de fake het bewaart.
typedef GemeldIncident = ({
  String id,
  String melderId,
  IncidentSoort soort,
  String klusId,
  String omschrijving,
});

/// Fake voor tests: bewaart wat er gemeld is. Stuurbaar met [isOffline] en
/// [volgendeFout].
class FakeIncidentGateway implements IncidentGateway {
  final List<GemeldIncident> gemeld = [];
  bool isOffline = false;
  HhFout? volgendeFout;

  @override
  Future<Result<String>> meld({
    required String melderId,
    required IncidentSoort soort,
    String klusId = '',
    String omschrijving = '',
  }) async {
    if (isOffline) {
      return Result.err(const HhFout(HhFoutSoort.geenVerbinding));
    }
    final fout = volgendeFout;
    volgendeFout = null;
    if (fout != null) return Result.err(fout);
    final id = 'i${gemeld.length + 1}';
    gemeld.add((
      id: id,
      melderId: melderId,
      soort: soort,
      klusId: klusId,
      omschrijving: omschrijving.trim(),
    ));
    return Result.ok(id);
  }
}
