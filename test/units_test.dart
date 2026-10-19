import 'package:flutter_test/flutter_test.dart';
import 'package:stockchef/core/units.dart';

void main() {
  group('toBase', () {
    test('converte kg para g', () {
      expect(Unit.kg.toBase(1.5), 1500);
    });

    test('converte L para ml', () {
      expect(Unit.l.toBase(2), 2000);
    });

    test('mantém g, ml e un', () {
      expect(Unit.g.toBase(250), 250);
      expect(Unit.ml.toBase(80), 80);
      expect(Unit.un.toBase(12), 12);
    });

    test('corrige erro de ponto flutuante', () {
      expect(1.005 * 1000, isNot(1005));
      expect(Unit.kg.toBase(1.005), 1005);
    });
  });

  group('fromBase', () {
    test('converte g para kg', () {
      expect(Unit.kg.fromBase(1500), 1.5);
    });

    test('converte ml para L', () {
      expect(Unit.l.fromBase(250), 0.25);
    });

    test('ida e volta devolve o mesmo valor', () {
      expect(Unit.kg.fromBase(Unit.kg.toBase(0.35)), 0.35);
    });
  });

  group('compatibilidade', () {
    test('kg e g são da mesma família', () {
      expect(Unit.kg.isCompatibleWith(Unit.g), isTrue);
    });

    test('kg e un não são compatíveis', () {
      expect(Unit.kg.isCompatibleWith(Unit.un), isFalse);
    });

    test('compatibleUnits lista só a mesma família', () {
      expect(Unit.g.compatibleUnits, [Unit.kg, Unit.g]);
      expect(Unit.ml.compatibleUnits, [Unit.l, Unit.ml]);
      expect(Unit.un.compatibleUnits, [Unit.un]);
    });
  });

  test('lê a unidade salva no banco pelo nome', () {
    expect(Unit.values.byName(Unit.l.name), Unit.l);
  });
}
