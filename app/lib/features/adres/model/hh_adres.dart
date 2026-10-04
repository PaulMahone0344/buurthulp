import 'package:flutter/foundation.dart';

/// Eén adres zoals de server het van PDOK (BAG) teruggeeft via
/// GET /api/hh/adres (backend/pb_hooks/hh_adres.pb.js). Straat en plaats
/// komen altijd van PDOK; de gebruiker typt alleen postcode, huisnummer en
/// toevoeging.
@immutable
class HhAdres {
  const HhAdres({
    required this.straat,
    required this.huisnummer,
    required this.postcode,
    required this.plaats,
    required this.adres,
    required this.weergave,
    this.toevoeging = '',
    this.gemeente = '',
    this.lat = 0,
    this.lon = 0,
    this.binnenWerkgebied = false,
  });

  final String straat;
  final String huisnummer;

  /// Huisletter en huisnummertoevoeging zoals BAG: "A", "2", "a-01".
  final String toevoeging;

  /// Altijd "4001 MA".
  final String postcode;
  final String plaats;
  final String gemeente;
  final double lat;
  final double lon;

  /// De regel voor hh_users.adres: "Kerkstraat 1a-01".
  final String adres;

  /// De regel op het kaartje: "Kerkstraat 1, 4001 MA Tiel".
  final String weergave;

  /// Ligt het in het werkgebied (Tiel + 20 km)?
  final bool binnenWerkgebied;

  factory HhAdres.vanJson(Map<String, dynamic> json) {
    double getal(Object? w) =>
        w is num ? w.toDouble() : double.tryParse('$w') ?? 0;
    String tekst(Object? w) => w == null ? '' : '$w';
    return HhAdres(
      straat: tekst(json['straat']),
      huisnummer: tekst(json['huisnummer']),
      toevoeging: tekst(json['toevoeging']),
      postcode: tekst(json['postcode']),
      plaats: tekst(json['plaats']),
      gemeente: tekst(json['gemeente']),
      lat: getal(json['lat']),
      lon: getal(json['lon']),
      adres: tekst(json['adres']),
      weergave: tekst(json['weergave']),
      binnenWerkgebied: json['binnen_werkgebied'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HhAdres &&
      other.postcode == postcode &&
      other.huisnummer == huisnummer &&
      other.toevoeging == toevoeging &&
      other.weergave == weergave;

  @override
  int get hashCode => Object.hash(postcode, huisnummer, toevoeging, weergave);
}

/// Uitkomst van het opzoeken.
sealed class AdresZoekUitkomst {
  const AdresZoekUitkomst();
}

/// Eén of meer adressen (meer = kiezen uit een lijstje).
final class AdresGevonden extends AdresZoekUitkomst {
  const AdresGevonden(this.adressen);
  final List<HhAdres> adressen;
}

/// Bestaat niet. Met [keuzes] als alleen de toevoeging niet klopte.
final class AdresNietGevonden extends AdresZoekUitkomst {
  const AdresNietGevonden(this.melding, {this.keuzes = const []});
  final String melding;
  final List<HhAdres> keuzes;
}

/// De server weigerde de invoer (400): reden postcode, huisnummer of
/// toevoeging.
final class AdresOngeldig extends AdresZoekUitkomst {
  const AdresOngeldig(this.reden, this.melding);
  final String reden;
  final String melding;
}

/// PDOK (of de server) is nu niet te bereiken: aanmelden mag wel, het adres
/// is dan "ongecontroleerd" (de server zet de markering).
final class AdresDienstWeg extends AdresZoekUitkomst {
  const AdresDienstWeg();
}

/// Te veel opzoekingen vanaf dit netwerk (429).
final class AdresLimiet extends AdresZoekUitkomst {
  const AdresLimiet(this.melding);
  final String melding;
}
