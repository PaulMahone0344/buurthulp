// Lokale proef voor B11: de ECHTE PocketBaseMeldkamerGateway tegen een LOKALE
// PocketBase 0.25.9 met het prod-schema, 150/151 en de hooks van deze
// branch. Nooit tegen prod: de test weigert elke URL die niet met
// http://127.0.0.1 begint.
//
// Draait alleen met twee defines; anders wordt hij overgeslagen:
//   flutter test test/smoke/b11_lokaal_smoke_test.dart \
//     --dart-define=HH_B11_LOKAAL=http://127.0.0.1:8290 \
//     --dart-define=HH_B11_ACCOUNTS=/pad/naar/seed-accounts.lokaal.json

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/pb/auth_gateway.dart';
import 'package:heitjehulp_app/core/pb/meldkamer_gateway.dart';
import 'package:heitjehulp_app/core/pb/pocketbase_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/features/coordinator/model/hh_te_doen.dart';
import 'package:pocketbase/pocketbase.dart';

const _url = String.fromEnvironment('HH_B11_LOKAAL');
const _accounts = String.fromEnvironment('HH_B11_ACCOUNTS');

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
    'meldkamer laadt Te doen, vinkt een kennismaking af; 409 met melding',
    () async {
      final data =
          jsonDecode(File(_accounts).readAsStringSync())
              as Map<String, dynamic>;
      final meldkamer = PocketBaseMeldkamerGateway(
        await _als(data['coordinator1'] as Map<String, dynamic>),
      );
      final t = _ok(await meldkamer.teDoen());
      expect(t.totaal, greaterThanOrEqualTo(0));

      // De bewoner bestaat lokaal; gesproken kan altijd opnieuw.
      final bewoner = PocketBaseClientGateway(client: PocketBase(_url));
      final b = _ok(
        await PocketBaseAuthGateway(bewoner).inloggen(
          email: (data['hulpvrager1'] as Map)['email'] as String,
          wachtwoord: (data['hulpvrager1'] as Map)['password'] as String,
        ),
      );
      final uit = _ok(
        await meldkamer.kennismaking(
          b.id,
          KennismakingBesluit.gesproken,
          'smoke b11',
        ),
      );
      expect(uit.geannuleerd, 0);

      // Een helper is geen bewoner: 409 met de Nederlandse melding.
      final helper = PocketBaseClientGateway(client: PocketBase(_url));
      final h = _ok(
        await PocketBaseAuthGateway(helper).inloggen(
          email: (data['jongere1'] as Map)['email'] as String,
          wachtwoord: (data['jongere1'] as Map)['password'] as String,
        ),
      );
      final fout = await meldkamer.kennismaking(
        h.id,
        KennismakingBesluit.gesproken,
        '',
      );
      expect(
        (fout as Err<KennismakingUitkomst>).fout.melding,
        'Een kennismaking is alleen voor bewoners.',
      );

      // De bewoner zelf mag Te doen niet: geen bellijst van anderen.
      final alsBewoner = PocketBaseMeldkamerGateway(bewoner);
      final eigen = _ok(await alsBewoner.teDoen());
      expect(eigen.bellen.where((x) => x.id != b.id), isEmpty);
      expect(eigen.helpers, isEmpty);
    },
    skip: kanDraaien ? false : 'alleen met HH_B11_LOKAAL en HH_B11_ACCOUNTS',
  );
}
