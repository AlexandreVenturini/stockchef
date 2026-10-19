import 'package:flutter_test/flutter_test.dart';
import 'package:stockchef/core/format.dart';
import 'package:stockchef/core/units.dart';

void main() {
  group('parseNumber', () {
    test('aceita vírgula como decimal', () {
      expect(parseNumber('1,5'), 1.5);
    });

    test('aceita ponto como decimal', () {
      expect(parseNumber('1.5'), 1.5);
    });

    test('aceita ponto de milhar junto com vírgula decimal', () {
      expect(parseNumber('1.500,5'), 1500.5);
    });

    test('ignora espaços', () {
      expect(parseNumber(' 2 '), 2);
    });

    test('retorna null para texto inválido', () {
      expect(parseNumber(''), isNull);
      expect(parseNumber('abc'), isNull);
      expect(parseNumber('NaN'), isNull);
      expect(parseNumber('Infinity'), isNull);
    });
  });

  group('formatQuantity', () {
    test('mostra na unidade de exibição com vírgula', () {
      expect(formatQuantity(1500, Unit.kg), '1,5 kg');
    });

    test('usa ponto como separador de milhar', () {
      expect(formatQuantity(2500, Unit.g), '2.500 g');
    });

    test('não mostra casas decimais desnecessárias', () {
      expect(formatQuantity(3, Unit.un), '3 un');
    });

    test('mostra estoque negativo', () {
      expect(formatQuantity(-600, Unit.kg), '-0,6 kg');
    });
  });

  group('datas', () {
    test('formatDate usa dia/mês/ano', () {
      expect(formatDate(DateTime(2026, 10, 19)), '19/10/2026');
    });

    test('toDateKey gera a chave salva no banco', () {
      expect(toDateKey(DateTime(2026, 10, 9, 15, 30)), '2026-10-09');
    });

    test('fromDateKey lê a chave do banco', () {
      expect(fromDateKey('2026-10-09'), DateTime(2026, 10, 9));
    });

    test('formatTime mostra hora e minuto', () {
      expect(formatTime(DateTime(2026, 10, 19, 9, 5)), '09:05');
    });
  });

  group('formatDayLabel', () {
    final today = DateTime(2026, 10, 19, 15, 30);

    test('mostra Hoje para o dia atual', () {
      expect(formatDayLabel(DateTime(2026, 10, 19), today: today), 'Hoje');
    });

    test('mostra Ontem para o dia anterior', () {
      expect(formatDayLabel(DateTime(2026, 10, 18), today: today), 'Ontem');
    });

    test('mostra a data para dias mais antigos', () {
      expect(
        formatDayLabel(DateTime(2026, 10, 17), today: today),
        '17/10/2026',
      );
    });

    test('reconhece Ontem na virada do mês', () {
      expect(
        formatDayLabel(DateTime(2026, 9, 30), today: DateTime(2026, 10, 1)),
        'Ontem',
      );
    });
  });
}
