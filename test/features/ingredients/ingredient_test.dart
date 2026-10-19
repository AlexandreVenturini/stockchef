import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stockchef/core/database.dart';
import 'package:stockchef/core/units.dart';
import 'package:stockchef/features/ingredients/ingredient.dart';

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

  test('salva e lê de volta do banco', () async {
    const sugar = Ingredient(
      name: 'Açúcar',
      unit: Unit.kg,
      stock: 2500,
      minStock: 1000,
    );

    final id = await db.insert('ingredients', sugar.toMap());
    final rows = await db.query('ingredients', where: 'id = ?', whereArgs: [id]);
    final saved = Ingredient.fromMap(rows.single);

    expect(saved.id, id);
    expect(saved.name, 'Açúcar');
    expect(saved.unit, Unit.kg);
    expect(saved.stock, 2500);
    expect(saved.minStock, 1000);
    expect(saved.price, isNull);
  });

  test('toMap sem id deixa o banco gerar o id', () {
    const milk = Ingredient(name: 'Leite', unit: Unit.l);

    expect(milk.toMap().containsKey('id'), isFalse);
    expect(milk.toMap()['unit'], 'l');
  });

  test('isOutOfStock quando o estoque é zero ou negativo', () {
    const base = Ingredient(name: 'Morango', unit: Unit.kg);

    expect(base.isOutOfStock, isTrue);
    expect(
      const Ingredient(name: 'Morango', unit: Unit.kg, stock: -300).isOutOfStock,
      isTrue,
    );
    expect(
      const Ingredient(name: 'Morango', unit: Unit.kg, stock: 500).isOutOfStock,
      isFalse,
    );
  });
}
