// Lokale proef voor B5: de ECHTE app-code (PocketBaseReactieGateway en
// PocketBaseKlussenGateway) tegen een LOKALE PocketBase 0.25.9 met het
// prod-schema, de rules van 131 en de hooks van deze branch. Nooit tegen
// prod: de test weigert elke URL die niet met http://127.0.0.1 begint.
//
// Draait alleen met twee defines; anders wordt hij overgeslagen:
//   flutter test test/smoke/b5_lokaal_smoke_test.dart \
//     --dart-define=HH_B5_LOKAAL=http://127.0.0.1:8290 \
//     --dart-define=HH_B5_ACCOUNTS=/pad/naar/accounts.json
// accounts.json: {"bewoner":{"email","password"}, "helper":{...},
// "klus":"<id van een open, goedgekeurde klus van de bewoner>"} (het lokale
// opzetscript maakt ze; tijdelijke b5check-accounts).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/pb/auth_gateway.dart';
import 'package:heitjehulp_app/core/pb/klussen_gateway.dart';
import 'package:heitjehulp_app/core/pb/pocketbase_gateway.dart';
import 'package:heitjehulp_app/core/pb/reactie_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/features/reacties/model/hh_reactie.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_gebruiker.dart';
import 'package:heitjehulp_app/theme.dart';
import 'package:pocketbase/pocketbase.dart';

const _url = String.fromEnvironment('HH_B5_LOKAAL');
const _accounts = String.fromEnvironment('HH_B5_ACCOUNTS');

T _ok<T>(Result<T> result) => switch (result) {
  Ok<T>(:final waarde) => waarde,
  Err<T>(:final fout) => throw StateError('mislukt: $fout'),
};

Future<(PocketBaseClientGateway, HhGebruiker)> _als(
  Map<String, dynamic> account,
) async {
  final pb = PocketBaseClientGateway(client: PocketBase(_url));
  final ik = _ok(
    await PocketBaseAuthGateway(pb).inloggen(
      email: account['email'] as String,
      wachtwoord: account['password'] as String,
    ),
  );
  return (pb, ik);
}

void main() {
  final kanDraaien =
      _url.startsWith('http://127.0.0.1') &&
      _accounts.isNotEmpty &&
      File(_accounts).existsSync();

  test(
    'helper reageert, bewoner ziet de kaart en kiest: match, helper ziet hem',
    () async {
      final data =
          jsonDecode(File(_accounts).readAsStringSync())
              as Map<String, dynamic>;
      final klusId = data['klus'] as String;
      final (helperPb, helper) = await _als(data['helper']);
      final (bewonerPb, _) = await _als(data['bewoner']);
      final helperReacties = PocketBaseReactieGateway(helperPb);
      final helperKlussen = PocketBaseKlussenGateway(helperPb);
      final bewonerReacties = PocketBaseReactieGateway(bewonerPb);

      // Vóór: de helper ziet de open klus, nog zonder eigen reactie.
      final voor = _ok(await helperKlussen.klus(klusId));
      expect(voor.isOpen, isTrue);
      expect(voor.mijnReactie, '');

      // "Ik wil helpen" met een berichtje (nummer wordt •••).
      final uit = await helperReacties.reageren(
        klusId,
        bericht: 'Ik kan zaterdag. Bel 06-12345678',
      );
      expect(uit, isA<Gereageerd>());
      expect((uit as Gereageerd).status, HhReactieStatus.open);
      final nog = await helperReacties.reageren(klusId);
      expect((nog as ReageerGeweigerd).reden, 'algereageerd');

      final mijn = _ok(await helperReacties.mijnReacties(helper.id));
      final reactie = mijn.firstWhere((r) => r.klusId == klusId);
      expect(reactie.bericht, 'Ik kan zaterdag. Bel •••');
      expect(reactie.klusSamenvatting, isNotEmpty);
      final naReactie = _ok(await helperKlussen.klus(klusId));
      expect(naReactie.mijnReactie, 'open');
      expect(naReactie.reactiesAantal, 1);

      // De bewoner ziet de kaart: voornaam, nooit de achternaam.
      final kaarten = _ok(await bewonerReacties.reactiesVoorKlus(klusId));
      final kaart = kaarten.single;
      expect(kaart.voornaam, isNot(contains(' ')));
      expect(kaart.niveau, 'Nieuw');
      expect(kaart.bericht, 'Ik kan zaterdag. Bel •••');

      // Kiezen = match.
      final keuze = await bewonerReacties.kiezen(klusId, kaart.reactieId);
      expect(keuze, isA<Gekozen>());
      expect((keuze as Gekozen).helperVoornaam, kaart.voornaam);
      final nogEens = await bewonerReacties.kiezen(klusId, kaart.reactieId);
      expect((nogEens as KiesGeweigerd).reden, 'klusbezet');

      // De helper heeft de klus: exact adres, status geaccepteerd.
      final na = _ok(await helperKlussen.klus(klusId));
      expect(na.status, HhKlusStatus.geaccepteerd);
      expect(na.toegewezenJongereId, helper.id);
      expect(na.isLocatieVaag, isFalse);
      final gekozen = _ok(
        await helperReacties.mijnReacties(helper.id),
      ).firstWhere((r) => r.klusId == klusId);
      expect(gekozen.status, HhReactieStatus.gekozen);

      // "Ik kan nu helpen": aan en uit.
      final aan = _ok(await helperReacties.zetBeschikbaar(true));
      expect(aan, isNotNull);
      expect(
        aan!.isAfter(DateTime.now().add(const Duration(hours: 2))),
        isTrue,
      );
      expect(_ok(await helperReacties.zetBeschikbaar(false)), isNull);
    },
    skip: kanDraaien ? false : 'alleen lokaal (HH_B5_LOKAAL + HH_B5_ACCOUNTS)',
  );
}
