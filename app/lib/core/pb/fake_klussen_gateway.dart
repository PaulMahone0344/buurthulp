import '../../features/jongere/klussen/model/hh_klus.dart';
import '../../theme.dart';
import '../hh_fout.dart';
import '../result.dart';
import 'klussen_gateway.dart';

/// Fake voor tests: nooit een verzoek naar de server. Houdt een lijst
/// klussen bij en speelt de hook na: accepteren slaagt alleen op een open
/// klus zonder jongere, anders 409 (bezet). Stuurbaar met [isOffline],
/// [volgendeFout], [accepteerUitkomst] (de eerstvolgende acceptatie geeft
/// precies dit terug, bijvoorbeeld een 409 van "iemand anders") en
/// [zichtbareOudereNaam] (wat de expand na accepteren oplevert).
class FakeKlussenGateway implements KlussenGateway {
  FakeKlussenGateway({
    List<HhKlus> klussen = const [],
    this.jongereId = '',
    this.zichtbareOudereNaam = 'Mevrouw de Vries',
    this.zichtbaarAdres = 'Prins Bernhardlaan 12, 4003 AB Tiel',
  }) : _klussen = {for (final k in klussen) k.id: k};

  final Map<String, HhKlus> _klussen;

  /// Wie de fake als ingelogde jongere ziet (voor accepteren).
  String jongereId;
  final String zichtbareOudereNaam;
  final String zichtbaarAdres;

  bool isOffline = false;
  HhFout? volgendeFout;
  AccepteerUitkomst? accepteerUitkomst;

  /// Wat er tussen twee ladingen "op de server" gebeurt: wordt uitgevoerd
  /// vlak voor de eerstvolgende openKlussen(), daarna gewist.
  void Function(FakeKlussenGateway fake)? voorVolgendeLading;

  int aantalOpenAanvragen = 0;
  int aantalMijnAanvragen = 0;
  final List<String> geaccepteerdeIds = [];

  List<HhKlus> get alleKlussen => List.unmodifiable(_klussen.values);
  HhKlus? klusVan(String id) => _klussen[id];

  void zetKlus(HhKlus klus) => _klussen[klus.id] = klus;

  /// Laat "iemand anders" de klus aannemen.
  void neemAanDoorAnder(String id, {String anderId = 'id-andere-jongere'}) {
    final klus = _klussen[id];
    if (klus == null) return;
    _klussen[id] = klus.copyWith(
      status: HhKlusStatus.geaccepteerd,
      toegewezenJongereId: anderId,
    );
  }

  HhFout? _neemFout() {
    if (isOffline) return const HhFout(HhFoutSoort.geenVerbinding);
    final fout = volgendeFout;
    volgendeFout = null;
    return fout;
  }

  /// De expand van hulpvrager komt alleen mee als de jongere de oudere mag
  /// zien: toegewezen aan hem.
  HhKlus _zoalsZichtbaar(HhKlus klus) {
    if (klus.isToegewezenAan(jongereId)) {
      return klus.copyWith(
        oudereNaam: zichtbareOudereNaam,
        adres: zichtbaarAdres,
      );
    }
    return klus.copyWith(oudereNaam: '', adres: '');
  }

  @override
  Future<Result<List<HhKlus>>> openKlussen() async {
    aantalOpenAanvragen++;
    final actie = voorVolgendeLading;
    voorVolgendeLading = null;
    actie?.call(this);
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final open =
        [
          for (final k in _klussen.values)
            if (k.isOpen) k,
        ]..sort((a, b) {
          final ta = a.wanneerVan;
          final tb = b.wanneerVan;
          if (ta == null || tb == null) return 0;
          return ta.compareTo(tb);
        });
    return Result.ok([for (final k in open) _zoalsZichtbaar(k)]);
  }

  @override
  Future<Result<List<HhKlus>>> mijnKlussen(String jongereId) async {
    aantalMijnAanvragen++;
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final mijn =
        [
          for (final k in _klussen.values)
            if (k.isToegewezenAan(jongereId)) k,
        ]..sort((a, b) {
          final ta = a.wanneerVan;
          final tb = b.wanneerVan;
          if (ta == null || tb == null) return 0;
          return tb.compareTo(ta);
        });
    return Result.ok([for (final k in mijn) _zoalsZichtbaar(k)]);
  }

  @override
  Future<Result<HhKlus>> klus(String id) async {
    final fout = _neemFout();
    if (fout != null) return Result.err(fout);
    final klus = _klussen[id];
    if (klus == null) {
      return Result.err(const HhFout(HhFoutSoort.nietGevonden));
    }
    // Een klus die aan iemand anders is toegewezen mag de jongere niet
    // meer zien (rule): 404, net als de server.
    if (!klus.isOpen && !klus.isToegewezenAan(jongereId)) {
      return Result.err(const HhFout(HhFoutSoort.nietGevonden));
    }
    return Result.ok(_zoalsZichtbaar(klus));
  }

  @override
  Future<AccepteerUitkomst> accepteren(String klusId) async {
    final fout = _neemFout();
    if (fout != null) return AccepteerFout(fout);
    final gezet = accepteerUitkomst;
    if (gezet != null) {
      accepteerUitkomst = null;
      return gezet;
    }
    final klus = _klussen[klusId];
    if (klus == null) return const Geweigerd(AccepteerReden.nietGevonden);
    if (!klus.isOpen) {
      return const Geweigerd(
        AccepteerReden.bezet,
        melding: 'Deze klus is net door iemand anders aangenomen.',
      );
    }
    _klussen[klusId] = klus.copyWith(
      status: HhKlusStatus.geaccepteerd,
      toegewezenJongereId: jongereId,
    );
    geaccepteerdeIds.add(klusId);
    return const Geaccepteerd();
  }
}
