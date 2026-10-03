import 'dart:async';

import '../../features/chat/model/hh_bericht.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'chat_gateway.dart';

/// Fake voor tests: nooit een verzoek naar de server. [zendUit] speelt een
/// bericht na dat de ander stuurt en dat realtime binnenkomt. Stuurbaar met
/// [isOffline], [volgendeFout] en [isGesloten] (de server weigert, zoals de
/// hook na 72 uur).
class FakeChatGateway implements ChatGateway {
  FakeChatGateway({
    List<HhBericht> berichten = const [],
    this.helperVanKlus = const {},
    DateTime? klok,
  }) : _berichten = [...berichten],
       _klok = klok ?? DateTime.utc(2026, 9, 15, 8);

  final List<HhBericht> _berichten;
  final DateTime _klok;
  final Map<String, StreamController<HhBericht>> _stromen = {};
  final List<StreamController<void>> _alle = [];

  /// De huidige helper per klus, voor [ongelezenPerKlus] (zoals de filter
  /// helper = klus.toegewezen_jongere op de server).
  Map<String, String> helperVanKlus;

  bool isOffline = false;
  bool isGesloten = false;
  HhFout? volgendeFout;
  int aantalLaadacties = 0;
  int _volgnummer = 0;
  final List<({String tekst, HhBerichtSoort soort})> verstuurd = [];
  final List<String> gelezenGezet = [];

  List<HhBericht> get alleBerichten => List.unmodifiable(_berichten);

  HhFout? _neemFout() {
    if (isOffline) return const HhFout(HhFoutSoort.geenVerbinding);
    final fout = volgendeFout;
    volgendeFout = null;
    return fout;
  }

  void _bewaar(HhBericht bericht) {
    _berichten
      ..removeWhere((b) => b.id == bericht.id)
      ..add(bericht);
    _stromen[bericht.klusId]?.add(bericht);
    for (final stroom in _alle) {
      if (!stroom.isClosed) stroom.add(null);
    }
  }

  /// Een bericht dat "op de server" ontstaat of wijzigt (realtime).
  void zendUit(HhBericht bericht) => _bewaar(bericht);

  @override
  Future<Result<List<HhBericht>>> berichten(
    String klusId, {
    required String helperId,
  }) async {
    aantalLaadacties++;
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final gesprek = [
      for (final b in _berichten)
        if (b.klusId == klusId && b.helperId == helperId) b,
    ]..sort((a, b) => (a.gemaakt ?? _klok).compareTo(b.gemaakt ?? _klok));
    return Result.ok(List.unmodifiable(gesprek));
  }

  @override
  Future<VerstuurUitkomst> verstuur({
    required String klusId,
    required String afzenderId,
    required String tekst,
    HhBerichtSoort soort = HhBerichtSoort.tekst,
  }) async {
    final fout = _neemFout();
    if (fout != null) return VerstuurFout(fout);
    if (isGesloten) return const VerstuurGeweigerd();
    verstuurd.add((tekst: tekst, soort: soort));
    final bericht = HhBericht(
      id: 'b-nieuw-${_volgnummer++}',
      klusId: klusId,
      afzenderId: afzenderId,
      helperId: helperVanKlus[klusId] ?? '',
      tekst: tekst,
      soort: soort,
      gemaakt: _klok.add(Duration(seconds: _volgnummer)),
    );
    _bewaar(bericht);
    return Verstuurd(bericht);
  }

  @override
  Future<Result<HhBericht>> markeerGelezen(
    String berichtId,
    DateTime moment,
  ) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final index = _berichten.indexWhere((b) => b.id == berichtId);
    if (index == -1) return Result.err(const HhFout(HhFoutSoort.nietGevonden));
    final nieuw = _berichten[index].metGelezenOp(moment);
    gelezenGezet.add(berichtId);
    _bewaar(nieuw);
    return Result.ok(nieuw);
  }

  @override
  Future<Result<Map<String, int>>> ongelezenPerKlus(String ikId) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final telling = <String, int>{};
    for (final b in _berichten) {
      final helper = helperVanKlus[b.klusId];
      if (b.isVan(ikId) || b.isGelezen || helper == null) continue;
      if (b.helperId != helper) continue;
      telling[b.klusId] = (telling[b.klusId] ?? 0) + 1;
    }
    return Result.ok(Map.unmodifiable(telling));
  }

  @override
  Stream<HhBericht> volg(String klusId) {
    final bestaand = _stromen[klusId];
    if (bestaand != null && !bestaand.isClosed) return bestaand.stream;
    final stroom = StreamController<HhBericht>.broadcast();
    _stromen[klusId] = stroom;
    return stroom.stream;
  }

  @override
  Stream<void> volgAlle() {
    final stroom = StreamController<void>.broadcast();
    _alle.add(stroom);
    return stroom.stream;
  }

  /// Sluit de open stromen; tests roepen dit aan in addTearDown.
  Future<void> sluit() async {
    for (final stroom in [..._stromen.values, ..._alle]) {
      if (!stroom.isClosed) await stroom.close();
    }
    _stromen.clear();
    _alle.clear();
  }
}
