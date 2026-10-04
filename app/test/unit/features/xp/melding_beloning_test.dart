import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/jongere/klussen/paden_klussen.dart';
import 'package:heitjehulp_app/features/meldingen/domein/melding_domein.dart';
import 'package:heitjehulp_app/features/meldingen/model/hh_melding.dart';
import 'package:heitjehulp_app/features/reacties/model/hh_reactie.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/l10n/teksten_xp_nl.dart';

HhMelding _beloning({String klus = 'k1', String titel = ''}) => HhMelding(
  id: 'm1',
  ontvangerId: 'u1',
  soort: HhMeldingSoort.vanCode('beloning'),
  klusId: klus,
  titel: titel,
);

void main() {
  test('soort "beloning" van de server wordt herkend', () {
    expect(_beloning().soort, HhMeldingSoort.beloning);
  });

  test('tik op een beloning opent het Profiel, ook met een klus erbij', () {
    expect(doelVan(_beloning(), HhRol.jongere), HhPadenKlussen.profiel);
    expect(doelVan(_beloning(klus: ''), HhRol.jongere), HhPadenKlussen.profiel);
  });

  test('zonder titel: terugval "Beloning"', () {
    expect(titelVan(_beloning(), HhRol.jongere), TekstenXpNl.beloningTitel);
    expect(
      titelVan(_beloning(titel: 'Nieuwe badge!'), HhRol.jongere),
      'Nieuwe badge!',
    );
  });

  test('KiesHelper-kaart leest niveau en "Nieuw in de buurt"', () {
    final k = HhReactieKaart.vanJson({
      'reactie': 'r1',
      'helper': 'h1',
      'voornaam': 'Ruud',
      'niveau': 'Ervaren',
      'nieuw_in_de_buurt': false,
    });
    expect(k.niveau, 'Ervaren');
    expect(k.isNieuwInDeBuurt, isFalse);
    expect(
      HhReactieKaart.vanJson({'nieuw_in_de_buurt': true}).isNieuwInDeBuurt,
      isTrue,
    );
  });

  test('Profiel-paden vallen onder de screening-guard', () {
    expect(
      HhPadenKlussen.isKlussenPad('${HhPadenKlussen.profiel}/verdiensten'),
      isTrue,
    );
    expect(HhPadenKlussen.isKlussenPad('/jongere/profielx'), isFalse);
  });
}
