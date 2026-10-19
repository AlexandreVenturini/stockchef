import 'package:sqflite/sqflite.dart';
import '../../core/database.dart';
import '../../core/units.dart';
import 'ingredient.dart';

class IngredientRepository {
  IngredientRepository({Future<Database>? database}) : _database = database ?? AppDatabase.instance;
  final Future<Database> _database;

  Future<List<Ingredient>> getAll() async {
    final db = await _database;
    final rows = await db.query('ingredients', where: 'is_preparation = 0', orderBy: 'name COLLATE NOCASE');
    return rows.map(Ingredient.fromMap).toList();
  }

  Future<int> save(Ingredient item) async {
    if (item.name.trim().isEmpty || !item.stock.isFinite) throw ArgumentError('Informe nome e estoque válidos');
    final db = await _database;
    return db.transaction((txn) async {
      final values = item.toMap()..['name'] = item.name.trim();
      if (item.id == null) return txn.insert('ingredients', values);
      final rows = await txn.query('ingredients', where: 'id = ?', whereArgs: [item.id]);
      if (rows.isEmpty) throw StateError('Ingrediente não encontrado');
      if (!Ingredient.fromMap(rows.single).unit.isCompatibleWith(item.unit)) {
        throw StateError('Não é possível mudar a família da unidade');
      }
      await txn.update('ingredients', values, where: 'id = ?', whereArgs: [item.id]);
      return item.id!;
    });
  }

  Future<void> addStock(int id, double quantity, Unit unit) async {
    if (!quantity.isFinite || quantity <= 0 || unit.toBase(quantity) <= 0) throw ArgumentError('Informe uma quantidade maior que zero');
    final db = await _database;
    await db.transaction((txn) async {
      final rows = await txn.query('ingredients', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) throw StateError('Ingrediente não encontrado');
      if (!Ingredient.fromMap(rows.single).unit.isCompatibleWith(unit)) throw ArgumentError('Unidade incompatível');
      await txn.rawUpdate('UPDATE ingredients SET stock = stock + ? WHERE id = ?', [unit.toBase(quantity), id]);
    });
  }

  Future<void> delete(int id) async {
    final db = await _database;
    await db.transaction((txn) async {
      final used = await txn.rawQuery('SELECT id FROM recipe_items WHERE ingredient_id = ? UNION ALL SELECT id FROM recipes WHERE output_ingredient_id = ? LIMIT 1', [id, id]);
      if (used.isNotEmpty) throw StateError('Não é possível excluir: ingrediente usado em uma receita');
      await txn.delete('ingredients', where: 'id = ?', whereArgs: [id]);
    });
  }
}
