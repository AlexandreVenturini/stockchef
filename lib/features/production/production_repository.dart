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
      final affectsStock = productionAffectsStock(date);
      final production = Production(
        recipeId: plan.recipe.id,
        recipeName: plan.recipe.name,
        date: date,
        quantity: plan.producedQuantity,
        unit: unit,
        createdAt: DateTime.now(),
        affectsStock: affectsStock,
      );
      final productionId = await txn.insert('productions', production.toMap());
      await _applyItems(txn, productionId, plan, affectsStock: affectsStock);
      return productionId;
    });
  }

  /// Substitui os dados de uma produção já registrada: desfaz o efeito
  /// anterior no estoque (se houve) e aplica o novo plano no lugar.
  Future<void> update({
    required int id,
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
    await db.transaction((txn) async {
      final rows = await txn.query(
        'productions',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) {
        throw StateError('Produção não encontrada');
      }
      final existing = Production.fromMap(rows.single);
      if (existing.affectsStock) {
        await _revertItems(txn, id);
      }
      await txn.delete(
        'production_items',
        where: 'production_id = ?',
        whereArgs: [id],
      );

      final affectsStock = productionAffectsStock(date);
      final production = Production(
        id: id,
        recipeId: plan.recipe.id,
        recipeName: plan.recipe.name,
        date: date,
        quantity: plan.producedQuantity,
        unit: unit,
        createdAt: existing.createdAt,
        affectsStock: affectsStock,
      );
      await txn.update(
        'productions',
        production.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
      await _applyItems(txn, id, plan, affectsStock: affectsStock);
    });
  }

  Future<void> delete(int id) async {
    final db = await _database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'productions',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) return;
      if (Production.fromMap(rows.single).affectsStock) {
        await _revertItems(txn, id);
      }
      await txn.delete('productions', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Grava os itens consumidos/produzidos e, se [affectsStock], aplica o
  /// efeito no estoque atual dos ingredientes.
  Future<void> _applyItems(
    DatabaseExecutor txn,
    int productionId,
    ProductionPlan plan, {
    required bool affectsStock,
  }) async {
    for (final consumption in plan.consumptions) {
      final ingredient = consumption.ingredient;
      final item = ProductionItem(
        ingredientId: ingredient.id,
        ingredientName: ingredient.name,
        quantity: consumption.quantity,
        unit: ingredient.unit,
      );
      await txn.insert('production_items', item.toMap(productionId));
      if (affectsStock) {
        await txn.rawUpdate(
          'UPDATE ingredients SET stock = ROUND(stock - ?, 3) WHERE id = ?',
          [consumption.quantity, ingredient.id],
        );
      }
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
      if (affectsStock) {
        await txn.rawUpdate(
          'UPDATE ingredients SET stock = ROUND(stock + ?, 3) WHERE id = ?',
          [plan.producedQuantity, outputId],
        );
      }
    }
  }

  /// Devolve ao estoque o efeito já aplicado pelos itens desta produção.
  Future<void> _revertItems(DatabaseExecutor txn, int productionId) async {
    final rows = await txn.query(
      'production_items',
      where: 'production_id = ?',
      whereArgs: [productionId],
    );
    for (final item in rows.map(ProductionItem.fromMap)) {
      if (item.ingredientId == null) continue;
      await txn.rawUpdate(
        'UPDATE ingredients SET stock = ROUND(stock + ?, 3) WHERE id = ?',
        [item.quantity, item.ingredientId],
      );
    }
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
