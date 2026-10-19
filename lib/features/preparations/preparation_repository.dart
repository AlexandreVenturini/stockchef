import 'package:sqflite/sqflite.dart';

import '../../core/database.dart';
import '../ingredients/ingredient.dart';
import '../recipes/recipe.dart';
import '../recipes/recipe_repository.dart';
import 'preparation.dart';

class PreparationRepository {
  PreparationRepository({Future<Database>? database})
    : _database = database ?? AppDatabase.instance;

  final Future<Database> _database;

  Future<List<Preparation>> getAll() async {
    final db = await _database;
    final recipes = await RecipeRepository(database: _database).getAll();
    final stockRows = await db.query(
      'ingredients',
      where: 'is_preparation = 1',
    );
    final stockById = {
      for (final row in stockRows) row['id'] as int: Ingredient.fromMap(row),
    };

    return [
      for (final recipe in recipes)
        if (stockById[recipe.outputIngredientId] case final stockItem?)
          Preparation(recipe: recipe, stockItem: stockItem),
    ];
  }

  Future<int> save(Recipe recipe) async {
    validateRecipe(recipe);
    final usesItself = recipe.items.any(
      (item) => item.ingredientId == recipe.outputIngredientId,
    );
    if (recipe.outputIngredientId != null && usesItself) {
      throw ArgumentError.value(
        recipe.items,
        'items',
        'O preparo não pode usar ele mesmo',
      );
    }

    final db = await _database;
    return db.transaction((txn) async {
      final int stockId;
      if (recipe.outputIngredientId == null) {
        stockId = await txn.insert(
          'ingredients',
          Ingredient(
            name: recipe.name,
            unit: recipe.yieldUnit,
            isPreparation: true,
          ).toMap(),
        );
      } else {
        stockId = recipe.outputIngredientId!;
        await txn.update(
          'ingredients',
          {'name': recipe.name, 'unit': recipe.yieldUnit.name},
          where: 'id = ?',
          whereArgs: [stockId],
        );
      }

      final recipeMap = {...recipe.toMap(), 'output_ingredient_id': stockId};
      final int recipeId;
      if (recipe.id == null) {
        recipeId = await txn.insert('recipes', recipeMap);
      } else {
        recipeId = recipe.id!;
        await txn.update(
          'recipes',
          recipeMap,
          where: 'id = ?',
          whereArgs: [recipeId],
        );
        await txn.delete(
          'recipe_items',
          where: 'recipe_id = ?',
          whereArgs: [recipeId],
        );
      }

      for (final item in recipe.items) {
        await txn.insert('recipe_items', item.toMap(recipeId));
      }
      return recipeId;
    });
  }

  Future<void> delete(Recipe recipe) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('recipes', where: 'id = ?', whereArgs: [recipe.id]);
      if (recipe.outputIngredientId != null) {
        await txn.delete(
          'ingredients',
          where: 'id = ?',
          whereArgs: [recipe.outputIngredientId],
        );
      }
    });
  }
}
