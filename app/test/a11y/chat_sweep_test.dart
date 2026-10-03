// B6: het chatscherm in de a11y-sweep (zoals schermen_data_sweep_test):
// geen overloop op 320/390/430 bij 100 en 200 procent tekst, en op 390 bij
// 100 procent de richtlijnen voor labels, tikvlak en contrast. Voor de
// helper (normaal) en de bewoner (groot), met lange berichten en een
// weggefilterd nummer.

import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/core/pb/fake_chat_gateway.dart';
import 'package:heitjehulp_app/core/pb/fake_uitvoer_gateway.dart';
import 'package:heitjehulp_app/features/chat/model/hh_bericht.dart';
import 'package:heitjehulp_app/features/chat/paden_chat.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/theme.dart';

import '../support/hh_jongere_wikkel.dart' show jongereId;
import '../support/hh_uitvoeren_wikkel.dart';
import 'sweep_steun.dart';

const _lang =
    'Hoi! Ik kom zaterdag om tien uur. Moet ik zelf een schaar en '
    'handschoenen meenemen, of liggen die in de schuur naast de fietsen?';

FakeChatGateway _chat() => FakeChatGateway(
  helperVanKlus: {'k-u': jongereId},
  klok: uitvoerNu.toUtc(),
  berichten: [
    for (final (i, afzender) in [jongereId, oudereId, jongereId].indexed)
      HhBericht(
        id: 'b$i',
        klusId: 'k-u',
        afzenderId: afzender,
        helperId: jongereId,
        tekst: i == 1 ? 'Bel me op •••' : _lang,
        soort: HhBerichtSoort.tekst,
        gemaakt: uitvoerNu.subtract(Duration(minutes: 30 - i)),
        gelezenOp: i == 0 ? uitvoerNu : null,
        isGefilterd: i == 1,
      ),
  ],
);

FakeUitvoerGateway _uitvoer(String ik) => FakeUitvoerGateway(
  ikBenId: ik,
  klussen: [uitvoerKlus(id: 'k-u', status: HhKlusStatus.onderweg)],
  logregels: uitvoerLogregels('k-u', HhKlusStatus.onderweg),
);

void main() {
  testWidgets('chatscherm past op 320/390/430 bij 100 en 200%', (tester) async {
    final bevindingen = <String>[
      ...await sweep(
        tester,
        rol: HhRol.jongere,
        paden: [HhPadenChat.chat('k-u')],
        data: SweepData(uitvoer: () => _uitvoer(jongereId), chat: _chat),
      ),
      ...await sweep(
        tester,
        rol: HhRol.hulpvrager,
        paden: [HhPadenChat.chat('k-u')],
        data: SweepData(uitvoer: () => _uitvoer(oudereId), chat: _chat),
      ),
    ];
    expect(bevindingen, isEmpty, reason: bevindingen.join('\n'));
  });
}
