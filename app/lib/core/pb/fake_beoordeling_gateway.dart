import '../../features/jongere/klussen/model/hh_klus.dart';
import '../../features/jongere/reputatie/model/hh_beoordeling.dart';
import '../../theme.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'beoordeling_gateway.dart';

/// Fake voor tests: nooit een verzoek naar de server. Speelt twee dingen na:
///
/// - de RULES van hh_beoordelingen: alleen bij een afgeronde klus, alleen de
///   oudere of de toegewezen jongere, van = [ikBenId], naar = de andere
///   deelnemer, één per klus per kant (unieke index), wijzigen alleen je
///   eigen beoordeling;
/// - de HOOK (hh_reputatie.js): het gemiddelde van alle beoordelingen naar
///   iemand op één decimaal, en het aantal afgeronde klussen waarin hij
///   meedeed. De app zelf rekent dit nooit uit; alleen deze fake, omdat hij
///   de server speelt.
///
/// Stuurbaar met [isOffline], [volgendeFout] (de eerstvolgende aanroep geeft
/// deze fout) en [volgendeUitkomst] (de eerstvolgende geef/wijzig geeft
/// precies dit terug, bijvoorbeeld "al gegeven" van een tweede toestel).
class FakeBeoordelingGateway implements BeoordelingGateway {
  FakeBeoordelingGateway({
    List<HhKlus> klussen = const [],
    List<HhBeoordeling> beoordelingen = const [],
    this.ikBenId = '',
    this.isOffline = false,
    DateTime? klok,
  }) : _klussen = {for (final k in klussen) k.id: k},
       _beoordelingen = [...beoordelingen],
       _klok = klok ?? DateTime.utc(2026, 9, 15, 8);

  final Map<String, HhKlus> _klussen;
  final List<HhBeoordeling> _beoordelingen;
  final DateTime _klok;

  /// Wie de fake als ingelogde gebruiker ziet.
  String ikBenId;

  bool isOffline;
  HhFout? volgendeFout;
  BeoordelingUitkomst? volgendeUitkomst;

  int aantalGegeven = 0;
  int aantalGewijzigd = 0;

  List<HhBeoordeling> get alleBeoordelingen =>
      List.unmodifiable(_beoordelingen);

  void zetKlus(HhKlus klus) => _klussen[klus.id] = klus;

  HhFout? _neemFout() {
    if (isOffline) return const HhFout(HhFoutSoort.geenVerbinding);
    final fout = volgendeFout;
    volgendeFout = null;
    return fout;
  }

  BeoordelingUitkomst? _neemUitkomst() {
    final gezet = volgendeUitkomst;
    volgendeUitkomst = null;
    return gezet;
  }

  /// Wat de hook op hh_users zou zetten.
  HhReputatie reputatieVan(String gebruikerId) {
    var som = 0;
    var geteld = 0;
    for (final b in _beoordelingen) {
      if (b.naarId == gebruikerId && b.sterren > 0) {
        som += b.sterren;
        geteld++;
      }
    }
    final aantal = _klussen.values
        .where(
          (k) =>
              k.status == HhKlusStatus.afgerond &&
              (k.hulpvragerId == gebruikerId ||
                  k.toegewezenJongereId == gebruikerId),
        )
        .length;
    return HhReputatie(
      // Zoals Math.round(x * 10) / 10 in hh_reputatie.js.
      sterrenGemiddeld: geteld == 0 ? 0 : (som / geteld * 10).round() / 10,
      klussenAantal: aantal,
    );
  }

  var _volgnummer = 0;

  /// B5: wat er bij de geheime vraag werd meegestuurd (klus-id bij geef,
  /// beoordeling-id bij wijzig).
  final List<({String klusId, bool? allesInOrde, String toelichting})> geheim =
      [];

  @override
  Future<BeoordelingUitkomst> geef({
    required String klusId,
    required String vanId,
    required String naarId,
    required int sterren,
    String tekst = '',
    bool? allesInOrde,
    String geheimToelichting = '',
  }) async {
    aantalGegeven++;
    geheim.add((
      klusId: klusId,
      allesInOrde: allesInOrde,
      toelichting: geheimToelichting,
    ));
    final fout = _neemFout();
    if (fout != null) return BeoordelingFout(fout);
    final gezet = _neemUitkomst();
    if (gezet != null) return gezet;

    final klus = _klussen[klusId];
    if (klus == null || klus.status != HhKlusStatus.afgerond) {
      return const BeoordelingGeweigerd(BeoordelingReden.nietToegestaan);
    }
    final deelnemers = {klus.hulpvragerId, klus.toegewezenJongereId};
    final isDeelnemer = vanId.isNotEmpty && deelnemers.contains(vanId);
    if (vanId != ikBenId ||
        !isDeelnemer ||
        naarId == vanId ||
        !deelnemers.contains(naarId) ||
        sterren < 1 ||
        sterren > 5) {
      return const BeoordelingGeweigerd(BeoordelingReden.nietToegestaan);
    }
    final bestaat = _beoordelingen.any(
      (b) => b.klusId == klusId && b.vanId == vanId,
    );
    if (bestaat) {
      return const BeoordelingGeweigerd(BeoordelingReden.alGegeven);
    }

    _volgnummer++;
    final nieuw = HhBeoordeling(
      id: 'b-$klusId-$vanId',
      klusId: klusId,
      vanId: vanId,
      naarId: naarId,
      sterren: sterren,
      tekst: tekst.trim(),
      gemaakt: _klok.add(Duration(minutes: _volgnummer)),
    );
    _beoordelingen.add(nieuw);
    return BeoordelingOpgeslagen(nieuw);
  }

  @override
  Future<BeoordelingUitkomst> wijzig(
    String beoordelingId, {
    required int sterren,
    required String tekst,
    bool? allesInOrde,
    String geheimToelichting = '',
  }) async {
    aantalGewijzigd++;
    geheim.add((
      klusId: beoordelingId,
      allesInOrde: allesInOrde,
      toelichting: geheimToelichting,
    ));
    final fout = _neemFout();
    if (fout != null) return BeoordelingFout(fout);
    final gezet = _neemUitkomst();
    if (gezet != null) return gezet;

    final index = _beoordelingen.indexWhere(
      (b) => b.id == beoordelingId && b.vanId == ikBenId,
    );
    if (index == -1) {
      return const BeoordelingGeweigerd(BeoordelingReden.nietGevonden);
    }
    if (sterren < 1 || sterren > 5) {
      return const BeoordelingGeweigerd(BeoordelingReden.nietToegestaan);
    }
    final nieuw = _beoordelingen[index].copyWith(
      sterren: sterren,
      tekst: tekst.trim(),
    );
    _beoordelingen[index] = nieuw;
    return BeoordelingOpgeslagen(nieuw);
  }

  @override
  Future<Result<List<HhBeoordeling>>> gegevenDoor(String vanId) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    return Result.ok(
      _laatsteEerst(_beoordelingen.where((b) => b.vanId == vanId)),
    );
  }

  @override
  Future<Result<List<HhBeoordeling>>> ontvangen(
    String naarId, {
    int limiet = 5,
  }) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    return Result.ok(
      _laatsteEerst(
        _beoordelingen.where((b) => b.naarId == naarId && b.heeftTekst),
      ).take(limiet).toList(),
    );
  }

  @override
  Future<Result<HhReputatie>> reputatie(String gebruikerId) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    return Result.ok(reputatieVan(gebruikerId));
  }

  static List<HhBeoordeling> _laatsteEerst(Iterable<HhBeoordeling> rijen) {
    final lijst = [...rijen];
    lijst.sort((a, b) {
      final ta = a.gemaakt;
      final tb = b.gemaakt;
      if (ta == null || tb == null) return 0;
      return tb.compareTo(ta);
    });
    return lijst;
  }
}
