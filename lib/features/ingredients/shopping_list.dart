import '../../core/units.dart';

class ShoppingList {
  const ShoppingList({
    this.id,
    required this.createdAt,
    this.closedAt,
    this.items = const [],
  });

  final int? id;
  final DateTime createdAt;
  final DateTime? closedAt;
  final List<ShoppingListItem> items;

  bool get isClosed => closedAt != null;

  int get checkedCount => items.where((item) => item.checked).length;

  factory ShoppingList.fromMap(
    Map<String, Object?> map, {
    List<ShoppingListItem> items = const [],
  }) {
    return ShoppingList(
      id: map['id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      closedAt: map['closed_at'] == null
          ? null
          : DateTime.parse(map['closed_at'] as String),
      items: items,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'created_at': createdAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
    };
  }
}

class ShoppingListItem {
  const ShoppingListItem({
    this.id,
    this.ingredientId,
    required this.ingredientName,
    required this.quantity,
    required this.unit,
    this.checked = false,
    this.checkedAt,
    this.pricePaid,
  });

  final int? id;
  final int? ingredientId;
  final String ingredientName;
  final double quantity;
  final Unit unit;
  final bool checked;
  final DateTime? checkedAt;

  /// Preço total pago por [quantity] deste item, informado ao marcar o
  /// check. Usado para atualizar o preço por unidade do ingrediente.
  final double? pricePaid;

  factory ShoppingListItem.fromMap(Map<String, Object?> map) {
    return ShoppingListItem(
      id: map['id'] as int?,
      ingredientId: map['ingredient_id'] as int?,
      ingredientName: map['ingredient_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: Unit.values.byName(map['unit'] as String),
      checked: (map['checked'] as int? ?? 0) == 1,
      checkedAt: map['checked_at'] == null
          ? null
          : DateTime.parse(map['checked_at'] as String),
      pricePaid: (map['price_paid'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toMap(int listId) {
    return {
      if (id != null) 'id': id,
      'list_id': listId,
      'ingredient_id': ingredientId,
      'ingredient_name': ingredientName,
      'quantity': quantity,
      'unit': unit.name,
      'checked': checked ? 1 : 0,
      'checked_at': checkedAt?.toIso8601String(),
      'price_paid': pricePaid,
    };
  }
}
