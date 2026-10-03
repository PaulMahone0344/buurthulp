import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/chat/paden_chat.dart';
import 'package:heitjehulp_app/features/coordinator/paden_coordinator.dart';
import 'package:heitjehulp_app/features/meldingen/domein/melding_domein.dart';
import 'package:heitjehulp_app/features/meldingen/model/hh_melding.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/l10n/teksten_chat_nl.dart';

HhMelding _bericht({String klus = 'k1', String titel = ''}) => HhMelding(
  id: 'm1',
  ontvangerId: 'u1',
  soort: HhMeldingSoort.vanCode('bericht'),
  klusId: klus,
  titel: titel,
);

void main() {
  test('soort "bericht" van de server wordt herkend', () {
    expect(_bericht().soort, HhMeldingSoort.bericht);
  });

  test('tik op een chatmelding opent de chat (helper en bewoner)', () {
    expect(doelVan(_bericht(), HhRol.jongere), HhPadenChat.chat('k1'));
    expect(doelVan(_bericht(), HhRol.hulpvrager), HhPadenChat.chat('k1'));
  });

  test('coordinator: naar de klus (de meldkamer-inzage komt in B11)', () {
    expect(
      doelVan(_bericht(), HhRol.coordinator),
      HhPadenCoordinator.klusDetail('k1'),
    );
  });

  test('zonder klus: nergens heen', () {
    expect(doelVan(_bericht(klus: ''), HhRol.jongere), isNull);
  });

  test('titel van de server, anders de terugval', () {
    expect(
      titelVan(_bericht(titel: 'Nieuw bericht van Daan'), HhRol.hulpvrager),
      'Nieuw bericht van Daan',
    );
    expect(titelVan(_bericht(), HhRol.hulpvrager), TekstenChatNl.meldingTitel);
  });
}
