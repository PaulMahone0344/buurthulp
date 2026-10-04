import 'dart:async';

import '../../features/jongere/klussen/model/hh_klus.dart';
import '../../features/jongere/uitvoeren/domein/klus_overgang.dart';
import '../../features/jongere/uitvoeren/model/hh_klus_logregel.dart';
import '../../features/jongere/xp/model/hh_xp.dart';
import '../../theme.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'uitvoer_gateway.dart';

/// Fake voor tests: nooit een verzoek naar de server. Speelt de hook na —
/// de statusmachine loopt één stap tegelijk, annuleren kent de twee kanten,
/// en elke wissel schrijft een logregel met tijdstempel.
///
/// Stuurbaar met [isOffline], [volgendeFout] (de eerstvolgende aanroep geeft
/// deze fout), [volgendeUitkomst] (de eerstvolgende status- of annuleerstap
/// geeft precies dit terug, bijvoorbeeld een 409 van "iemand was eerder") en
/// [nummerVan] (leeg = geen nummer bekend). [zendUit] speelt een wijziging
/// "op de server" na, zoals realtime hem zou binnenbrengen.
class FakeUitvoerGateway implements UitvoerGateway {
  FakeUitvoerGateway({
    List<HhKlus> klussen = const [],
    List<HhKlusLogregel> logregels = const [],
    this.ikBenId = '',
    this.nummerVan = '06-10000001',
    this.naamVan = 'Mevrouw de Vries',
    DateTime? klok,
  }) : _klussen = {for (final k in klussen) k.id: k},
       _logs = [...logregels],
       _klok = klok ?? DateTime(2026, 9, 15, 10);

  final Map<String, HhKlus> _klussen;
  final List<HhKlusLogregel> _logs;
  final DateTime _klok;
  final Map<String, StreamController<HhKlus>> _stromen = {};

  /// Wie de fake als ingelogde gebruiker ziet (jongere of oudere).
  String ikBenId;

  /// Wat de belroute teruggeeft; leeg betekent "geen nummer bekend".
  String nummerVan;
  String naamVan;

  bool isOffline = false;
  HhFout? volgendeFout;
  UitvoerUitkomst? volgendeUitkomst;

  /// B9: wat de statusroute bij "afgerond" als beloning meestuurt.
  HhBeloning? beloningBijAfgerond;

  int aantalStatusStappen = 0;
  int aantalAnnuleringen = 0;
  int aantalBelVerzoeken = 0;
  final List<String> gezetteStappen = [];

  List<HhKlus> get alleKlussen => List.unmodifiable(_klussen.values);
  List<HhKlusLogregel> get alleLogregels => List.unmodifiable(_logs);
  HhKlus? klusVan(String id) => _klussen[id];

  void zetKlus(HhKlus klus) => _klussen[klus.id] = klus;

  /// Speelt een wijziging na die van de server komt (realtime).
  void zendUit(HhKlus klus) {
    _klussen[klus.id] = klus;
    _stromen[klus.id]?.add(klus);
  }

  HhFout? _neemFout() {
    if (isOffline) return const HhFout(HhFoutSoort.geenVerbinding);
    final fout = volgendeFout;
    volgendeFout = null;
    return fout;
  }

  int _volgnummer = 0;
  void _log(
    HhKlus klus,
    HhKlusStatus? van,
    HhKlusStatus naar, {
    String toelichting = '',
  }) {
    _volgnummer++;
    _logs.add(
      HhKlusLogregel(
        id: 'log-${klus.id}-$_volgnummer',
        klusId: klus.id,
        van: van,
        naar: naar,
        doorId: ikBenId,
        toelichting: toelichting,
        wanneer: _klok.add(Duration(minutes: _volgnummer)),
      ),
    );
  }

  @override
  Future<UitvoerUitkomst> zetStatus(String klusId, HhKlusStatus naar) async {
    aantalStatusStappen++;
    final fout = _neemFout();
    if (fout != null) return UitvoerFout(fout);
    final gezet = volgendeUitkomst;
    if (gezet != null) {
      volgendeUitkomst = null;
      return gezet;
    }
    final klus = _klussen[klusId];
    if (klus == null) {
      return const UitvoerGeweigerd(UitvoerReden.nietGevonden);
    }
    if (!klus.isToegewezenAan(ikBenId)) {
      return const UitvoerGeweigerd(UitvoerReden.geenToegang);
    }
    if (volgendeStap(klus.status) != naar) {
      return const UitvoerGeweigerd(
        UitvoerReden.nietMeerMogelijk,
        melding:
            'Deze stap kan nu niet meer. Ververs het scherm en probeer het opnieuw.',
      );
    }
    final nieuw = klus.copyWith(status: naar);
    _log(klus, klus.status, naar);
    gezetteStappen.add(naar.name);
    zendUit(nieuw);
    return UitvoerGelukt(
      naar,
      beloning: naar == HhKlusStatus.afgerond ? beloningBijAfgerond : null,
    );
  }

  @override
  Future<UitvoerUitkomst> annuleer(String klusId, String reden) async {
    aantalAnnuleringen++;
    final fout = _neemFout();
    if (fout != null) return UitvoerFout(fout);
    final gezet = volgendeUitkomst;
    if (gezet != null) {
      volgendeUitkomst = null;
      return gezet;
    }
    if (!isGeldigeReden(reden)) {
      return const UitvoerGeweigerd(UitvoerReden.ongeldigeReden);
    }
    final klus = _klussen[klusId];
    if (klus == null) {
      return const UitvoerGeweigerd(UitvoerReden.nietGevonden);
    }
    final isJongere = klus.isToegewezenAan(ikBenId);
    final isOudere = klus.hulpvragerId == ikBenId;
    if (!isJongere && !isOudere) {
      return const UitvoerGeweigerd(UitvoerReden.geenToegang);
    }
    if (klus.status == HhKlusStatus.bezig) {
      return const UitvoerGeweigerd(UitvoerReden.isBezig);
    }
    final mag = isOudere
        ? magOudereAnnuleren(klus.status)
        : magJongereAnnuleren(klus.status);
    if (!mag) return const UitvoerGeweigerd(UitvoerReden.nietMeerMogelijk);

    final naar = isOudere ? HhKlusStatus.geannuleerd : HhKlusStatus.open;
    final nieuw = isOudere
        ? klus.copyWith(status: naar)
        : klus.copyWith(
            status: naar,
            toegewezenJongereId: '',
            jongereNaam: '',
            isJongereIdGecontroleerd: false,
          );
    _log(klus, klus.status, naar, toelichting: reden.trim());
    zendUit(nieuw);
    return UitvoerGelukt(naar);
  }

  @override
  Future<BelUitkomst> belNummer(String klusId) async {
    aantalBelVerzoeken++;
    final fout = _neemFout();
    if (fout != null) return BelFout(fout);
    final klus = _klussen[klusId];
    if (klus == null) return const BelGeweigerd(UitvoerReden.nietGevonden);
    if (!magBellenBij(klus.status)) {
      return const BelGeweigerd(UitvoerReden.nietMeerMogelijk);
    }
    if (nummerVan.isEmpty) {
      return const BelGeweigerd(UitvoerReden.geenNummer);
    }
    return BelNummer(nummer: nummerVan, naam: naamVan);
  }

  @override
  Future<Result<List<HhKlusLogregel>>> logregels(String klusId) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    return Result.ok([
      for (final l in _logs)
        if (l.klusId == klusId) l,
    ]);
  }

  @override
  Future<Result<HhKlus>> klus(String klusId) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final klus = _klussen[klusId];
    if (klus == null) {
      return Result.err(const HhFout(HhFoutSoort.nietGevonden));
    }
    return Result.ok(klus);
  }

  @override
  Future<Result<List<HhKlus>>> hulpvragen(String hulpvragerId) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final mijn =
        [
          for (final k in _klussen.values)
            if (k.hulpvragerId == hulpvragerId) k,
        ]..sort((a, b) {
          final ta = a.wanneerVan;
          final tb = b.wanneerVan;
          if (ta == null || tb == null) return 0;
          return tb.compareTo(ta);
        });
    return Result.ok(mijn);
  }

  @override
  Stream<HhKlus> volgKlus(String klusId) {
    final bestaand = _stromen[klusId];
    if (bestaand != null && !bestaand.isClosed) return bestaand.stream;
    final stroom = StreamController<HhKlus>.broadcast();
    _stromen[klusId] = stroom;
    return stroom.stream;
  }

  /// Sluit de open stromen; tests roepen dit aan in addTearDown.
  Future<void> sluit() async {
    for (final stroom in _stromen.values) {
      if (!stroom.isClosed) await stroom.close();
    }
    _stromen.clear();
  }
}
