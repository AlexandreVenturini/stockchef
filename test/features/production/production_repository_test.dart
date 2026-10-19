import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stockchef/core/database.dart';
import 'package:stockchef/core/units.dart';
import 'package:stockchef/features/ingredients/ingredient.dart';
import 'package:stockchef/features/production/production_calculator.dart';
import 'package:stockchef/features/production/production_repository.dart';
import 'package:stockchef/features/recipes/recipe.dart';

void main() {
  late Database db;
  late ProductionRepository repository;
  late Recipe syrup;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: AppDatabase.options,
    );
    repository = ProductionRepository(database: Future.value(db));

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
    syrup = Recipe(
      id: recipeId,
      name: draft.name,
      yieldQuantity: draft.yieldQuantity,
      yieldUnit: draft.yieldUnit,
      items: draft.items,
    );
  });

  tearDown(() => db.close());

  Future<List<Ingredient>> loadIngredients() async =>
      (await db.query('ingredients')).map(Ingredient.fromMap).toList();

  Future<double> stockOf(String name) async {
    final rows = await db.query(
      'ingredients',
      where: 'name = ?',
      whereArgs: [name],
    );
    return Ingredient.fromMap(rows.single).stock;
  }

  Future<ProductionPlan> planFor(double producedQuantity) async =>
      planProduction(
        recipe: syrup,
        producedQuantity: producedQuantity,
        ingredients: await loadIngredients(),
      );

  test('salvar abate o estoque de cada ingrediente', () async {
    await repository.save(
      plan: await planFor(2500),
      date: DateTime(2026, 10, 19),
      unit: Unit.kg,
    );

    expect(await stockOf('Morango'), 3500);
    expect(await stockOf('Açúcar'), 2000);
  });

  test('salvar guarda a produção e o consumo no histórico', () async {
    final id = await repository.save(
      plan: await planFor(2500),
      date: DateTime(2026, 10, 19, 15, 30),
      unit: Unit.kg,
    );

    final history = await repository.getHistory();
    final production = history.single;
    expect(production.id, id);
    expect(production.recipeId, syrup.id);
    expect(production.recipeName, 'Calda de morango');
    expect(production.date, DateTime(2026, 10, 19));
    expect(production.quantity, 2500);
    expect(production.unit, Unit.kg);
    expect(production.items, hasLength(2));
    expect(production.items.first.ingredientName, 'Morango');
    expect(production.items.first.quantity, 1500);
  });

  test('salvar com falta deixa o estoque negativo', () async {
    await repository.save(
      plan: await planFor(10000),
      date: DateTime(2026, 10, 19),
      unit: Unit.kg,
    );

    expect(await stockOf('Morango'), -1000);
    expect(await stockOf('Açúcar'), -1000);
  });

  test('excluir devolve o estoque e apaga o consumo', () async {
    final id = await repository.save(
      plan: await planFor(2500),
      date: DateTime(2026, 10, 19),
      unit: Unit.kg,
    );

    await repository.delete(id);

    expect(await stockOf('Morango'), 5000);
    expect(await stockOf('Açúcar'), 3000);
    expect(await repository.getHistory(), isEmpty);
    expect(await db.query('production_items'), isEmpty);
  });

  test('se algo falhar no meio, nada é gravado', () async {
    final ingredients = await loadIngredients();
    const ghost = Ingredient(id: 999, name: 'Fantasma', unit: Unit.kg);
    final brokenRecipe = Recipe(
      id: syrup.id,
      name: syrup.name,
      yieldQuantity: syrup.yieldQuantity,
      yieldUnit: syrup.yieldUnit,
      items: [
        ...syrup.items,
        const RecipeItem(ingredientId: 999, quantity: 100, unit: Unit.g),
      ],
    );
    final plan = planProduction(
      recipe: brokenRecipe,
      producedQuantity: 1000,
      ingredients: [...ingredients, ghost],
    );

    await expectLater(
      repository.save(plan: plan, date: DateTime(2026, 10, 19), unit: Unit.kg),
      throwsA(isA<DatabaseException>()),
    );

    expect(await stockOf('Morango'), 5000);
    expect(await stockOf('Açúcar'), 3000);
    expect(await repository.getHistory(), isEmpty);
  });

  test('histórico vem do dia mais recente para o mais antigo', () async {
    await repository.save(
      plan: await planFor(1000),
      date: DateTime(2026, 10, 18),
      unit: Unit.kg,
    );
    await repository.save(
      plan: await planFor(500),
      date: DateTime(2026, 10, 19),
      unit: Unit.g,
    );

    final history = await repository.getHistory();
    expect(history.map((production) => production.date), [
      DateTime(2026, 10, 19),
      DateTime(2026, 10, 18),
    ]);
  });

  test('recusa unidade incompatível com o rendimento', () async {
    final plan = await planFor(1000);

    await expectLater(
      repository.save(plan: plan, date: DateTime(2026, 10, 19), unit: Unit.un),
      throwsArgumentError,
    );
    expect(await repository.getHistory(), isEmpty);
  });
}
