import '../../features/familie/model/hh_koppeling.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'familie_gateway.dart';

/// Het vaste bericht van de hook (hh_familie_hulp.js), letterlijk.
const fakeVastBericht =
    'Als dit adres bij ons bekend is, krijgt je familielid een vraag om toestemming.';

/// Fake voor tests: nooit een verzoek naar de server. Speelt de hook en de
/// rules na: een aanvraag voor een bekend adres maakt een koppeling
/// "aangevraagd" (voor [ikBenId]), het antwoord is altijd het vaste
/// bericht, hooguit [maxPerDag] aanvragen. Stuurbaar met [isOffline] en
/// [volgendeFout].
class FakeFamilieGateway implements FamilieGateway {
  FakeFamilieGateway({
    List<HhKoppeling> koppelingen = const [],
    Map<String, ({String id, String naam})> ouderenOpEmail = const {},
    this.ikBenId = 'id-familie',
    this.ikBenNaam = 'Karin de Vries',
  }) : _koppelingen = [...koppelingen],
       _ouderen = {...ouderenOpEmail};

  final List<HhKoppeling> _koppelingen;
  final Map<String, ({String id, String naam})> _ouderen;

  String ikBenId;
  String ikBenNaam;
  static const maxPerDag = 5;

  bool isOffline = false;
  HhFout? volgendeFout;
  final List<String> aangevraagd = [];

  List<HhKoppeling> get alleKoppelingen => List.unmodifiable(_koppelingen);

  HhFout? _neemFout() {
    if (isOffline) return const HhFout(HhFoutSoort.geenVerbinding);
    final fout = volgendeFout;
    volgendeFout = null;
    return fout;
  }

  var _volgnummer = 0;

  @override
  Future<AanvraagUitkomst> aanvragen(String emailOudere) async {
    final fout = _neemFout();
    if (fout != null) return AanvraagFout(fout);
    final email = emailOudere.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return const AanvraagGeweigerd(AanvraagReden.email);
    }
    if (aangevraagd.length >= maxPerDag) {
      return const AanvraagGeweigerd(AanvraagReden.limiet);
    }
    aangevraagd.add(email);
    final oudere = _ouderen[email];
    if (oudere != null &&
        !_koppelingen.any(
          (k) => k.oudereId == oudere.id && k.familielidId == ikBenId,
        )) {
      _volgnummer++;
      _koppelingen.add(
        HhKoppeling(
          id: 'kp-$_volgnummer',
          oudereId: oudere.id,
          familielidId: ikBenId,
          status: KoppelingStatus.aangevraagd,
          // Bij een aanvraag geeft de server de oudere nog niet prijs.
          familielidNaam: ikBenNaam,
        ),
      );
    }
    return const AanvraagVerstuurd(fakeVastBericht);
  }

  /// De rules: het familielid ziet de naam van de oudere pas bij actief.
  @override
  Future<Result<List<HhKoppeling>>> vanFamilielid(String familielidId) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    return Result.ok([
      for (final k in _koppelingen)
        if (k.familielidId == familielidId)
          k.isActief
              ? k
              : HhKoppeling(
                  id: k.id,
                  oudereId: k.oudereId,
                  familielidId: k.familielidId,
                  status: k.status,
                  rechten: k.rechten,
                  familielidNaam: k.familielidNaam,
                ),
    ]);
  }

  @override
  Future<Result<List<HhKoppeling>>> vanOudere(String oudereId) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    return Result.ok([
      for (final k in _koppelingen)
        if (k.oudereId == oudereId) k,
    ]);
  }

  @override
  Future<Result<HhKoppeling>> geefToestemming(String koppelingId) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final index = _koppelingen.indexWhere((k) => k.id == koppelingId);
    if (index == -1) return Result.err(const HhFout(HhFoutSoort.nietGevonden));
    final nieuw = _koppelingen[index].metActief();
    _koppelingen[index] = nieuw;
    return Result.ok(nieuw);
  }

  @override
  Future<Result<void>> verwijder(String koppelingId) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final voor = _koppelingen.length;
    _koppelingen.removeWhere((k) => k.id == koppelingId);
    if (_koppelingen.length == voor) {
      return Result.err(const HhFout(HhFoutSoort.nietGevonden));
    }
    return Result.ok(null);
  }
}
