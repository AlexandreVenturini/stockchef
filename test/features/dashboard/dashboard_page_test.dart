import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stockchef/app.dart';
import 'package:stockchef/core/units.dart';
import 'package:stockchef/features/ingredients/ingredient.dart';
import 'package:stockchef/features/ingredients/ingredients_page.dart';
import 'package:stockchef/features/production/production_detail_page.dart';
import 'package:stockchef/features/production/production_calculator.dart';
import 'package:stockchef/features/production/production_repository.dart';
import 'package:stockchef/features/recipes/recipe.dart';

import '../../helpers/test_database.dart';

void main() {
  late Database db;

  setUp(() async => db = await openTestDatabase());

  tearDown(() => closeTestDatabase(db));

  testWidgets('tocar no stat card de ingredientes abre a aba Ingredientes', (
    tester,
  ) async {
    await tester.pumpWidget(const StockChefApp());
    await pumpAndLoad(tester);

    await tester.tap(find.widgetWithText(Card, 'Ingredientes'));
    await pumpAndLoad(tester);

    expect(find.byType(IngredientsPage), findsOneWidget);
  });

  Future<void> seedTodayProduction() async {
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
      date: DateTime.now(),
      unit: Unit.kg,
    );
  }

  testWidgets('tocar numa produção de hoje abre o detalhe', (tester) async {
    await tester.runAsync(seedTodayProduction);

    await tester.pumpWidget(const StockChefApp());
    await pumpAndLoad(tester);

    await tester.scrollUntilVisible(
      find.text('Calda de morango'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await pumpAndLoad(tester);
    await tester.tap(find.text('Calda de morango'));
    await pumpAndLoad(tester);

    expect(find.byType(ProductionDetailPage), findsOneWidget);
  });
}
