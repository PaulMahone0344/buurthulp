// Lokale proef voor B6: de ECHTE app-code (PocketBaseChatGateway) tegen een
// LOKALE PocketBase 0.25.9 met het prod-schema, de rules van 111 en de
// hooks van deze branch. Nooit tegen prod: de test weigert elke URL die niet
// met http://127.0.0.1 begint.
//
// Draait alleen met twee defines; anders wordt hij overgeslagen:
//   flutter test test/smoke/b6_lokaal_smoke_test.dart \
//     --dart-define=HH_CHAT_LOKAAL=http://127.0.0.1:8096 \
//     --dart-define=HH_CHAT_ACCOUNTS=/pad/naar/accounts.json
// accounts.json: {"bewoner":{"email","password"}, "helper":{...},
// "vreemde":{...}, "klus":"<id van een geaccepteerde klus>"} (een eigen
// klus met bewoner en helper; het lokale opzetscript maakt hem).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/pb/auth_gateway.dart';
import 'package:heitjehulp_app/core/pb/chat_gateway.dart';
import 'package:heitjehulp_app/core/pb/pocketbase_gateway.dart';
import 'package:heitjehulp_app/core/result.dart';
import 'package:heitjehulp_app/features/chat/model/hh_bericht.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_gebruiker.dart';
import 'package:pocketbase/pocketbase.dart';

const _url = String.fromEnvironment('HH_CHAT_LOKAAL');
const _accounts = String.fromEnvironment('HH_CHAT_ACCOUNTS');

T _ok<T>(Result<T> result) => switch (result) {
  Ok<T>(:final waarde) => waarde,
  Err<T>(:final fout) => throw StateError('mislukt: $fout'),
};

Future<(ChatGateway, HhGebruiker)> _als(Map<String, dynamic> account) async {
  final pb = PocketBaseClientGateway(client: PocketBase(_url));
  final ik = _ok(
    await PocketBaseAuthGateway(pb).inloggen(
      email: account['email'] as String,
      wachtwoord: account['password'] as String,
    ),
  );
  return (PocketBaseChatGateway(pb) as ChatGateway, ik);
}

void main() {
  final kanDraaien =
      _url.startsWith('http://127.0.0.1') &&
      _accounts.isNotEmpty &&
      File(_accounts).existsSync();

  test(
    'bewoner en strijder chatten realtime; filter, gelezen, teller, derden niets',
    () async {
      final data =
          jsonDecode(File(_accounts).readAsStringSync())
              as Map<String, dynamic>;
      final klus = data['klus'] as String;
      final (bewonerChat, bewoner) = await _als(data['bewoner']);
      final (helperChat, helper) = await _als(data['helper']);
      final (vreemdeChat, _) = await _als(data['vreemde']);

      // De helper luistert realtime.
      final binnen = Completer<HhBericht>();
      final sub = helperChat.volg(klus).listen((b) {
        if (!binnen.isCompleted && b.afzenderId == bewoner.id) {
          binnen.complete(b);
        }
      });
      await Future<void>.delayed(const Duration(milliseconds: 800));

      final uit = await bewonerChat.verstuur(
        klusId: klus,
        afzenderId: bewoner.id,
        tekst: 'Bel me op 06-12345678, de poort is open',
      );
      expect(uit, isA<Verstuurd>());
      expect(
        (uit as Verstuurd).bericht.tekst,
        'Bel me op •••, de poort is open',
      );
      expect(uit.bericht.isGefilterd, isTrue);
      expect(uit.bericht.helperId, helper.id);

      final realtime = await binnen.future.timeout(const Duration(seconds: 5));
      expect(realtime.tekst, 'Bel me op •••, de poort is open');

      // Teller bij de helper, daarna gelezen.
      expect(_ok(await helperChat.ongelezenPerKlus(helper.id))[klus], 1);
      _ok(await helperChat.markeerGelezen(realtime.id, DateTime.now()));
      expect(_ok(await helperChat.ongelezenPerKlus(helper.id))[klus], isNull);

      // De bewoner kan zijn eigen bericht niet op gelezen zetten.
      expect(
        await bewonerChat.markeerGelezen(realtime.id, DateTime.now()),
        isA<Err<HhBericht>>(),
      );

      // Snelknop van de helper.
      final snel = await helperChat.verstuur(
        klusId: klus,
        afzenderId: helper.id,
        tekst: 'Ik ben onderweg',
        soort: HhBerichtSoort.snel,
      );
      expect((snel as Verstuurd).bericht.soort, HhBerichtSoort.snel);

      final gesprek = _ok(
        await bewonerChat.berichten(klus, helperId: helper.id),
      );
      expect(gesprek.map((b) => b.tekst), [
        'Bel me op •••, de poort is open',
        'Ik ben onderweg',
      ]);
      expect(gesprek.first.isGelezen, isTrue);

      // Een derde ziet niets en kan niet schrijven.
      expect(
        _ok(await vreemdeChat.berichten(klus, helperId: helper.id)),
        isEmpty,
      );
      expect(
        await vreemdeChat.verstuur(
          klusId: klus,
          afzenderId: 'iemand',
          tekst: 'hoi',
        ),
        isA<VerstuurGeweigerd>(),
      );
      await sub.cancel();
    },
    skip: kanDraaien
        ? false
        : 'alleen lokaal met HH_CHAT_LOKAAL en HH_CHAT_ACCOUNTS',
  );
}
