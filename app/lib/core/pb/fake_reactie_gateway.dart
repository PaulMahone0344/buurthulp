import '../../features/reacties/model/hh_reactie.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'reactie_gateway.dart';

/// Fake voor tests: nooit een verzoek naar de server. Houdt reacties en
/// KiesHelper-kaarten bij en speelt de hook na: een helper onder 18 komt op
/// wacht_op_ouder ([helperOnder18]), nog eens reageren geeft 409, kiezen
/// lukt één keer per klus. Stuurbaar met [isOffline], [volgendeFout],
/// [reageerUitkomst] en [kiesUitkomst] (de eerstvolgende aanroep geeft
/// precies dit terug) en [aantalNu] (wat "N strijders kunnen nu" telt).
class FakeReactieGateway implements ReactieGateway {
  FakeReactieGateway({
    this.helperId = 'id-jongere',
    this.helperOnder18 = false,
    List<HhReactie> reacties = const [],
    Map<String, List<HhReactieKaart>> kaarten = const {},
    this.aantalNu = 0,
    this.beschikbaarTot,
    DateTime Function()? klok,
  }) : _reacties = [...reacties],
       _kaarten = {
         for (final e in kaarten.entries) e.key: [...e.value],
       },
       _klok = klok ?? DateTime.now;

  final List<HhReactie> _reacties;
  final Map<String, List<HhReactieKaart>> _kaarten;
  final DateTime Function() _klok;

  String helperId;
  bool helperOnder18;
  int aantalNu;
  DateTime? beschikbaarTot;

  bool isOffline = false;
  HhFout? volgendeFout;
  ReageerUitkomst? reageerUitkomst;
  KiesUitkomst? kiesUitkomst;

  /// Wat de app meestuurde (voor de tests).
  final List<({String klusId, String bericht, bool ouderGaatMee})> verstuurd =
      [];
  final List<({String klusId, String reactieId})> gekozen = [];
  final List<String> ingetrokken = [];
  final List<bool> beschikbaarGezet = [];
  final List<({String klustypeId, DateTime? van, DateTime? tot})> geteld = [];
  final Set<String> _gekozenKlussen = {};

  List<HhReactie> get alleReacties => List.unmodifiable(_reacties);

  void zetKaarten(String klusId, List<HhReactieKaart> kaarten) =>
      _kaarten[klusId] = [...kaarten];

  HhFout? _neemFout() {
    if (isOffline) return const HhFout(HhFoutSoort.geenVerbinding);
    final fout = volgendeFout;
    volgendeFout = null;
    return fout;
  }

  @override
  Future<ReageerUitkomst> reageren(
    String klusId, {
    String bericht = '',
    bool ouderGaatMee = false,
  }) async {
    final fout = _neemFout();
    if (fout != null) return ReageerFout(fout);
    verstuurd.add((
      klusId: klusId,
      bericht: bericht,
      ouderGaatMee: ouderGaatMee,
    ));
    final gezet = reageerUitkomst;
    if (gezet != null) {
      reageerUitkomst = null;
      return gezet;
    }
    final bestaand = _reacties.where(
      (r) => r.klusId == klusId && r.helperId == helperId && r.status.isActief,
    );
    if (bestaand.isNotEmpty) {
      return const ReageerGeweigerd(
        'algereageerd',
        'Je hebt al gereageerd op deze klus.',
      );
    }
    final status = helperOnder18
        ? HhReactieStatus.wachtOpOuder
        : HhReactieStatus.open;
    _reacties.insert(
      0,
      HhReactie(
        id: 'r-$klusId-${_reacties.length + 1}',
        klusId: klusId,
        helperId: helperId,
        status: status,
        bericht: bericht.trim(),
        ouderGaatMee: ouderGaatMee,
        gemaakt: _klok(),
      ),
    );
    return Gereageerd(status: status);
  }

  @override
  Future<Result<List<HhReactie>>> mijnReacties(String helperId) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    return Result.ok([
      for (final r in _reacties)
        if (r.helperId == helperId) r,
    ]);
  }

  @override
  Future<Result<void>> intrekken(String reactieId) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final i = _reacties.indexWhere((r) => r.id == reactieId);
    if (i == -1 || !_reacties[i].status.isActief) {
      return Result.err(const HhFout(HhFoutSoort.nietGevonden));
    }
    _reacties[i] = _reacties[i].metStatus(HhReactieStatus.ingetrokken);
    ingetrokken.add(reactieId);
    return Result.ok(null);
  }

  @override
  Future<Result<List<HhReactieKaart>>> reactiesVoorKlus(String klusId) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    if (_gekozenKlussen.contains(klusId)) return Result.ok(const []);
    return Result.ok(List.unmodifiable(_kaarten[klusId] ?? const []));
  }

  @override
  Future<KiesUitkomst> kiezen(String klusId, String reactieId) async {
    final fout = _neemFout();
    if (fout != null) return KiesFout(fout);
    gekozen.add((klusId: klusId, reactieId: reactieId));
    final gezet = kiesUitkomst;
    if (gezet != null) {
      kiesUitkomst = null;
      return gezet;
    }
    if (_gekozenKlussen.contains(klusId)) {
      return const KiesGeweigerd(
        'klusbezet',
        'Je hebt al een strijder gekozen voor deze klus.',
      );
    }
    final kaart = (_kaarten[klusId] ?? const <HhReactieKaart>[])
        .where((k) => k.reactieId == reactieId)
        .firstOrNull;
    if (kaart == null) {
      return const KiesGeweigerd(
        'reactieweg',
        'Deze strijder is niet meer beschikbaar. Kies iemand anders.',
      );
    }
    _gekozenKlussen.add(klusId);
    return Gekozen(
      helperVoornaam: kaart.voornaam,
      melding: 'Het is een match!',
    );
  }

  @override
  Future<Result<DateTime?>> zetBeschikbaar(bool aan) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    beschikbaarGezet.add(aan);
    beschikbaarTot = aan ? _klok().add(const Duration(hours: 3)) : null;
    return Result.ok(beschikbaarTot);
  }

  @override
  Future<Result<int>> aantalBeschikbaar({
    required String klustypeId,
    DateTime? van,
    DateTime? tot,
  }) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    geteld.add((klustypeId: klustypeId, van: van, tot: tot));
    return Result.ok(aantalNu);
  }
}
