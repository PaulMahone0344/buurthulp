import 'dart:async';

import '../../features/coordinator/domein/incident_lijst.dart';
import '../../features/coordinator/model/hh_coordinator_klus.dart';
import '../../features/coordinator/model/hh_incident.dart';
import '../../features/coordinator/model/hh_kandidaat.dart';
import '../../theme.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'coordinator_gateway.dart';

/// Fake voor tests: nooit een verzoek naar de server. Houdt meldingen,
/// klussen en jongeren in het geheugen en speelt de hook na: koppelen
/// slaagt alleen op een open klus zonder jongere met een goedgekeurde
/// jongere, vrijgeven alleen op geaccepteerd of onderweg.
///
/// Stuurbaar met [isOffline], [volgendeFout] en [koppelUitkomst] (de
/// eerstvolgende koppeling of vrijgave geeft precies dit terug).
/// [stuurIncident] speelt de realtime-verbinding: de melding komt binnen
/// alsof de server hem duwde.
class FakeCoordinatorGateway implements CoordinatorGateway {
  FakeCoordinatorGateway({
    List<HhIncident> incidenten = const [],
    List<HhCoordinatorKlus> klussen = const [],
    List<HhKandidaat> jongeren = const [],
    this.coordinatorId = 'id-coordinator',
  }) : _incidenten = {for (final i in incidenten) i.id: i},
       _klussen = {for (final k in klussen) k.id: k},
       _jongeren = [...jongeren];

  final Map<String, HhIncident> _incidenten;
  final Map<String, HhCoordinatorKlus> _klussen;
  final List<HhKandidaat> _jongeren;
  final String coordinatorId;

  final _stroom = StreamController<IncidentWijziging>.broadcast();

  bool isOffline = false;
  HhFout? volgendeFout;
  KoppelUitkomst? koppelUitkomst;

  /// Jongeren die de "server" niet goedgekeurd vindt, op gebruiker-id.
  final Set<String> nietGoedgekeurd = {};

  int aantalIncidentAanvragen = 0;
  int aantalKlusAanvragen = 0;
  final List<String> gekoppeldeIds = [];
  final List<String> vrijgegevenIds = [];

  List<HhIncident> get alleIncidenten => List.unmodifiable(_incidenten.values);
  HhCoordinatorKlus? klusVan(String id) => _klussen[id];

  void zetKlus(HhCoordinatorKlus klus) => _klussen[klus.id] = klus;
  void zetIncident(HhIncident incident) => _incidenten[incident.id] = incident;

  /// Speelt een duw van de server: de melding komt binnen op de stroom.
  void stuurIncident(
    HhIncident incident, {
    IncidentWijzigingSoort soort = IncidentWijzigingSoort.nieuw,
  }) {
    _incidenten[incident.id] = incident;
    _stroom.add(IncidentWijziging(soort, incident.id, incident: incident));
  }

  void sluitStroom() => _stroom.close();

  HhFout? _neemFout() {
    if (isOffline) return const HhFout(HhFoutSoort.geenVerbinding);
    final fout = volgendeFout;
    volgendeFout = null;
    return fout;
  }

  @override
  Future<Result<List<HhIncident>>> incidenten() async {
    aantalIncidentAanvragen++;
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    return Result.ok(sorteerIncidenten(_incidenten.values));
  }

  @override
  Stream<IncidentWijziging> incidentStroom() => _stroom.stream;

  @override
  Future<Result<HhIncident>> handelAf(
    String incidentId,
    String afhandeling,
  ) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final incident = _incidenten[incidentId];
    if (incident == null) {
      return Result.err(const HhFout(HhFoutSoort.nietGevonden));
    }
    final nieuw = incident.metAfhandeling(afhandeling);
    _incidenten[incidentId] = nieuw;
    return Result.ok(nieuw);
  }

  @override
  Future<Result<List<HhCoordinatorKlus>>> openKlussen() async {
    aantalKlusAanvragen++;
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final open = [
      for (final k in _klussen.values)
        if (k.isOpen) k,
    ]..sort((a, b) => a.aangemaaktOp.compareTo(b.aangemaaktOp));
    return Result.ok(open);
  }

  @override
  Future<Result<HhCoordinatorKlus>> klus(String id) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final klus = _klussen[id];
    if (klus == null) {
      return Result.err(const HhFout(HhFoutSoort.nietGevonden));
    }
    return Result.ok(klus);
  }

  @override
  Future<Result<List<HhKandidaat>>> goedgekeurdeJongeren() async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    return Result.ok(List.unmodifiable(_jongeren));
  }

  @override
  Future<KoppelUitkomst> koppelen(String klusId, String jongereId) async {
    final vooraf = _neemGezetteUitkomst();
    if (vooraf != null) return vooraf;

    final klus = _klussen[klusId];
    if (klus == null) {
      return const KoppelGeweigerd(KoppelReden.nietGevonden);
    }
    if (!klus.isOpen) {
      return const KoppelGeweigerd(
        KoppelReden.bezet,
        melding:
            'Deze klus is niet meer open; hij is al aan iemand toegewezen.',
      );
    }
    if (nietGoedgekeurd.contains(jongereId)) {
      return const KoppelGeweigerd(
        KoppelReden.jongereNietGeschikt,
        melding:
            'Deze helper is nog niet goedgekeurd en kan geen klussen doen.',
      );
    }
    final jongere = _jongereVan(jongereId);
    _klussen[klusId] = klus.copyWith(
      status: HhKlusStatus.geaccepteerd,
      toegewezenJongereId: jongereId,
      toegewezenJongereNaam: jongere?.naam ?? '',
    );
    gekoppeldeIds.add(klusId);
    final andereWijk =
        jongere != null &&
        jongere.heeftWijk &&
        klus.oudereWijkId.isNotEmpty &&
        jongere.wijkId != klus.oudereWijkId;
    return KoppelGelukt(isAndereWijk: andereWijk);
  }

  @override
  Future<KoppelUitkomst> vrijgeven(String klusId, String reden) async {
    final vooraf = _neemGezetteUitkomst();
    if (vooraf != null) return vooraf;

    final klus = _klussen[klusId];
    if (klus == null) {
      return const KoppelGeweigerd(KoppelReden.nietGevonden);
    }
    if (!klus.isVrijTeGeven) {
      return const KoppelGeweigerd(
        KoppelReden.nietVrijTeGeven,
        melding:
            'Deze klus staat niet op geaccepteerd of onderweg en kan niet worden vrijgegeven.',
      );
    }
    _klussen[klusId] = klus.copyWith(
      status: HhKlusStatus.open,
      toegewezenJongereId: '',
      toegewezenJongereNaam: '',
    );
    vrijgegevenIds.add(klusId);
    return const KoppelGelukt();
  }

  /// Een vooraf gezette uitkomst of een gezette fout gaat voor op het
  /// nagespeelde gedrag; allebei gelden maar één keer.
  KoppelUitkomst? _neemGezetteUitkomst() {
    final fout = _neemFout();
    if (fout != null) return KoppelFout(fout);
    final gezet = koppelUitkomst;
    if (gezet != null) {
      koppelUitkomst = null;
      return gezet;
    }
    return null;
  }

  HhKandidaat? _jongereVan(String id) {
    for (final jongere in _jongeren) {
      if (jongere.id == id) return jongere;
    }
    return null;
  }
}
