import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stockchef/core/database.dart';
import 'package:stockchef/core/units.dart';
import 'package:stockchef/features/ingredients/ingredient.dart';
import 'package:stockchef/features/ingredients/shopping_list.dart';
import 'package:stockchef/features/ingredients/shopping_list_repository.dart';

void main() {
  late Database db;
  late ShoppingListRepository repository;
  late int flourId;
  late int sugarId;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: AppDatabase.options,
    );
    repository = ShoppingListRepository(database: Future.value(db));

    flourId = await db.insert(
      'ingredients',
      const Ingredient(name: 'Farinha', unit: Unit.kg, stock: 1000).toMap(),
    );
    sugarId = await db.insert(
      'ingredients',
      const Ingredient(name: 'Açúcar', unit: Unit.kg, stock: 500).toMap(),
    );
  });

  tearDown(() => db.close());

  Future<double> stockOf(int id) async {
    final rows = await db.query(
      'ingredients',
      where: 'id = ?',
      whereArgs: [id],
    );
    return Ingredient.fromMap(rows.single).stock;
  }

  List<ShoppingListItem> draftItems() => [
    ShoppingListItem(
      ingredientId: flourId,
      ingredientName: 'Farinha',
      quantity: 2000,
      unit: Unit.kg,
    ),
    ShoppingListItem(
      ingredientId: sugarId,
      ingredientName: 'Açúcar',
      quantity: 1000,
      unit: Unit.kg,
    ),
  ];

  test('cria a lista com os itens, ainda sem fechar', () async {
    final id = await repository.create(draftItems());

    final list = await repository.getById(id);
    expect(list, isNotNull);
    expect(list!.isClosed, isFalse);
    expect(list.items, hasLength(2));
    expect(list.checkedCount, 0);
  });

  test('recusa criar lista sem itens', () async {
    await expectLater(repository.create([]), throwsArgumentError);
  });

  test('marcar um item soma a quantidade no estoque', () async {
    final id = await repository.create(draftItems());
    final list = await repository.getById(id);
    final flourItem = list!.items.first;

    await repository.setChecked(id, flourItem.id!, true);

    expect(await stockOf(flourId), 3000);
    final reloaded = await repository.getById(id);
    expect(reloaded!.items.first.checked, isTrue);
    expect(reloaded.isClosed, isFalse);
  });

  test(
    'marcar com preço pago atualiza o preço por unidade do ingrediente',
    () async {
      final id = await repository.create(draftItems());
      final list = await repository.getById(id);
      final flourItem = list!.items.first;

      await repository.setChecked(id, flourItem.id!, true, pricePaid: 10);

      final reloaded = await repository.getById(id);
      expect(reloaded!.items.first.pricePaid, 10);
      final flourRows = await db.query(
        'ingredients',
        where: 'id = ?',
        whereArgs: [flourId],
      );
      expect(
        Ingredient.fromMap(flourRows.single).price,
        closeTo(10 / 2000, 1e-9),
      );
    },
  );

  test('marcar sem preço não altera o preço do ingrediente', () async {
    await db.update(
      'ingredients',
      {'price': 0.02},
      where: 'id = ?',
      whereArgs: [flourId],
    );
    final id = await repository.create(draftItems());
    final list = await repository.getById(id);

    await repository.setChecked(id, list!.items.first.id!, true);

    final flourRows = await db.query(
      'ingredients',
      where: 'id = ?',
      whereArgs: [flourId],
    );
    expect(Ingredient.fromMap(flourRows.single).price, 0.02);
  });

  test('desmarcar devolve a quantidade do estoque', () async {
    final id = await repository.create(draftItems());
    final list = await repository.getById(id);
    final flourItem = list!.items.first;

    await repository.setChecked(id, flourItem.id!, true);
    await repository.setChecked(id, flourItem.id!, false);

    expect(await stockOf(flourId), 1000);
    final reloaded = await repository.getById(id);
    expect(reloaded!.items.first.checked, isFalse);
  });

  test('fecha a lista sozinha quando todos os itens são marcados', () async {
    final id = await repository.create(draftItems());
    final list = await repository.getById(id);

    for (final item in list!.items) {
      await repository.setChecked(id, item.id!, true);
    }

    final closed = await repository.getById(id);
    expect(closed!.isClosed, isTrue);
    expect(closed.closedAt, isNotNull);
    expect(await stockOf(flourId), 3000);
    expect(await stockOf(sugarId), 1500);
  });

  test('desmarcar um item reabre a lista fechada', () async {
    final id = await repository.create(draftItems());
    final list = await repository.getById(id);
    for (final item in list!.items) {
      await repository.setChecked(id, item.id!, true);
    }

    await repository.setChecked(id, list.items.first.id!, false);

    final reopened = await repository.getById(id);
    expect(reopened!.isClosed, isFalse);
  });

  test('excluir lista retira do estoque o que já tinha sido marcado', () async {
    final id = await repository.create(draftItems());
    final list = await repository.getById(id);
    await repository.setChecked(id, list!.items.first.id!, true);

    await repository.delete(id);

    expect(await stockOf(flourId), 1000);
    expect(await repository.getById(id), isNull);
  });

  test('addItems soma na quantidade de um item ainda não comprado', () async {
    final id = await repository.create(draftItems());

    await repository.addItems(id, [
      ShoppingListItem(
        ingredientId: flourId,
        ingredientName: 'Farinha',
        quantity: 500,
        unit: Unit.kg,
      ),
    ]);

    final list = await repository.getById(id);
    expect(list!.items, hasLength(2));
    final flourItem = list.items.firstWhere(
      (item) => item.ingredientId == flourId,
    );
    expect(flourItem.quantity, 2500);
  });

  test(
    'addItems cria uma linha nova quando o item já foi comprado',
    () async {
      final id = await repository.create(draftItems());
      final list = await repository.getById(id);
      final flourItem = list!.items.firstWhere(
        (item) => item.ingredientId == flourId,
      );
      await repository.setChecked(id, flourItem.id!, true);

      await repository.addItems(id, [
        ShoppingListItem(
          ingredientId: flourId,
          ingredientName: 'Farinha',
          quantity: 500,
          unit: Unit.kg,
        ),
      ]);

      final reloaded = await repository.getById(id);
      final flourRows = reloaded!.items.where(
        (item) => item.ingredientId == flourId,
      );
      expect(flourRows, hasLength(2));
    },
  );

  test('addItems reabre uma lista fechada', () async {
    final id = await repository.create(draftItems());
    final list = await repository.getById(id);
    for (final item in list!.items) {
      await repository.setChecked(id, item.id!, true);
    }
    expect((await repository.getById(id))!.isClosed, isTrue);

    await repository.addItems(id, [
      ShoppingListItem(
        ingredientId: flourId,
        ingredientName: 'Farinha',
        quantity: 500,
        unit: Unit.kg,
      ),
    ]);

    expect((await repository.getById(id))!.isClosed, isFalse);
  });

  test('addItems recusa lista sem itens ou lista inexistente', () async {
    final id = await repository.create(draftItems());
    await expectLater(repository.addItems(id, []), throwsArgumentError);
    await expectLater(
      repository.addItems(999, draftItems()),
      throwsStateError,
    );
  });

  test('lista todas as listas da mais nova para a mais antiga', () async {
    final firstId = await repository.create(draftItems());
    final secondId = await repository.create(draftItems());

    final all = await repository.getAll();

    expect(all.map((list) => list.id), [secondId, firstId]);
  });
}
