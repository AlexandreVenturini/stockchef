import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stockchef/core/theme.dart';
import 'package:stockchef/core/units.dart';
import 'package:stockchef/features/ingredients/ingredient.dart';
import 'package:stockchef/features/production/production_calculator.dart';
import 'package:stockchef/features/production/production_history_page.dart';
import 'package:stockchef/features/production/production_repository.dart';
import 'package:stockchef/features/recipes/recipe.dart';

import '../../helpers/test_database.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await openTestDatabase();

    final strawberryId = await db.insert(
      'ingredients',
      const Ingredient(name: 'Morango', unit: Unit.kg, stock: 5000).toMap(),
    );
    final sugarId = await db.insert(
      'ingredients',
      const Ingredient(name: 'Açúcar', unit: Unit.kg, stock: 3000).toMap(),
    );
    final draft = Recipe(
      name: 'Calda de morango',
      yieldQuantity: 1000,
      yieldUnit: Unit.kg,
      items: [
        RecipeItem(ingredientId: strawberryId, quantity: 600, unit: Unit.g),
        RecipeItem(ingredientId: sugarId, quantity: 400, unit: Unit.g),
      ],
    );
    final recipeId = await db.insert('recipes', draft.toMap());
    for (final item in draft.items) {
      await db.insert('recipe_items', item.toMap(recipeId));
    }

    final ingredients = (await db.query(
      'ingredients',
    )).map(Ingredient.fromMap).toList();
    final plan = planProduction(
      recipe: Recipe(
        id: recipeId,
        name: draft.name,
        yieldQuantity: draft.yieldQuantity,
        yieldUnit: draft.yieldUnit,
        items: draft.items,
      ),
      producedQuantity: 2500,
      ingredients: ingredients,
    );
    await ProductionRepository().save(
      plan: plan,
      date: DateTime(2020, 10, 18),
      unit: Unit.kg,
    );
  });

  tearDown(() => closeTestDatabase(db));

  Future<double> stockOf(WidgetTester tester, String name) async {
    final rows = await tester.runAsync(
      () => db.query('ingredients', where: 'name = ?', whereArgs: [name]),
    );
    return Ingredient.fromMap(rows!.single).stock;
  }

  testWidgets('histórico mostra a produção agrupada pelo dia', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const ProductionHistoryPage()),
    );
    await pumpAndLoad(tester);

    expect(find.text('18/10/2020'), findsOneWidget);
    expect(find.text('Calda de morango'), findsOneWidget);
    expect(find.text('2,5 kg'), findsOneWidget);
  });

  testWidgets('detalhe mostra o consumo e excluir devolve o estoque', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const ProductionHistoryPage()),
    );
    await pumpAndLoad(tester);

    await tester.tap(find.text('Calda de morango'));
    await pumpAndLoad(tester);

    expect(find.text('Ingredientes consumidos'), findsOneWidget);
    expect(find.text('Morango'), findsOneWidget);
    expect(find.text('1,5 kg'), findsOneWidget);
    expect(find.text('Açúcar'), findsOneWidget);
    expect(find.text('1 kg'), findsOneWidget);
    expect(await stockOf(tester, 'Morango'), 3500);

    await tester.tap(find.text('Excluir produção'));
    await pumpAndLoad(tester);
    expect(find.text('Excluir produção?'), findsOneWidget);

    await tester.tap(find.text('Excluir'));
    await pumpAndLoad(tester);

    expect(find.textContaining('Nenhuma produção registrada'), findsOneWidget);
    expect(await stockOf(tester, 'Morango'), 5000);
    expect(await stockOf(tester, 'Açúcar'), 3000);
  });
}
