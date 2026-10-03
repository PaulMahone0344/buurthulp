import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/chat/domein/chat_regels.dart';
import 'package:heitjehulp_app/features/chat/model/hh_bericht.dart';
import 'package:heitjehulp_app/features/jongere/klussen/model/hh_klus.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/model/hh_klus_logregel.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/theme.dart';

final _nu = DateTime(2026, 10, 4, 12);

HhKlus _klus(HhKlusStatus status, {String helper = 'j1'}) => HhKlus(
  id: 'k1',
  hulpvragerId: 'b1',
  status: status,
  toegewezenJongereId: helper,
);

HhKlusLogregel _log(HhKlusStatus naar, DateTime wanneer) => HhKlusLogregel(
  id: 'l-${naar.name}',
  klusId: 'k1',
  naar: naar,
  wanneer: wanneer,
);

HhBericht _bericht(
  String id,
  String afzender,
  DateTime gemaakt, {
  DateTime? gelezen,
  String helper = 'j1',
}) => HhBericht(
  id: id,
  klusId: 'k1',
  afzenderId: afzender,
  helperId: helper,
  tekst: 'tekst $id',
  soort: HhBerichtSoort.tekst,
  gemaakt: gemaakt,
  gelezenOp: gelezen,
);

void main() {
  group('chatStandVan (gelijk aan de server, 72 uur)', () {
    test('zonder helper of bij concept/open: geen chat', () {
      expect(
        chatStandVan(_klus(HhKlusStatus.open, helper: ''), const [], _nu),
        ChatStand.geenHelper,
      );
      expect(
        chatStandVan(_klus(HhKlusStatus.concept), const [], _nu),
        ChatStand.geenHelper,
      );
      expect(
        chatStandVan(
          _klus(HhKlusStatus.geannuleerd, helper: ''),
          const [],
          _nu,
        ),
        ChatStand.geenHelper,
      );
    });

    test('loopt de klus met helper: open', () {
      for (final s in [
        HhKlusStatus.geaccepteerd,
        HhKlusStatus.onderweg,
        HhKlusStatus.bezig,
        HhKlusStatus.probleem,
      ]) {
        expect(
          chatStandVan(_klus(s), const [], _nu),
          ChatStand.open,
          reason: s.name,
        );
      }
    });

    test('afgerond: open tot en met 72 uur na de stap, daarna dicht', () {
      for (final s in [HhKlusStatus.afgerond, HhKlusStatus.geannuleerd]) {
        final klus = _klus(s);
        expect(
          chatStandVan(klus, [
            _log(s, _nu.subtract(const Duration(hours: 71))),
          ], _nu),
          ChatStand.open,
        );
        expect(
          chatStandVan(klus, [_log(s, _nu.subtract(chatDichtNa))], _nu),
          ChatStand.open,
        );
        expect(
          chatStandVan(klus, [
            _log(s, _nu.subtract(chatDichtNa + const Duration(minutes: 1))),
          ], _nu),
          ChatStand.dicht,
        );
      }
    });

    test('afgerond zonder logregel: dicht (liever dicht dan open)', () {
      expect(
        chatStandVan(_klus(HhKlusStatus.afgerond), const [], _nu),
        ChatStand.dicht,
      );
    });

    test('de LAATSTE stap naar de huidige status telt', () {
      final klus = _klus(HhKlusStatus.afgerond);
      final logs = [
        _log(HhKlusStatus.afgerond, _nu.subtract(const Duration(days: 10))),
        _log(HhKlusStatus.afgerond, _nu.subtract(const Duration(hours: 1))),
      ];
      expect(chatStandVan(klus, logs, _nu), ChatStand.open);
    });
  });

  test(
    'heeftChat: knop alleen bij een klus met helper (ook na afloop, om te lezen)',
    () {
      expect(heeftChat(_klus(HhKlusStatus.geaccepteerd)), isTrue);
      expect(heeftChat(_klus(HhKlusStatus.afgerond)), isTrue);
      expect(heeftChat(_klus(HhKlusStatus.open, helper: '')), isFalse);
      expect(heeftChat(_klus(HhKlusStatus.concept)), isFalse);
    },
  );

  test('snelknoppen: helper en bewoner elk hun eigen drie', () {
    expect(snelknoppenVoor(HhRol.jongere), [
      'Ik ben onderweg',
      'Ik ben er',
      'Klaar',
    ]);
    expect(snelknoppenVoor(HhRol.hulpvrager), [
      'Prima!',
      'Ik ben thuis',
      'Bel even aan',
    ]);
    expect(snelknoppenVoor(HhRol.coordinator), isEmpty);
  });

  test('voegIn: vervangt op id, oudste boven, nieuwste onder', () {
    final a = _bericht('a', 'b1', _nu.subtract(const Duration(minutes: 5)));
    final b = _bericht('b', 'j1', _nu);
    final lijst = voegBerichtIn(voegBerichtIn(const [], b), a);
    expect(lijst.map((x) => x.id), ['a', 'b']);
    final aGelezen = a.metGelezenOp(_nu);
    final na = voegBerichtIn(lijst, aGelezen);
    expect(na.map((x) => x.id), ['a', 'b']);
    expect(na.first.isGelezen, isTrue);
  });

  test(
    'indeling: dagkoppen Vandaag / Gisteren / datum, en "Gelezen" alleen bij mijn laatste gelezen bericht',
    () {
      final eergisteren = DateTime(2026, 10, 2, 9, 12);
      final gisteren = DateTime(2026, 10, 3, 18, 0);
      final lijst = [
        _bericht('1', 'j1', eergisteren),
        _bericht('2', 'b1', gisteren, gelezen: gisteren),
        _bericht('3', 'b1', DateTime(2026, 10, 4, 9, 20), gelezen: _nu),
        _bericht('4', 'j1', DateTime(2026, 10, 4, 9, 52)),
      ];
      final regels = chatIndeling(lijst, ikId: 'b1', nu: _nu);
      expect(regels.whereType<ChatDagKop>().map((k) => k.label), [
        'Vrijdag 2 oktober',
        'Gisteren',
        'Vandaag',
      ]);
      final berichten = regels.whereType<ChatBerichtRegel>().toList();
      expect(berichten.map((r) => r.bericht.id), ['1', '2', '3', '4']);
      expect(berichten.where((r) => r.toonGelezen).map((r) => r.bericht.id), [
        '3',
      ]);
      expect(berichten.firstWhere((r) => r.bericht.id == '3').isVanMij, isTrue);
      expect(
        berichten.firstWhere((r) => r.bericht.id == '4').isVanMij,
        isFalse,
      );
    },
  );

  test('ongelezen voor mij: van de ander en zonder gelezen_op', () {
    final lijst = [
      _bericht('1', 'j1', _nu),
      _bericht('2', 'j1', _nu, gelezen: _nu),
      _bericht('3', 'b1', _nu),
    ];
    expect(ongelezenVoor(lijst, 'b1').map((b) => b.id), ['1']);
  });

  test('voornaam en ondertitel van de kop', () {
    expect(chatVoornaam('Daan de Vries'), 'Daan');
    expect(chatVoornaam(''), '');
    expect(
      chatOndertitel('tuin', DateTime(2026, 10, 10, 10), _nu),
      'Tuin · zaterdag 10 oktober 10:00',
    );
    expect(chatOndertitel('tuin', null, _nu), 'Tuin');
    expect(chatOndertitel('', null, _nu), '');
  });
}
