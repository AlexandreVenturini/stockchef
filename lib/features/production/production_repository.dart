import 'package:sqflite/sqflite.dart';

import '../../core/database.dart';
import '../../core/units.dart';
import 'production.dart';
import 'production_calculator.dart';

class ProductionRepository {
  ProductionRepository({Future<Database>? database})
    : _database = database ?? AppDatabase.instance;

  final Future<Database> _database;

  Future<int> save({
    required ProductionPlan plan,
    required DateTime date,
    required Unit unit,
  }) async {
    if (!unit.isCompatibleWith(plan.recipe.yieldUnit)) {
      throw ArgumentError.value(
        unit,
        'unit',
        'Unidade incompatível com o rendimento da receita',
      );
    }

    final db = await _database;
    return db.transaction((txn) async {
      final production = Production(
        recipeId: plan.recipe.id,
        recipeName: plan.recipe.name,
        date: date,
        quantity: plan.producedQuantity,
        unit: unit,
        createdAt: DateTime.now(),
      );
      final productionId = await txn.insert('productions', production.toMap());

      for (final consumption in plan.consumptions) {
        final ingredient = consumption.ingredient;
        final item = ProductionItem(
          ingredientId: ingredient.id,
          ingredientName: ingredient.name,
          quantity: consumption.quantity,
          unit: ingredient.unit,
        );
        await txn.insert('production_items', item.toMap(productionId));
        await txn.rawUpdate(
          'UPDATE ingredients SET stock = ROUND(stock - ?, 3) WHERE id = ?',
          [consumption.quantity, ingredient.id],
        );
      }

      final outputId = plan.recipe.outputIngredientId;
      if (outputId != null) {
        final output = ProductionItem(
          ingredientId: outputId,
          ingredientName: plan.recipe.name,
          quantity: -plan.producedQuantity,
          unit: plan.recipe.yieldUnit,
        );
        await txn.insert('production_items', output.toMap(productionId));
        await txn.rawUpdate(
          'UPDATE ingredients SET stock = ROUND(stock + ?, 3) WHERE id = ?',
          [plan.producedQuantity, outputId],
        );
      }

      return productionId;
    });
  }

  Future<void> delete(int id) async {
    final db = await _database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'production_items',
        where: 'production_id = ?',
        whereArgs: [id],
      );

      for (final item in rows.map(ProductionItem.fromMap)) {
        if (item.ingredientId == null) continue;
        await txn.rawUpdate(
          'UPDATE ingredients SET stock = ROUND(stock + ?, 3) WHERE id = ?',
          [item.quantity, item.ingredientId],
        );
      }

      await txn.delete('productions', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<Production>> getHistory() async {
    final db = await _database;
    final productionRows = await db.query(
      'productions',
      orderBy: 'date DESC, created_at DESC',
    );
    final itemRows = await db.query('production_items', orderBy: 'id');

    final itemsByProduction = <int, List<ProductionItem>>{};
    for (final row in itemRows) {
      itemsByProduction
          .putIfAbsent(row['production_id'] as int, () => [])
          .add(ProductionItem.fromMap(row));
    }

    return productionRows
        .map(
          (row) => Production.fromMap(
            row,
            items: itemsByProduction[row['id']] ?? const [],
          ),
        )
        .toList();
  }
}
