import '../l10n/teksten_nl.dart';

/// De foutsoorten die de app kent. Een gebruiker ziet nooit een technische
/// melding; elke soort heeft een Nederlandse zin in [TekstenNl].
enum HhFoutSoort {
  /// Geen netwerk of server onbereikbaar. De knop blijft bruikbaar zodat
  /// de gebruiker opnieuw kan proberen.
  geenVerbinding,

  /// Verkeerd wachtwoord en onbekend e-mailadres geven samen deze ene
  /// fout: nooit verklappen of een adres bestaat.
  ongeldigeInlog,

  /// Registreren met een adres dat al een account heeft.
  emailBestaatAl,

  /// De server laat pas binnen na bevestiging van het e-mailadres.
  emailNietBevestigd,

  /// 401: token verlopen of ingetrokken. Terug naar inloggen.
  nietIngelogd,

  /// 403: wel ingelogd, maar dit mag deze rol niet.
  geenToegang,

  /// 404: bestaat niet, of mag niet gezien worden (server verklapt niet
  /// welke van de twee).
  nietGevonden,

  /// 400 met veldfouten die de app niet apart kent.
  ongeldigeInvoer,

  /// ADRES: de server keurde het adres af (bestaat niet bij PDOK, postcode
  /// of huisnummer klopt niet, toevoeging kiezen). De melding komt van de
  /// server (je-vorm, al Nederlands).
  adresOngeldig,

  /// B11: de partnercode (jongerenwerk) bestaat niet of staat uit. De
  /// melding komt van de server.
  partnerCode,

  /// 5xx.
  server,

  onbekend,
}

class HhFout {
  const HhFout(this.soort, {this.detail, this.serverMelding});

  final HhFoutSoort soort;

  /// Een Nederlandse melding van de server zelf (alleen bij
  /// [HhFoutSoort.adresOngeldig], [HhFoutSoort.partnerCode] en een 409 van
  /// een hook).
  final String? serverMelding;

  /// Technische details voor logs en tests, nooit voor de gebruiker.
  final String? detail;

  /// Vertaalt een PocketBase-antwoord naar een [HhFout]. [statuscode] null
  /// of 0 betekent dat er nooit een antwoord kwam (geen verbinding).
  /// [antwoord] is de JSON-body van PocketBase: {"data": {veld: {code}}}.
  factory HhFout.vanStatus(
    int? statuscode, {
    Map<String, dynamic> antwoord = const {},
  }) {
    final soort = switch (statuscode) {
      null || 0 => HhFoutSoort.geenVerbinding,
      400 => _soortVoor400(antwoord),
      401 => HhFoutSoort.nietIngelogd,
      403 => HhFoutSoort.geenToegang,
      404 => HhFoutSoort.nietGevonden,
      >= 500 => HhFoutSoort.server,
      _ => HhFoutSoort.onbekend,
    };
    return HhFout(
      soort,
      detail: '$statuscode $antwoord',
      serverMelding: switch (soort) {
        HhFoutSoort.adresOngeldig => _veldMelding(antwoord, 'adres'),
        HhFoutSoort.partnerCode => _veldMelding(antwoord, 'partner_code'),
        // B11: een hook antwoordt 409 met {melding, reden} in gewone taal.
        _ when statuscode == 409 => _hookMelding(antwoord),
        _ => null,
      },
    );
  }

  static String? _hookMelding(Map<String, dynamic> antwoord) {
    final melding = antwoord['melding'];
    return melding is String && melding.trim().isNotEmpty ? melding : null;
  }

  /// De melding van een hook-check (adres: hh_aanmelden.pb.js, partnercode:
  /// hh_meldkamer.pb.js): data.[veld].message, anders de algemene message.
  static String? _veldMelding(Map<String, dynamic> antwoord, String veld) {
    final data = antwoord['data'];
    final fout = data is Map ? data[veld] : null;
    final melding = fout is Map ? '${fout['message'] ?? ''}' : '';
    if (melding.isNotEmpty) return melding;
    final algemeen = '${antwoord['message'] ?? ''}';
    return algemeen.isEmpty ? null : algemeen;
  }

  /// 400 draagt de veldfouten in "data". Een leeg "data" bij een
  /// inlogpoging is "Failed to authenticate."; de aanroeper (inloggen)
  /// vertaalt dat verder naar [HhFoutSoort.ongeldigeInlog].
  static HhFoutSoort _soortVoor400(Map<String, dynamic> antwoord) {
    final data = antwoord['data'];
    if (data is! Map || data.isEmpty) return HhFoutSoort.ongeldigeInvoer;
    final email = data['email'];
    if (email is Map && '${email['code']}'.contains('unique')) {
      return HhFoutSoort.emailBestaatAl;
    }
    final adres = data['adres'];
    if (adres is Map && '${adres['code']}'.startsWith('hh_adres')) {
      return HhFoutSoort.adresOngeldig;
    }
    final partner = data['partner_code'];
    if (partner is Map && '${partner['code']}' == 'hh_partner_code') {
      return HhFoutSoort.partnerCode;
    }
    return HhFoutSoort.ongeldigeInvoer;
  }

  /// De zin die de gebruiker te zien krijgt.
  String get melding => switch (soort) {
    HhFoutSoort.geenVerbinding => TekstenNl.foutGeenVerbinding,
    HhFoutSoort.ongeldigeInlog => TekstenNl.foutOngeldigeInlog,
    HhFoutSoort.emailBestaatAl => TekstenNl.foutEmailBestaatAl,
    HhFoutSoort.emailNietBevestigd => TekstenNl.foutEmailNietBevestigd,
    HhFoutSoort.nietIngelogd => TekstenNl.foutSessieVerlopen,
    HhFoutSoort.geenToegang => TekstenNl.foutGeenToegang,
    HhFoutSoort.nietGevonden => TekstenNl.foutNietGevonden,
    HhFoutSoort.ongeldigeInvoer => TekstenNl.foutOngeldigeInvoer,
    HhFoutSoort.adresOngeldig => serverMelding ?? TekstenNl.foutOngeldigeInvoer,
    HhFoutSoort.partnerCode => serverMelding ?? TekstenNl.foutOngeldigeInvoer,
    HhFoutSoort.server => TekstenNl.foutServer,
    HhFoutSoort.onbekend => serverMelding ?? TekstenNl.foutOnbekend,
  };

  bool get isGeenVerbinding => soort == HhFoutSoort.geenVerbinding;

  @override
  String toString() => 'HhFout($soort${detail != null ? ': $detail' : ''})';
}
