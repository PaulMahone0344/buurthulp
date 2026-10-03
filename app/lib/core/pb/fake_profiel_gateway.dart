import 'dart:typed_data';

import '../../features/jongere/model/hh_profiel.dart';
import '../../features/jongere/model/hh_screening_status.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'profiel_gateway.dart';

/// Een upload zoals de fake hem ontving; tests kijken hierop.
class FakeUpload {
  const FakeUpload({
    required this.collectie,
    required this.recordId,
    required this.veld,
    required this.bestandsnaam,
    required this.bytes,
  });

  final String collectie;
  final String recordId;
  final String veld;
  final String bestandsnaam;
  final int bytes;
}

/// Fake voor tests en het dev-scherm; er gaat nooit een verzoek naar de
/// server. Doet de server-rules na: geblokkeerde velden geven nietGevonden
/// (404, zoals PocketBase bij een geweigerde update), verificatiestatus mag
/// alleen van nieuw naar in_behandeling, een tweede profiel per gebruiker
/// wordt geweigerd. [isOffline] laat alles mislukken met geenVerbinding,
/// [volgendeFout] laat de eerstvolgende aanroep mislukken.
class FakeProfielGateway implements ProfielGateway {
  FakeProfielGateway({
    Map<String, HhProfiel> profielen = const {},
    Map<String, HhAccountGegevens> accounts = const {},
    this.wijken = standaardWijken,
    this.klustypes = standaardKlustypes,
  }) : _profielen = {...profielen},
       _accounts = {...accounts};

  /// Een helper van 18+ die helemaal rond is (goedgekeurd, ID
  /// gecontroleerd, VOG gezien): de staat waarin hij klussen ziet.
  FakeProfielGateway.goedgekeurd(String gebruikerId)
    : this(
        profielen: {
          gebruikerId: HhProfiel(
            id: 'profiel-$gebruikerId',
            gebruikerId: gebruikerId,
            verificatiestatus: HhScreeningStatus.goedgekeurd,
            straalKm: 3,
            overMij: 'Ik help graag met boodschappen.',
            vogAangevraagdOp: DateTime.utc(2026, 9, 1),
            vogGezienOp: DateTime.utc(2026, 9, 20),
            idGecontroleerdOp: DateTime.utc(2026, 9, 20),
          ),
        },
        accounts: {
          gebruikerId: HhAccountGegevens(
            geboortedatum: DateTime.utc(2000, 5, 14),
            wijkId: 'wijk-west',
          ),
        },
      );

  static const standaardWijken = [
    HhWijk(id: 'wijk-west', gemeente: 'Tiel', wijk: 'Tiel-West'),
    HhWijk(id: 'wijk-passewaaij', gemeente: 'Tiel', wijk: 'Passewaaij'),
  ];

  static const standaardKlustypes = [
    HhKlustype(
      id: 'type-boodschappen',
      naam: 'boodschappen',
      icoon: 'shopping_cart',
    ),
    HhKlustype(id: 'type-tuin', naam: 'tuin', icoon: 'yard'),
    HhKlustype(id: 'type-huis', naam: 'klusje in huis', icoon: 'handyman'),
    HhKlustype(
      id: 'type-digitaal',
      naam: 'telefoon/tablet-hulp',
      icoon: 'devices',
    ),
    HhKlustype(
      id: 'type-wandelen',
      naam: 'wandelen/gezelschap',
      icoon: 'directions_walk',
    ),
    HhKlustype(id: 'type-vervoer', naam: 'vervoer', icoon: 'directions_car'),
  ];

  /// Profielen op gebruikers-id.
  final Map<String, HhProfiel> _profielen;
  final Map<String, HhAccountGegevens> _accounts;
  final List<HhWijk> wijken;
  final List<HhKlustype> klustypes;

  bool isOffline = false;
  HhFout? volgendeFout;

  Map<String, dynamic>? laatsteProfielBody;
  final List<FakeUpload> uploads = [];
  int _teller = 0;

  HhProfiel? profielVan(String gebruikerId) => _profielen[gebruikerId];
  HhAccountGegevens accountVan(String gebruikerId) =>
      _accounts[gebruikerId] ?? const HhAccountGegevens();

  /// Voor tests: de coordinator (server) verandert een status. Goedkeuren
  /// wist de ID-foto en zet id_gecontroleerd_op, zoals de B2-hook.
  void zetStatus(String gebruikerId, {HhScreeningStatus? verificatiestatus}) {
    final huidig = _profielen[gebruikerId];
    if (huidig == null) return;
    final wordtGoedgekeurd =
        verificatiestatus == HhScreeningStatus.goedgekeurd &&
        huidig.verificatiestatus != HhScreeningStatus.goedgekeurd;
    _profielen[gebruikerId] = huidig.copyWith(
      verificatiestatus: verificatiestatus,
      documentFoto: wordtGoedgekeurd ? '' : null,
      idGecontroleerdOp: wordtGoedgekeurd
          ? () => DateTime.utc(2026, 10, 3)
          : null,
    );
  }

  /// Voor tests: de meldkamer zag de VOG (of haalt hem weg met null).
  void zetVogGezien(String gebruikerId, DateTime? op) {
    final huidig = _profielen[gebruikerId];
    if (huidig == null) return;
    _profielen[gebruikerId] = huidig.copyWith(vogGezienOp: () => op);
  }

  /// Voor tests: de accountvelden (geboortedatum, ouder-toestemming).
  void zetAccount(String gebruikerId, HhAccountGegevens account) =>
      _accounts[gebruikerId] = account;

  HhFout? _neemFout() {
    if (isOffline) return const HhFout(HhFoutSoort.geenVerbinding);
    final fout = volgendeFout;
    volgendeFout = null;
    return fout;
  }

  @override
  Future<Result<HhProfiel?>> haalProfiel(String gebruikerId) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    return Result.ok(_profielen[gebruikerId]);
  }

  @override
  Future<Result<HhProfiel>> maakProfielAan(
    String gebruikerId,
    Map<String, dynamic> velden,
  ) async {
    laatsteProfielBody = Map.unmodifiable(velden);
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    if (_profielen.containsKey(gebruikerId) ||
        velden.containsKey('verificatiestatus') ||
        velden.keys.any(hhProfielGeblokkeerdeVelden.contains)) {
      return Result.err(const HhFout(HhFoutSoort.ongeldigeInvoer));
    }
    _teller++;
    final profiel = _pasToe(
      HhProfiel(id: 'profiel-$_teller', gebruikerId: gebruikerId),
      velden,
    );
    _profielen[gebruikerId] = profiel;
    return Result.ok(profiel);
  }

  @override
  Future<Result<HhProfiel>> werkProfielBij(
    String profielId,
    Map<String, dynamic> velden,
  ) async {
    laatsteProfielBody = Map.unmodifiable(velden);
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final huidig = _zoekProfiel(profielId);
    if (huidig == null ||
        velden.keys.any(hhProfielGeblokkeerdeVelden.contains)) {
      return Result.err(const HhFout(HhFoutSoort.nietGevonden));
    }
    if (velden.containsKey('verificatiestatus') &&
        !(huidig.verificatiestatus == HhScreeningStatus.nieuw &&
            velden['verificatiestatus'] ==
                HhScreeningStatus.inBehandeling.code)) {
      return Result.err(const HhFout(HhFoutSoort.nietGevonden));
    }
    final nieuw = _pasToe(huidig, velden);
    _profielen[nieuw.gebruikerId] = nieuw;
    return Result.ok(nieuw);
  }

  @override
  Future<Result<HhProfiel>> uploadIdFoto({
    required String profielId,
    required Uint8List bytes,
    required String bestandsnaam,
  }) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final huidig = _zoekProfiel(profielId);
    // Na goedkeuring weigert de server een nieuwe ID-foto (80-b2-rules).
    if (huidig == null ||
        huidig.verificatiestatus == HhScreeningStatus.goedgekeurd) {
      return Result.err(const HhFout(HhFoutSoort.nietGevonden));
    }
    uploads.add(
      FakeUpload(
        collectie: hhProfielenCollectie,
        recordId: profielId,
        veld: 'document_foto',
        bestandsnaam: bestandsnaam,
        bytes: bytes.length,
      ),
    );
    final nieuw = huidig.copyWith(
      documentFoto: 'document_foto_${uploads.length}.jpg',
    );
    _profielen[nieuw.gebruikerId] = nieuw;
    return Result.ok(nieuw);
  }

  @override
  Future<Result<HhAccountGegevens>> haalAccountGegevens(
    String gebruikerId,
  ) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    return Result.ok(accountVan(gebruikerId));
  }

  @override
  Future<Result<List<HhWijk>>> haalWijken() async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    return Result.ok([
      for (final w in wijken)
        if (w.isActief) w,
    ]);
  }

  @override
  Future<Result<List<HhKlustype>>> haalKlustypes() async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    return Result.ok(List.unmodifiable(klustypes));
  }

  HhProfiel? _zoekProfiel(String profielId) {
    for (final p in _profielen.values) {
      if (p.id == profielId) return p;
    }
    return null;
  }

  /// Past een body toe zoals de server dat zou doen (alleen de velden die
  /// meegestuurd zijn).
  static HhProfiel _pasToe(HhProfiel p, Map<String, dynamic> velden) {
    return p.copyWith(
      verificatiestatus: velden.containsKey('verificatiestatus')
          ? HhScreeningStatus.vanCode(velden['verificatiestatus'] as String?)
          : null,
      overMij: velden['over_mij'] as String?,
      vogAangevraagdOp: velden.containsKey('vog_aangevraagd_op')
          ? () =>
                HhProfiel.datumVanServer(velden['vog_aangevraagd_op'] as String)
          : null,
    );
  }
}
