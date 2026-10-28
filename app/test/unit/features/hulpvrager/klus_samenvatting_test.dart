import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/domein/afgerond_overzicht.dart';
import 'package:heitjehulp_app/features/hulpvrager/status/domein/klus_samenvatting.dart';
import 'package:heitjehulp_app/features/jongere/klussen/model/hh_klus.dart';
import 'package:heitjehulp_app/l10n/teksten_uitvoeren_nl.dart';
import 'package:heitjehulp_app/theme.dart';

void main() {
  final nu = DateTime(2026, 9, 15, 10); // dinsdag
  final van = DateTime(2026, 9, 15, 14);

  HhKlus klus({
    String omschrijving = 'Weekboodschappen',
    String adres = 'Dorpsstraat 1, Tiel',
    DateTime? wanneerVan,
    int bruto = 1000,
    int vergoeding = 1000,
  }) => HhKlus(
    id: 'k',
    hulpvragerId: 'o',
    status: HhKlusStatus.open,
    klustypeNaam: 'boodschappen',
    omschrijving: omschrijving,
    adres: adres,
    wanneerVan: wanneerVan,
    wanneerTot: wanneerVan?.add(const Duration(hours: 1)),
    bedragBrutoCenten: bruto,
    vergoedingJongereCenten: vergoeding,
  );

  String? waarde(List<OverzichtRegel> regels, String kop) {
    for (final r in regels) {
      if (r.kop == kop) return r.waarde;
    }
    return null;
  }

  group('klusSamenvatting', () {
    test('wat, wanneer, waar en hoeveel in vaste volgorde', () {
      final regels = klusSamenvatting(klus(wanneerVan: van), nu);

      expect(regels.map((r) => r.kop), [
        TekstenUitvoerenNl.o7WatKop,
        TekstenUitvoerenNl.o7WanneerKop,
        TekstenUitvoerenNl.o7WaarKop,
        TekstenUitvoerenNl.o7HoeveelKop,
      ]);
      expect(waarde(regels, TekstenUitvoerenNl.o7WatKop), 'Weekboodschappen');
      expect(waarde(regels, TekstenUitvoerenNl.o7WanneerKop), isNotEmpty);
      expect(
        waarde(regels, TekstenUitvoerenNl.o7HoeveelKop),
        TekstenUitvoerenNl.o7BedragVoorbeeld('€ 10,00'),
      );
    });

    test('zonder tijd: "Nog geen tijd afgesproken"', () {
      final regels = klusSamenvatting(klus(), nu);
      expect(
        waarde(regels, TekstenUitvoerenNl.o7WanneerKop),
        TekstenUitvoerenNl.o7GeenTijd,
      );
    });

    test('zonder omschrijving: het klustype met hoofdletter', () {
      final regels = klusSamenvatting(klus(omschrijving: ''), nu);
      expect(waarde(regels, TekstenUitvoerenNl.o7WatKop), 'Boodschappen');
    });

    test('geen adres en geen bedrag: die regels vallen weg', () {
      final koppen = klusSamenvatting(
        klus(adres: '', bruto: 0, vergoeding: 0),
        nu,
      ).map((r) => r.kop);

      expect(koppen, isNot(contains(TekstenUitvoerenNl.o7WaarKop)));
      expect(koppen, isNot(contains(TekstenUitvoerenNl.o7HoeveelKop)));
    });
  });

  group('beoordeelKlusRegels', () {
    test('wat en wie, zonder tijd of bedrag', () {
      final metJongere = HhKlus(
        id: 'k',
        hulpvragerId: 'o',
        status: HhKlusStatus.afgerond,
        klustypeNaam: 'boodschappen',
        omschrijving: 'Weekboodschappen',
        wanneerVan: van,
        vergoedingJongereCenten: 1000,
        jongereNaam: 'Sanne de Vries',
      );
      final regels = beoordeelKlusRegels(metJongere);

      expect(regels.map((r) => r.kop), [
        TekstenUitvoerenNl.o7WatKop,
        TekstenUitvoerenNl.o7WieKop,
      ]);
      expect(waarde(regels, TekstenUitvoerenNl.o7WieKop), 'Sanne');
      expect(regels.any((r) => r.waarde.contains(RegExp(r'\d'))), isFalse);
    });
  });
}
