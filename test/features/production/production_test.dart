import 'package:flutter_test/flutter_test.dart';
import 'package:stockchef/core/units.dart';
import 'package:stockchef/features/production/production.dart';

void main() {
  Production production(String recipeName, DateTime date) => Production(
    recipeName: recipeName,
    date: date,
    quantity: 1000,
    unit: Unit.kg,
    createdAt: date,
  );

  test('groupByDay junta as produções do mesmo dia mantendo a ordem', () {
    final productions = [
      production('Calda de morango', DateTime(2026, 10, 19)),
      production('Calda de chocolate', DateTime(2026, 10, 19)),
      production('Calda de caramelo', DateTime(2026, 10, 18)),
    ];

    final days = groupByDay(productions);

    expect(days.keys, [DateTime(2026, 10, 19), DateTime(2026, 10, 18)]);
    expect(
      days[DateTime(2026, 10, 19)]!.map((item) => item.recipeName),
      ['Calda de morango', 'Calda de chocolate'],
    );
    expect(days[DateTime(2026, 10, 18)], hasLength(1));
  });

  test('groupByDay com lista vazia devolve nenhum dia', () {
    expect(groupByDay([]), isEmpty);
  });
}
