import 'package:flutter_test/flutter_test.dart';
import 'package:heitjehulp_app/app/paden.dart';
import 'package:heitjehulp_app/features/toegang/model/hh_rol.dart';
import 'package:heitjehulp_app/features/toegang/validatie.dart';

void main() {
  group('HhRol', () {
    test('rol naar route', () {
      expect(HhRol.hulpvrager.pad, HhPaden.hulpvrager);
      expect(HhRol.jongere.pad, HhPaden.jongere);
      expect(HhRol.familie.pad, HhPaden.familie);
      expect(HhRol.coordinator.pad, HhPaden.coordinator);
      expect(HhPaden.rolPaden, HhRol.values.map((r) => r.pad).toSet());
    });

    test('vanCode volgt de serverwaarden precies', () {
      for (final rol in HhRol.values) {
        expect(HhRol.vanCode(rol.code), rol);
      }
      expect(HhRol.vanCode('Hulpvrager'), isNull);
      expect(HhRol.vanCode(''), isNull);
      expect(HhRol.vanCode(null), isNull);
    });

    test('alleen de coordinator kan niet zelf registreren', () {
      expect(HhRol.coordinator.kanZelfRegistreren, isFalse);
      for (final rol in HhRol.values.where((r) => r != HhRol.coordinator)) {
        expect(rol.kanZelfRegistreren, isTrue, reason: rol.code);
      }
    });
  });

  group('validatie', () {
    test('naam verplicht', () {
      expect(valideerNaam('  '), isNotNull);
      expect(valideerNaam('Fatima'), isNull);
    });

    test('e-mail vorm', () {
      expect(valideerEmail(''), isNotNull);
      expect(valideerEmail('geen-apenstaart'), isNotNull);
      expect(valideerEmail('a@b'), isNotNull);
      expect(valideerEmail(' iemand@voorbeeld.nl '), isNull);
    });

    test('wachtwoord minstens 8 tekens', () {
      expect(valideerWachtwoord('kort'), isNotNull);
      expect(valideerWachtwoord('achtteken'), isNull);
    });
  });
}
