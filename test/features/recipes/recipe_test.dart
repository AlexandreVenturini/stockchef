import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stockchef/core/database.dart';
import 'package:stockchef/core/units.dart';
import 'package:stockchef/features/ingredients/ingredient.dart';
import 'package:stockchef/features/recipes/recipe.dart';

void main() {
  late Database db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: AppDatabase.options,
    );
  });

  tearDown(() => db.close());

  test('salva receita com itens e lê de volta do banco', () async {
    final strawberryId = await db.insert(
      'ingredients',
      const Ingredient(name: 'Morango', unit: Unit.kg).toMap(),
    );
    final sugarId = await db.insert(
      'ingredients',
      const Ingredient(name: 'Açúcar', unit: Unit.kg).toMap(),
    );
    final recipe = Recipe(
      name: 'Calda de morango',
      yieldQuantity: Unit.kg.toBase(1),
      yieldUnit: Unit.kg,
      items: [
        RecipeItem(ingredientId: strawberryId, quantity: 600, unit: Unit.g),
        RecipeItem(ingredientId: sugarId, quantity: 400, unit: Unit.g),
      ],
    );

    final recipeId = await db.insert('recipes', recipe.toMap());
    for (final item in recipe.items) {
      await db.insert('recipe_items', item.toMap(recipeId));
    }

    final recipeRow = (await db.query(
      'recipes',
      where: 'id = ?',
      whereArgs: [recipeId],
    )).single;
    final itemRows = await db.query(
      'recipe_items',
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
      orderBy: 'id',
    );
    final saved = Recipe.fromMap(
      recipeRow,
      items: itemRows.map(RecipeItem.fromMap).toList(),
    );

    expect(saved.id, recipeId);
    expect(saved.name, 'Calda de morango');
    expect(saved.yieldQuantity, 1000);
    expect(saved.yieldUnit, Unit.kg);
    expect(saved.outputIngredientId, isNull);
    expect(saved.items, hasLength(2));
    expect(saved.items.first.ingredientId, strawberryId);
    expect(saved.items.first.quantity, 600);
    expect(saved.items.first.unit, Unit.g);
  });

  test('toMap da receita não inclui os itens', () {
    const recipe = Recipe(
      name: 'Calda',
      yieldQuantity: 1000,
      yieldUnit: Unit.kg,
      items: [RecipeItem(ingredientId: 1, quantity: 400, unit: Unit.g)],
    );

    expect(recipe.toMap().containsKey('items'), isFalse);
    expect(recipe.toMap().containsKey('id'), isFalse);
  });
}
