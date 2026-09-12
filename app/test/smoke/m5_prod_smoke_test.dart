// Prod-smoke voor M5: seed-jongere 1 haalt via de ECHTE app-code
// (PocketBaseKlussenGateway) de open klussen in zijn wijk op en accepteert
// seed-klus k11 via de hook-route /api/hh/klussen/{id}/accepteren. Daarna
// leest hij de klus terug (naam en adres van de oudere zijn nu zichtbaar)
// en ziet hem bij mijn klussen. Terugzetten gebeurt NIET hier maar met:
//   node backend/scripts/11-accepteercheck.mjs --apply --alleen-terugzetten
//
// Draait alleen met --dart-define=HH_SMOKE=true en met
// backend/seed-accounts.local.json aanwezig; anders wordt hij overgeslagen.
// De wachtwoorden komen uit dat bestand en worden nergens gelogd.
//
//   flutter test test/smoke/m5_prod_smoke_test.dart --dart-define=HH_SMOKE=true

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/pb/auth_gateway.dart';
import 'package:heitjehulp_app/core/pb/klussen_gateway.dart';
import 'package:heitjehulp_app/core/pb/pocketbase_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/features/jongere/klussen/model/hh_klus.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_gebruiker.dart';
import 'package:heitjehulp_app/theme.dart';

const _isSmoke = bool.fromEnvironment('HH_SMOKE');
const _accountsPad = '../backend/seed-accounts.local.json';
const _doelMerk = '[seed k11]';

T _ok<T>(Result<T> result) => switch (result) {
  Ok<T>(:final waarde) => waarde,
  Err<T>(:final fout) => throw StateError('mislukt: $fout'),
};

void main() {
  final bestand = File(_accountsPad);
  final kanDraaien = _isSmoke && bestand.existsSync();

  test(
    'seed-jongere 1 haalt de lijst op en accepteert k11 via de hook-route',
    () async {
      final accounts =
          jsonDecode(bestand.readAsStringSync()) as Map<String, dynamic>;
      final jongere = accounts['jongere1'] as Map<String, dynamic>;

      final pb = PocketBaseClientGateway();
      final auth = PocketBaseAuthGateway(pb);
      final klussen = PocketBaseKlussenGateway(pb);

      final gebruiker = _ok<HhGebruiker>(
        await auth.inloggen(
          email: jongere['email'] as String,
          wachtwoord: jongere['password'] as String,
        ),
      );

      final open = _ok<List<HhKlus>>(await klussen.openKlussen());
      expect(open, isNotEmpty);
      final doel = open.firstWhere((k) => k.omschrijving.startsWith(_doelMerk));
      expect(doel.isOpen, isTrue);
      // Let op: seed-jongere 1 staat al op k04/k07 van dezelfde oudere en
      // ziet haar daardoor al (hh_users-rule); de app toont naam en adres
      // toch pas na accepteren (OPEN-PUNTEN-M5).
      final oudereAlZichtbaar = doel.isOudereZichtbaar;
      expect(doel.klustypeNaam, isNotEmpty);
      final metLocatie = open.where((k) => k.heeftCoordinaten).length;

      final uitkomst = await klussen.accepteren(doel.id);
      expect(uitkomst, isA<Geaccepteerd>(), reason: '$uitkomst');

      final terug = _ok<HhKlus>(await klussen.klus(doel.id));
      expect(terug.status, HhKlusStatus.geaccepteerd);
      expect(terug.isToegewezenAan(gebruiker.id), isTrue);
      expect(terug.isOudereZichtbaar, isTrue);
      expect(terug.adres, isNotEmpty);

      final mijn = _ok<List<HhKlus>>(await klussen.mijnKlussen(gebruiker.id));
      expect(mijn.map((k) => k.id), contains(doel.id));

      final nogmaals = await klussen.accepteren(doel.id);
      expect(nogmaals, isA<Geweigerd>());
      expect((nogmaals as Geweigerd).reden, AccepteerReden.bezet);

      await auth.uitloggen();

      // ignore: avoid_print
      print(
        'M5-SMOKE open=${open.length} metLocatie=$metLocatie '
        'oudereAlZichtbaarVooraf=$oudereAlZichtbaar '
        'geaccepteerd=${doel.id} oudere="${terug.oudereNaam}" '
        'mijn=${mijn.length} tweedeKeer409=${nogmaals.reden}',
      );
    },
    skip: kanDraaien
        ? false
        : 'alleen met --dart-define=HH_SMOKE=true en seed-accounts',
  );
}
