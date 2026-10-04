// Lokale proef voor B9: de ECHTE app-code (PocketBaseXpGateway en
// PocketBaseReactieGateway-kaart) tegen een LOKALE PocketBase 0.25.9 met het
// prod-schema, de rules van 141 en de hooks van deze branch. Nooit tegen
// prod: de test weigert elke URL die niet met http://127.0.0.1 begint.
//
// Draait alleen met twee defines; anders wordt hij overgeslagen:
//   flutter test test/smoke/b9_lokaal_smoke_test.dart \
//     --dart-define=HH_B9_LOKAAL=http://127.0.0.1:8290 \
//     --dart-define=HH_B9_ACCOUNTS=/pad/naar/seed-accounts.lokaal.json
// accounts.json: de lokale seed-accounts ({"jongere1": {"email",
// "password"}, "hulpvrager1": {...}}); jongere1 heeft afgeronde klussen en
// is nagerekend met 144 --apply.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/pb/auth_gateway.dart';
import 'package:heitjehulp_app/core/pb/pocketbase_gateway.dart';
import 'package:heitjehulp_app/core/pb/xp_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:pocketbase/pocketbase.dart';

const _url = String.fromEnvironment('HH_B9_LOKAAL');
const _accounts = String.fromEnvironment('HH_B9_ACCOUNTS');

T _ok<T>(Result<T> result) => switch (result) {
  Ok<T>(:final waarde) => waarde,
  Err<T>(:final fout) => throw StateError('mislukt: $fout'),
};

Future<PocketBaseClientGateway> _als(Map<String, dynamic> account) async {
  final pb = PocketBaseClientGateway(client: PocketBase(_url));
  _ok(
    await PocketBaseAuthGateway(pb).inloggen(
      email: account['email'] as String,
      wachtwoord: account['password'] as String,
    ),
  );
  return pb;
}

void main() {
  final kanDraaien =
      _url.startsWith('http://127.0.0.1') &&
      _accounts.isNotEmpty &&
      File(_accounts).existsSync();

  test(
    'strijder leest zijn XP-overzicht en maakt een verklaring; bewoner niet',
    () async {
      final data =
          jsonDecode(File(_accounts).readAsStringSync())
              as Map<String, dynamic>;
      final helper = PocketBaseXpGateway(
        await _als(data['jongere1'] as Map<String, dynamic>),
      );
      final o = _ok(await helper.mijnOverzicht());
      expect(o.xpTotaal, greaterThan(0));
      expect(o.niveau.naam, isNotEmpty);
      expect(o.badges, hasLength(7));
      expect(o.badges.where((b) => b.isBehaald), isNotEmpty);
      expect(o.verdiensten.jaren, isNotEmpty);

      final v = _ok(await helper.maakVerklaring());
      expect(v.code, matches(RegExp(r'^[A-Z2-9]{5}-[A-Z2-9]{5}$')));
      expect(v.klussen, o.klussenAantal);
      expect(v.voornaam, isNotEmpty);

      final bewoner = PocketBaseXpGateway(
        await _als(data['hulpvrager1'] as Map<String, dynamic>),
      );
      expect(await bewoner.mijnOverzicht(), isA<Err<dynamic>>());
    },
    skip: kanDraaien ? false : 'alleen lokaal (HH_B9_LOKAAL + HH_B9_ACCOUNTS)',
  );
}
