// Prod-smoke voor M4: plaatst via de ECHTE app-code (PocketBaseKlusGateway
// + HulpvraagPlaatser-logica) een klus als seed-oudere 1 op
// api.qawayahbase.com, leest hem terug en print het id. Verwijderen kan
// niet (status open; de rule verbiedt dat): het id gaat in OPEN-PUNTEN-M4.
//
// Draait alleen met --dart-define=HH_SMOKE=1 en met
// backend/seed-accounts.local.json aanwezig; anders wordt hij overgeslagen.
// De wachtwoorden komen uit dat bestand en worden nergens gelogd.
//
//   flutter test test/smoke/m4_prod_smoke_test.dart --dart-define=HH_SMOKE=1

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/pb/auth_gateway.dart';
import 'package:heitjehulp_app/core/pb/klus_gateway.dart';
import 'package:heitjehulp_app/core/pb/pocketbase_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/features/hulpvrager/domein/adres.dart';
import 'package:heitjehulp_app/features/hulpvrager/domein/bedragen.dart';
import 'package:heitjehulp_app/features/hulpvrager/domein/wanneer.dart';
import 'package:heitjehulp_app/features/hulpvrager/model/hh_gegevens.dart';
import 'package:heitjehulp_app/features/hulpvrager/model/hh_klustype.dart';
import 'package:heitjehulp_app/features/hulpvrager/model/hulpvraag_concept.dart';
import 'package:heitjehulp_app/features/hulpvrager/model/nieuwe_klus.dart';
import 'package:heitjehulp_app/features/jongere/foto_kiezer.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/model/hh_klus_logregel.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_gebruiker.dart';

const _isSmoke = bool.fromEnvironment('HH_SMOKE');
const _merk = '[m4-smoke]';
const _accountsPad = '../backend/seed-accounts.local.json';
const _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=';

T _ok<T>(Result<T> result) => switch (result) {
  Ok<T>(:final waarde) => waarde,
  Err<T>(:final fout) => throw StateError('mislukt: $fout'),
};

void main() {
  final bestand = File(_accountsPad);
  final kanDraaien = _isSmoke && bestand.existsSync();

  test(
    'seed-oudere plaatst een echte klus met status open via de app-code',
    () async {
      final accounts =
          jsonDecode(bestand.readAsStringSync()) as Map<String, dynamic>;
      final oudere = accounts['hulpvrager1'] as Map<String, dynamic>;

      final pb = PocketBaseClientGateway();
      final auth = PocketBaseAuthGateway(pb);
      final klussen = PocketBaseKlusGateway(pb);

      final gebruiker = _ok<HhGebruiker>(
        await auth.inloggen(
          email: oudere['email'] as String,
          wachtwoord: oudere['password'] as String,
        ),
      );

      final klustypes = _ok<List<HhKlustype>>(await klussen.klustypes());
      expect(klustypes, isNotEmpty);
      final klustype = klustypes.firstWhere(
        (t) => t.naam == 'Boodschappen',
        orElse: () => klustypes.first,
      );

      final gegevens = _ok<HhGegevens>(
        await klussen.mijnGegevens(gebruiker.id),
      );

      // B4: met foto, vinkje en een begintijd morgen om 10:00; de klus
      // begint ongekeurd (de meldkamer keurt).
      final nu = DateTime.now();
      final dag = dagVoorKeuze(HhDagKeuze.morgen, nu)!;
      final concept = HulpvraagConcept(
        klustype: klustype,
        omschrijving:
            '$_merk boodschappen via de app-code, ${nu.toIso8601String()}',
        foto: HhFoto(bytes: base64Decode(_png1x1), bestandsnaam: 'smoke.png'),
        dagKeuze: HhDagKeuze.morgen,
        dag: dag,
        vanafMinuten: standaardVanaf(dag, nu),
        isNeeLijstAkkoord: true,
        adres: gegevens.adres.isEmpty ? 'Smoketeststraat 4' : gegevens.adres,
        postcode: gegevens.postcode.isEmpty ? '4001 AA' : gegevens.postcode,
        plaats: gegevens.plaats.isEmpty ? 'Tiel' : gegevens.plaats,
      );
      final klus = NieuweKlus(
        hulpvragerId: gebruiker.id,
        klustypeId: klustype.id,
        omschrijving: concept.omschrijving,
        adres: stelAdresSamen(
          adres: concept.adres!,
          postcode: concept.postcode!,
          plaats: concept.plaats!,
        ),
        wanneerVan: momentOp(dag, concept.vanafMinuten!),
        bedragen: berekenBedragen(klustype),
        foto: concept.foto!,
      );

      final klusId = _ok<String>(await klussen.klusAanmaken(klus));

      // Teruglezen als de oudere zelf.
      final terug = _ok(
        await pb.voerUit(
          (client) => client.collection(hhKlussenCollectie).getOne(klusId),
        ),
      );
      expect(terug.getStringValue('status'), 'open');
      expect(terug.getStringValue('bron'), 'app');
      expect(terug.getStringValue('klus_goedgekeurd_op'), isEmpty);
      expect(terug.getIntValue('bedrag_bruto'), klustype.richtvergoedingCenten);
      expect(
        terug.getIntValue('vergoeding_jongere'),
        klustype.richtvergoedingCenten,
      );
      expect(terug.getIntValue('commissie'), 0);

      // M6: de hook schrijft de eerste logregel zelf (leeg -> open); de app
      // doet dat niet meer.
      final logs = _ok(
        await pb.voerUit(
          (client) => client
              .collection(HhKlusLogregel.collectie)
              .getFullList(filter: 'klus = "$klusId"'),
        ),
      );

      // Verwijderen mag niet (status open): bewijzen en laten staan.
      final verwijderd = await pb.voerUit(
        (client) => client.collection(hhKlussenCollectie).delete(klusId),
      );
      expect(verwijderd, isA<Err<void>>());

      await auth.uitloggen();

      // Het enige dat naar buiten gaat: het record-id voor OPEN-PUNTEN-M4.
      // ignore: avoid_print
      print(
        'M4-SMOKE klus=$klusId logs=${logs.length} '
        'verwijderen_geweigerd=${verwijderd is Err<void>}',
      );
    },
    skip: kanDraaien
        ? false
        : 'alleen met --dart-define=HH_SMOKE=1 en seed-accounts',
  );
}
