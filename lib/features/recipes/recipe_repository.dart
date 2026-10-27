import 'package:sqflite/sqflite.dart';

import '../../core/database.dart';
import '../ingredients/ingredient.dart';
import 'recipe.dart';

class RecipeRepository {
  RecipeRepository({Future<Database>? database})
    : _database = database ?? AppDatabase.instance;

  final Future<Database> _database;

  /// Todas as receitas, em ordem alfabética, já com seus itens e etapas.
  Future<List<Recipe>> getAll() async {
    final db = await _database;
    final recipeRows = await db.query(
      'recipes',
      orderBy: 'name COLLATE NOCASE',
    );
    final itemRows = await db.query('recipe_items', orderBy: 'id');
    final stepRows = await db.query('recipe_steps', orderBy: 'position');

    final itemsByRecipe = <int, List<RecipeItem>>{};
    for (final row in itemRows) {
      itemsByRecipe
          .putIfAbsent(row['recipe_id'] as int, () => [])
          .add(RecipeItem.fromMap(row));
    }
    final stepsByRecipe = <int, List<RecipeStep>>{};
    for (final row in stepRows) {
      stepsByRecipe
          .putIfAbsent(row['recipe_id'] as int, () => [])
          .add(RecipeStep.fromMap(row));
    }

    return recipeRows
        .map(
          (row) => Recipe.fromMap(
            row,
            items: itemsByRecipe[row['id']] ?? const [],
            steps: stepsByRecipe[row['id']] ?? const [],
          ),
        )
        .toList();
  }

  Future<Recipe?> getById(int id) async {
    final db = await _database;
    final rows = await db.query('recipes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final itemRows = await db.query(
      'recipe_items',
      where: 'recipe_id = ?',
      whereArgs: [id],
      orderBy: 'id',
    );
    final stepRows = await db.query(
      'recipe_steps',
      where: 'recipe_id = ?',
      whereArgs: [id],
      orderBy: 'position',
    );
    return Recipe.fromMap(
      rows.single,
      items: itemRows.map(RecipeItem.fromMap).toList(),
      steps: stepRows.map(RecipeStep.fromMap).toList(),
    );
  }

  /// Insere a receita (sem id) ou atualiza (com id), junto com os itens e as
  /// etapas. Tudo na mesma transação: ou salva a receita inteira, ou nada.
  /// Retorna o id da receita.
  Future<int> save(Recipe recipe) async {
    validateRecipe(recipe);

    final db = await _database;
    return db.transaction((txn) async {
      final int recipeId;
      if (recipe.id == null) {
        recipeId = await txn.insert('recipes', recipe.toMap());
      } else {
        recipeId = recipe.id!;
        await txn.update(
          'recipes',
          recipe.toMap(),
          where: 'id = ?',
          whereArgs: [recipeId],
        );
        await txn.delete(
          'recipe_items',
          where: 'recipe_id = ?',
          whereArgs: [recipeId],
        );
        await txn.delete(
          'recipe_steps',
          where: 'recipe_id = ?',
          whereArgs: [recipeId],
        );
      }

      for (final item in recipe.items) {
        await txn.insert('recipe_items', item.toMap(recipeId));
      }
      for (final step in recipe.steps) {
        await txn.insert('recipe_steps', step.toMap(recipeId));
      }
      return recipeId;
    });
  }

  /// Exclui a receita e seus itens/etapas (cascade). As produções já
  /// registradas continuam no histórico, apenas sem o vínculo com a receita.
  Future<void> delete(int id) async {
    final db = await _database;
    await db.delete('recipes', where: 'id = ?', whereArgs: [id]);
  }

  /// Ingredientes cadastrados, para escolher na receita (somente leitura).
  Future<List<Ingredient>> getIngredients() async {
    final db = await _database;
    final rows = await db.query('ingredients', orderBy: 'name COLLATE NOCASE');
    return rows.map(Ingredient.fromMap).toList();
  }
}

void validateRecipe(Recipe recipe) {
  if (recipe.name.trim().isEmpty) {
    throw ArgumentError.value(recipe.name, 'name', 'Informe o nome');
  }
  if (recipe.yieldQuantity <= 0) {
    throw ArgumentError.value(
      recipe.yieldQuantity,
      'yieldQuantity',
      'O rendimento precisa ser maior que zero',
    );
  }
  final ids = recipe.items.map((item) => item.ingredientId).toSet();
  if (ids.length != recipe.items.length) {
    throw ArgumentError.value(
      recipe.items,
      'items',
      'Ingrediente repetido na receita',
    );
  }
}
