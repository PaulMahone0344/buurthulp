import '../../features/adres/model/hh_adres.dart';
import 'adres_gateway.dart';

/// Nep voor tests (en de dev-app): kent een paar vaste adressen, zoals
/// PDOK ze teruggeeft. Nooit een echt verzoek.
class FakeAdresGateway implements AdresGateway {
  FakeAdresGateway({Map<String, List<HhAdres>>? adressen})
    : _adressen = adressen ?? standaardAdressen;

  final Map<String, List<HhAdres>> _adressen;

  /// Elke zoekopdracht, voor tests ("geen dubbele verzoeken").
  final List<({String postcode, String huisnummer, String toevoeging})>
  verzoeken = [];

  /// Zet om PDOK onbereikbaar te maken.
  bool dienstWeg = false;

  /// Zet om de rate-limit te laten afgaan.
  bool limiet = false;

  static const kerkstraat1 = HhAdres(
    straat: 'Kerkstraat',
    huisnummer: '1',
    postcode: '4001 MA',
    plaats: 'Tiel',
    gemeente: 'Tiel',
    adres: 'Kerkstraat 1',
    weergave: 'Kerkstraat 1, 4001 MA Tiel',
    lat: 51.88761538,
    lon: 5.43597055,
    binnenWerkgebied: true,
  );

  static HhAdres _flat(String toevoeging) => HhAdres(
    straat: 'Nieuwe Tielseweg',
    huisnummer: '1',
    toevoeging: toevoeging,
    postcode: '4001 JS',
    plaats: 'Tiel',
    gemeente: 'Tiel',
    adres: 'Nieuwe Tielseweg 1$toevoeging',
    weergave: 'Nieuwe Tielseweg 1$toevoeging, 4001 JS Tiel',
    lat: 51.8837,
    lon: 5.4361,
    binnenWerkgebied: true,
  );

  static const dam1 = HhAdres(
    straat: 'Dam',
    huisnummer: '1',
    postcode: '1012 JS',
    plaats: 'Amsterdam',
    gemeente: 'Amsterdam',
    adres: 'Dam 1',
    weergave: 'Dam 1, 1012 JS Amsterdam',
    lat: 52.37329259,
    lon: 4.8937175,
  );

  static final standaardAdressen = <String, List<HhAdres>>{
    '4001MA:1': [kerkstraat1],
    '4001JS:1': [_flat('a-01'), _flat('a-02')],
    '1012JS:1': [dam1],
  };

  @override
  Future<AdresZoekUitkomst> zoek({
    required String postcode,
    required String huisnummer,
    String toevoeging = '',
  }) async {
    verzoeken.add((
      postcode: postcode,
      huisnummer: huisnummer,
      toevoeging: toevoeging,
    ));
    if (limiet) {
      return const AdresLimiet(
        'Je hebt veel adressen opgezocht. Probeer het over een uur opnieuw.',
      );
    }
    if (dienstWeg) return const AdresDienstWeg();
    final sleutel = '${postcode.replaceAll(' ', '').toUpperCase()}:$huisnummer';
    final alle = _adressen[sleutel] ?? const [];
    if (alle.isEmpty) {
      return const AdresNietGevonden(
        'We vinden dit adres niet. Klopt de postcode en het huisnummer?',
      );
    }
    String s(String t) => t.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    final passend = toevoeging.trim().isEmpty
        ? alle
        : alle.where((a) => s(a.toevoeging) == s(toevoeging)).toList();
    if (passend.isEmpty) {
      return AdresNietGevonden(
        'Deze toevoeging kennen we niet op dit huisnummer. Kies er een uit de lijst.',
        keuzes: alle,
      );
    }
    return AdresGevonden(passend);
  }
}
