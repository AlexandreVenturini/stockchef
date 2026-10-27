import 'package:sqflite/sqflite.dart';

import '../../core/database.dart';
import 'shopping_list.dart';

class ShoppingListRepository {
  ShoppingListRepository({Future<Database>? database})
    : _database = database ?? AppDatabase.instance;

  final Future<Database> _database;

  Future<List<ShoppingList>> getAll() async {
    final db = await _database;
    final listRows = await db.query(
      'shopping_lists',
      orderBy: 'created_at DESC',
    );
    final itemRows = await db.query('shopping_list_items', orderBy: 'id');

    final itemsByList = <int, List<ShoppingListItem>>{};
    for (final row in itemRows) {
      itemsByList
          .putIfAbsent(row['list_id'] as int, () => [])
          .add(ShoppingListItem.fromMap(row));
    }

    return listRows
        .map(
          (row) => ShoppingList.fromMap(
            row,
            items: itemsByList[row['id']] ?? const [],
          ),
        )
        .toList();
  }

  Future<ShoppingList?> getById(int id) async {
    final db = await _database;
    final rows = await db.query(
      'shopping_lists',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    final itemRows = await db.query(
      'shopping_list_items',
      where: 'list_id = ?',
      whereArgs: [id],
      orderBy: 'id',
    );
    return ShoppingList.fromMap(
      rows.single,
      items: itemRows.map(ShoppingListItem.fromMap).toList(),
    );
  }

  /// Cria uma lista nova com os itens escolhidos, todos ainda não comprados.
  Future<int> create(List<ShoppingListItem> items) async {
    if (items.isEmpty) {
      throw ArgumentError.value(
        items,
        'items',
        'A lista precisa ter ao menos um item',
      );
    }
    final db = await _database;
    return db.transaction((txn) async {
      final listId = await txn.insert(
        'shopping_lists',
        ShoppingList(createdAt: DateTime.now()).toMap(),
      );
      for (final item in items) {
        await txn.insert('shopping_list_items', item.toMap(listId));
      }
      return listId;
    });
  }

  /// Adiciona itens a uma lista já existente: se a lista já tiver um item do
  /// mesmo ingrediente ainda não comprado, soma a quantidade nele em vez de
  /// duplicar a linha. Reabre a lista (limpa a data de fechamento), já que
  /// agora ela tem algo pendente de novo.
  Future<void> addItems(int listId, List<ShoppingListItem> items) async {
    if (items.isEmpty) {
      throw ArgumentError.value(
        items,
        'items',
        'Informe ao menos um item para adicionar',
      );
    }
    final db = await _database;
    await db.transaction((txn) async {
      final listRows = await txn.query(
        'shopping_lists',
        where: 'id = ?',
        whereArgs: [listId],
      );
      if (listRows.isEmpty) {
        throw StateError('Lista não encontrada');
      }
      final existingRows = await txn.query(
        'shopping_list_items',
        where: 'list_id = ?',
        whereArgs: [listId],
      );
      final existingItems = existingRows.map(ShoppingListItem.fromMap).toList();

      for (final item in items) {
        ShoppingListItem? match;
        for (final existing in existingItems) {
          if (existing.ingredientId == item.ingredientId &&
              !existing.checked) {
            match = existing;
            break;
          }
        }
        if (match != null) {
          await txn.update(
            'shopping_list_items',
            {'quantity': match.quantity + item.quantity},
            where: 'id = ?',
            whereArgs: [match.id],
          );
        } else {
          final inserted = await txn.insert(
            'shopping_list_items',
            item.toMap(listId),
          );
          existingItems.add(
            ShoppingListItem(
              id: inserted,
              ingredientId: item.ingredientId,
              ingredientName: item.ingredientName,
              quantity: item.quantity,
              unit: item.unit,
            ),
          );
        }
      }

      await txn.update(
        'shopping_lists',
        {'closed_at': null},
        where: 'id = ?',
        whereArgs: [listId],
      );
    });
  }

  /// Marca ou desmarca um item como comprado. Ao marcar, soma a quantidade
  /// no estoque do ingrediente; ao desmarcar, devolve. A lista fecha sozinha
  /// (e grava a data) quando todos os itens ficam marcados, e reabre se
  /// algum item for desmarcado depois.
  ///
  /// [pricePaid], se informado ao marcar, é o preço total pago por essa
  /// quantidade: atualiza o preço por unidade do ingrediente (vale sempre o
  /// preço da compra mais recente).
  Future<void> setChecked(
    int listId,
    int itemId,
    bool checked, {
    double? pricePaid,
  }) async {
    final db = await _database;
    await db.transaction((txn) async {
      final itemRows = await txn.query(
        'shopping_list_items',
        where: 'id = ? AND list_id = ?',
        whereArgs: [itemId, listId],
      );
      if (itemRows.isEmpty) {
        throw StateError('Item não encontrado');
      }
      final item = ShoppingListItem.fromMap(itemRows.single);
      if (item.checked == checked) return;

      await txn.update(
        'shopping_list_items',
        {
          'checked': checked ? 1 : 0,
          'checked_at': checked ? DateTime.now().toIso8601String() : null,
          'price_paid': checked ? pricePaid : item.pricePaid,
        },
        where: 'id = ?',
        whereArgs: [itemId],
      );

      if (item.ingredientId != null) {
        final delta = checked ? item.quantity : -item.quantity;
        await txn.rawUpdate(
          'UPDATE ingredients SET stock = ROUND(stock + ?, 3) WHERE id = ?',
          [delta, item.ingredientId],
        );
        if (checked && pricePaid != null) {
          await txn.update(
            'ingredients',
            {'price': pricePaid / item.quantity},
            where: 'id = ?',
            whereArgs: [item.ingredientId],
          );
        }
      }

      final remaining = await txn.query(
        'shopping_list_items',
        where: 'list_id = ? AND checked = 0',
        whereArgs: [listId],
      );
      await txn.update(
        'shopping_lists',
        {
          'closed_at': remaining.isEmpty
              ? DateTime.now().toIso8601String()
              : null,
        },
        where: 'id = ?',
        whereArgs: [listId],
      );
    });
  }

  /// Exclui a lista. Itens já marcados como comprados têm a quantidade
  /// retirada do estoque, já que não foram de fato recebidos.
  Future<void> delete(int id) async {
    final db = await _database;
    await db.transaction((txn) async {
      final itemRows = await txn.query(
        'shopping_list_items',
        where: 'list_id = ? AND checked = 1',
        whereArgs: [id],
      );
      for (final item in itemRows.map(ShoppingListItem.fromMap)) {
        if (item.ingredientId == null) continue;
        await txn.rawUpdate(
          'UPDATE ingredients SET stock = ROUND(stock - ?, 3) WHERE id = ?',
          [item.quantity, item.ingredientId],
        );
      }
      await txn.delete('shopping_lists', where: 'id = ?', whereArgs: [id]);
    });
  }
}
