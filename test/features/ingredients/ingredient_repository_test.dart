import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stockchef/core/units.dart';
import 'package:stockchef/features/ingredients/ingredient.dart';
import 'package:stockchef/features/ingredients/ingredient_repository.dart';
import '../../helpers/test_database.dart';

void main() {
  late Database db;
  late IngredientRepository repository;
  setUp(() async {
    db = await openTestDatabase();
    repository = IngredientRepository(database: Future.value(db));
  });
  tearDown(() => closeTestDatabase(db));

  test(
    'salva saldo negativo e soma compras convertidas sem perder entradas',
    () async {
      final id = await repository.save(
        const Ingredient(name: 'Farinha', unit: Unit.kg, stock: -500),
      );
      await Future.wait([
        repository.addStock(id, 1.5, Unit.kg),
        repository.addStock(id, 250, Unit.g),
      ]);
      expect((await repository.getAll()).single.stock, 1250);
      await repository.save(
        Ingredient(id: id, name: 'Farinha fina', unit: Unit.g, stock: 1250),
      );
      expect((await repository.getAll()).single.name, 'Farinha fina');
    },
  );

  test(
    'addStock com preço atualiza o preço por unidade base do ingrediente',
    () async {
      final id = await repository.save(
        const Ingredient(name: 'Farinha', unit: Unit.kg, stock: 0),
      );

      await repository.addStock(id, 2, Unit.kg, totalPrice: 10);
      expect((await repository.getAll()).single.price, closeTo(0.005, 1e-9));

      await repository.addStock(id, 500, Unit.g, totalPrice: 2);
      expect((await repository.getAll()).single.price, closeTo(0.004, 1e-9));
    },
  );

  test('addStock sem preço não altera o preço já guardado', () async {
    final id = await repository.save(
      const Ingredient(name: 'Farinha', unit: Unit.kg, stock: 0, price: 0.01),
    );

    await repository.addStock(id, 1, Unit.kg);

    expect((await repository.getAll()).single.price, 0.01);
  });

  test('recusa compras inválidas e unidade incompatível', () async {
    final id = await repository.save(
      const Ingredient(name: 'Leite', unit: Unit.l),
    );
    for (final quantity in [0.0, -1.0, double.nan, double.infinity]) {
      await expectLater(
        repository.addStock(id, quantity, Unit.l),
        throwsArgumentError,
      );
    }
    await expectLater(repository.addStock(id, 1, Unit.kg), throwsArgumentError);
    expect((await repository.getAll()).single.stock, 0);
  });

  test('bloqueia exclusão em receitas e permite ingrediente livre', () async {
    final id = await repository.save(
      const Ingredient(name: 'Açúcar', unit: Unit.g),
    );
    final recipe = await db.insert('recipes', {
      'name': 'Calda',
      'yield_qty': 1000,
      'yield_unit': 'g',
    });
    await db.insert('recipe_items', {
      'recipe_id': recipe,
      'ingredient_id': id,
      'quantity': 100,
      'unit': 'g',
    });
    await expectLater(repository.delete(id), throwsStateError);
    await db.delete('recipes', where: 'id = ?', whereArgs: [recipe]);
    await repository.delete(id);
    expect(await repository.getAll(), isEmpty);
  });

  test(
    'protege ingredientes de saída de receitas e família ao editar',
    () async {
      final id = await repository.save(
        const Ingredient(name: 'Base', unit: Unit.g),
      );
      await db.insert('recipes', {
        'name': 'Base',
        'yield_qty': 100,
        'yield_unit': 'g',
        'output_ingredient_id': id,
      });
      await expectLater(repository.delete(id), throwsStateError);
      await expectLater(
        repository.save(Ingredient(id: id, name: 'Base', unit: Unit.l)),
        throwsStateError,
      );
    },
  );
}
