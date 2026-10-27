import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stockchef/core/database.dart';

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

  Future<int> insertIngredient(String name) => db.insert('ingredients', {
    'name': name,
    'unit': 'kg',
    'stock': 1000,
  });

  Future<int> insertRecipe() => db.insert('recipes', {
    'name': 'Calda de morango',
    'yield_qty': 1000,
    'yield_unit': 'kg',
  });

  Future<int> insertProduction(int recipeId) => db.insert('productions', {
    'recipe_id': recipeId,
    'recipe_name': 'Calda de morango',
    'date': '2026-10-19',
    'quantity': 2500,
    'unit': 'kg',
    'created_at': '2026-10-19T10:00:00',
  });

  test('cria as 7 tabelas', () async {
    final rows = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'table'",
    );

    expect(
      rows.map((row) => row['name']),
      containsAll([
        'ingredients',
        'recipes',
        'recipe_items',
        'productions',
        'production_items',
        'shopping_lists',
        'shopping_list_items',
      ]),
    );
  });

  test('produção nasce abatendo o estoque por padrão', () async {
    final recipe = await insertRecipe();
    final id = await insertProduction(recipe);

    final rows = await db.query('productions', where: 'id = ?', whereArgs: [id]);
    expect(rows.single['affects_stock'], 1);
  });

  test('excluir lista de compras apaga os itens dela', () async {
    final sugar = await insertIngredient('Açúcar');
    final listId = await db.insert('shopping_lists', {
      'created_at': '2026-10-19T10:00:00',
    });
    await db.insert('shopping_list_items', {
      'list_id': listId,
      'ingredient_id': sugar,
      'ingredient_name': 'Açúcar',
      'quantity': 1000,
      'unit': 'kg',
    });

    await db.delete('shopping_lists', where: 'id = ?', whereArgs: [listId]);

    expect(await db.query('shopping_list_items'), isEmpty);
  });

  test('não deixa excluir ingrediente usado em receita', () async {
    final sugar = await insertIngredient('Açúcar');
    final recipe = await insertRecipe();
    await db.insert('recipe_items', {
      'recipe_id': recipe,
      'ingredient_id': sugar,
      'quantity': 400,
      'unit': 'g',
    });

    await expectLater(
      db.delete('ingredients', where: 'id = ?', whereArgs: [sugar]),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('excluir receita apaga os itens dela', () async {
    final sugar = await insertIngredient('Açúcar');
    final recipe = await insertRecipe();
    await db.insert('recipe_items', {
      'recipe_id': recipe,
      'ingredient_id': sugar,
      'quantity': 400,
      'unit': 'g',
    });

    await db.delete('recipes', where: 'id = ?', whereArgs: [recipe]);

    expect(await db.query('recipe_items'), isEmpty);
  });

  test('excluir receita mantém a produção no histórico', () async {
    final recipe = await insertRecipe();
    await insertProduction(recipe);

    await db.delete('recipes', where: 'id = ?', whereArgs: [recipe]);

    final productions = await db.query('productions');
    expect(productions, hasLength(1));
    expect(productions.first['recipe_id'], isNull);
    expect(productions.first['recipe_name'], 'Calda de morango');
  });

  test('excluir produção apaga o consumo dela', () async {
    final sugar = await insertIngredient('Açúcar');
    final recipe = await insertRecipe();
    final production = await insertProduction(recipe);
    await db.insert('production_items', {
      'production_id': production,
      'ingredient_id': sugar,
      'ingredient_name': 'Açúcar',
      'quantity': 1000,
      'unit': 'kg',
    });

    await db.delete('productions', where: 'id = ?', whereArgs: [production]);

    expect(await db.query('production_items'), isEmpty);
  });

  test('recusa unidade fora da lista', () async {
    await expectLater(
      db.insert('ingredients', {'name': 'Leite', 'unit': 'L', 'stock': 0}),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('recusa receita com rendimento zero', () async {
    await expectLater(
      db.insert('recipes', {
        'name': 'Calda',
        'yield_qty': 0,
        'yield_unit': 'kg',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });
}
