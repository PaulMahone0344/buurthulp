import '../../features/hulpvrager/model/hh_gegevens.dart';
import '../../features/hulpvrager/model/hh_klustype.dart';
import '../../features/hulpvrager/model/nieuwe_klus.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'klus_gateway.dart';

/// Een geschreven logregel in de fake.
class FakeLogregel {
  const FakeLogregel({
    required this.klusId,
    required this.doorId,
    required this.van,
    required this.naar,
  });

  final String klusId;
  final String doorId;
  final String van;
  final String naar;
}

/// Fake voor tests: nooit een verzoek naar de server. Stuurbaar met
/// [isOffline] (alles mislukt met geenVerbinding), [volgendeFout] (de
/// eerstvolgende aanroep mislukt) en [logMislukt] (alleen het statusloggen
/// mislukt, zoals wanneer de rule dat weigert).
class FakeKlusGateway implements KlusGateway {
  FakeKlusGateway({
    List<HhKlustype> klustypes = const [],
    Map<String, HhGegevens> gegevens = const {},
  }) : _klustypes = List.unmodifiable(klustypes),
       _gegevens = Map.of(gegevens);

  final List<HhKlustype> _klustypes;
  final Map<String, HhGegevens> _gegevens;

  bool isOffline = false;
  bool logMislukt = false;
  HhFout? volgendeFout;

  /// Elke aangemaakte klus, in volgorde.
  final List<NieuweKlus> aangemaakteKlussen = [];
  final List<FakeLogregel> logregels = [];

  /// Wat de laatste bijwerking meestuurde (alleen gewijzigde velden).
  Map<String, dynamic>? laatsteGegevensBody;

  int aantalKlustypeAanvragen = 0;
  int aantalGegevensAanvragen = 0;

  HhGegevens? gegevensVan(String id) => _gegevens[id];

  HhFout? _neemFout() {
    if (isOffline) return const HhFout(HhFoutSoort.geenVerbinding);
    final fout = volgendeFout;
    volgendeFout = null;
    return fout;
  }

  @override
  Future<Result<List<HhKlustype>>> klustypes() async {
    aantalKlustypeAanvragen++;
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final gesorteerd = [..._klustypes]
      ..sort((a, b) => a.naam.compareTo(b.naam));
    return Result.ok(gesorteerd);
  }

  @override
  Future<Result<HhGegevens>> mijnGegevens(String gebruikerId) async {
    aantalGegevensAanvragen++;
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final gegevens = _gegevens[gebruikerId];
    if (gegevens == null) {
      return Result.err(const HhFout(HhFoutSoort.nietGevonden));
    }
    return Result.ok(gegevens);
  }

  @override
  Future<Result<HhGegevens>> gegevensBijwerken(
    String gebruikerId,
    Map<String, dynamic> velden,
  ) async {
    laatsteGegevensBody = Map.unmodifiable(velden);
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final huidig = _gegevens[gebruikerId];
    if (huidig == null) {
      return Result.err(const HhFout(HhFoutSoort.nietGevonden));
    }
    final nieuw = huidig.metVelden(velden);
    _gegevens[gebruikerId] = nieuw;
    return Result.ok(nieuw);
  }

  @override
  Future<Result<String>> klusAanmaken(NieuweKlus klus) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    aangemaakteKlussen.add(klus);
    return Result.ok('fake-klus-${aangemaakteKlussen.length}');
  }

  @override
  Future<Result<void>> statusLoggen({
    required String klusId,
    required String doorId,
    required String van,
    required String naar,
  }) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    if (logMislukt) return Result.err(const HhFout(HhFoutSoort.geenToegang));
    logregels.add(
      FakeLogregel(klusId: klusId, doorId: doorId, van: van, naar: naar),
    );
    return Result.ok(null);
  }
}
