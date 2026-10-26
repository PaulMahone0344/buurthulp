import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/domein/afgerond_overzicht.dart';
import 'package:heitjehulp_app/features/jongere/klussen/model/hh_klus.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/model/hh_klus_logregel.dart';
import 'package:heitjehulp_app/features/jongere/uitvoeren/provider/uitvoeren_providers.dart';
import 'package:heitjehulp_app/l10n/teksten_uitvoeren_nl.dart';
import 'package:heitjehulp_app/theme.dart';

void main() {
  final nu = DateTime(2026, 9, 15, 18); // dinsdag
  final begin = DateTime(2026, 9, 15, 14);

  HhKlus klus({
    String omschrijving = 'Weekboodschappen',
    String adres = 'Dorpsstraat 1, Tiel',
    int bruto = 1000,
    int vergoeding = 1000,
  }) => HhKlus(
    id: 'k',
    hulpvragerId: 'o',
    status: HhKlusStatus.afgerond,
    klustypeNaam: 'boodschappen',
    omschrijving: omschrijving,
    adres: adres,
    bedragBrutoCenten: bruto,
    vergoedingJongereCenten: vergoeding,
    jongereNaam: 'Sanne de Vries',
  );

  HhKlusLogregel log(HhKlusStatus naar, DateTime? wanneer) =>
      HhKlusLogregel(id: naar.name, klusId: 'k', naar: naar, wanneer: wanneer);

  KlusMetGeschiedenis met(
    HhKlus k, {
    Duration duur = const Duration(minutes: 50),
  }) => KlusMetGeschiedenis(
    klus: k,
    logregels: [
      log(HhKlusStatus.bezig, begin),
      log(HhKlusStatus.afgerond, begin.add(duur)),
    ],
  );

  String? waarde(List<OverzichtRegel> regels, String kop) {
    for (final r in regels) {
      if (r.kop == kop) return r.waarde;
    }
    return null;
  }

  group('afgerondOverzicht', () {
    test('alle zeven regels in vaste volgorde', () {
      final regels = afgerondOverzicht(met(klus()), nu);

      expect(regels.map((r) => r.kop), [
        TekstenUitvoerenNl.o7WatKop,
        TekstenUitvoerenNl.o7KlaarKop,
        TekstenUitvoerenNl.o7WaarKop,
        TekstenUitvoerenNl.o7WieKop,
        TekstenUitvoerenNl.o7HoelangKop,
        TekstenUitvoerenNl.o7BedragKop,
        TekstenUitvoerenNl.o7BetalingKop,
      ]);
      expect(waarde(regels, TekstenUitvoerenNl.o7WatKop), 'Weekboodschappen');
      expect(waarde(regels, TekstenUitvoerenNl.o7KlaarKop), 'vandaag om 14:50');
      expect(
        waarde(regels, TekstenUitvoerenNl.o7WaarKop),
        'Dorpsstraat 1, Tiel',
      );
      expect(waarde(regels, TekstenUitvoerenNl.o7WieKop), 'Sanne');
      expect(waarde(regels, TekstenUitvoerenNl.o7HoelangKop), '50 minuten');
      expect(
        waarde(regels, TekstenUitvoerenNl.o7BedragKop),
        TekstenUitvoerenNl.o7BedragVoorbeeld('€ 10,00'),
      );
      expect(
        waarde(regels, TekstenUitvoerenNl.o7BetalingKop),
        TekstenUitvoerenNl.o7BetalingLater,
      );
    });

    test('zonder omschrijving: het klustype met hoofdletter', () {
      final regels = afgerondOverzicht(met(klus(omschrijving: '')), nu);
      expect(waarde(regels, TekstenUitvoerenNl.o7WatKop), 'Boodschappen');
    });

    test('geen bruto bedrag: valt terug op de vergoeding', () {
      final regels = afgerondOverzicht(
        met(klus(bruto: 0, vergoeding: 750)),
        nu,
      );
      expect(
        waarde(regels, TekstenUitvoerenNl.o7BedragKop),
        TekstenUitvoerenNl.o7BedragVoorbeeld('€ 7,50'),
      );
    });

    test('wat ontbreekt valt weg in plaats van een lege regel', () {
      final zonder = KlusMetGeschiedenis(
        klus: klus(adres: '', bruto: 0, vergoeding: 0),
        logregels: const [],
      );
      final koppen = afgerondOverzicht(zonder, nu).map((r) => r.kop);

      expect(koppen, isNot(contains(TekstenUitvoerenNl.o7WaarKop)));
      expect(koppen, isNot(contains(TekstenUitvoerenNl.o7KlaarKop)));
      expect(koppen, isNot(contains(TekstenUitvoerenNl.o7HoelangKop)));
      expect(koppen, isNot(contains(TekstenUitvoerenNl.o7BedragKop)));
      expect(koppen, contains(TekstenUitvoerenNl.o7BetalingKop));
    });
  });

  group('duurTekst', () {
    test('minuten, uren en een mix', () {
      expect(duurTekst(const Duration(seconds: 30)), 'minder dan een minuut');
      expect(duurTekst(const Duration(minutes: 1)), '1 minuut');
      expect(duurTekst(const Duration(minutes: 45)), '45 minuten');
      expect(duurTekst(const Duration(hours: 1)), '1 uur');
      expect(
        duurTekst(const Duration(hours: 2, minutes: 1)),
        '2 uur en 1 minuut',
      );
      expect(
        duurTekst(const Duration(hours: 1, minutes: 20)),
        '1 uur en 20 minuten',
      );
    });
  });
}
