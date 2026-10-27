import '../../core/format.dart';
import '../../core/units.dart';

class Production {
  const Production({
    this.id,
    this.recipeId,
    required this.recipeName,
    required this.date,
    required this.quantity,
    required this.unit,
    required this.createdAt,
    this.affectsStock = true,
    this.items = const [],
  });

  final int? id;
  final int? recipeId;
  final String recipeName;
  final DateTime date;
  final double quantity;
  final Unit unit;
  final DateTime createdAt;

  /// Se esta produção alterou o estoque atual dos ingredientes. Produções
  /// com data retroativa (anteriores a hoje) não abatem o estoque, pois
  /// representam um registro histórico de algo já consumido antes do app.
  final bool affectsStock;
  final List<ProductionItem> items;

  factory Production.fromMap(
    Map<String, Object?> map, {
    List<ProductionItem> items = const [],
  }) {
    return Production(
      id: map['id'] as int?,
      recipeId: map['recipe_id'] as int?,
      recipeName: map['recipe_name'] as String,
      date: fromDateKey(map['date'] as String),
      quantity: (map['quantity'] as num).toDouble(),
      unit: Unit.values.byName(map['unit'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      affectsStock: (map['affects_stock'] as int? ?? 1) == 1,
      items: items,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'recipe_id': recipeId,
      'recipe_name': recipeName,
      'date': toDateKey(date),
      'quantity': quantity,
      'unit': unit.name,
      'created_at': createdAt.toIso8601String(),
      'affects_stock': affectsStock ? 1 : 0,
    };
  }
}

/// Produções de hoje abatem o estoque; produções com data retroativa são
/// apenas um registro histórico e não alteram o estoque atual.
bool productionAffectsStock(DateTime date) =>
    toDateKey(date) == toDateKey(DateTime.now());

class ProductionItem {
  const ProductionItem({
    this.id,
    this.ingredientId,
    required this.ingredientName,
    required this.quantity,
    required this.unit,
  });

  final int? id;
  final int? ingredientId;
  final String ingredientName;
  final double quantity;
  final Unit unit;

  factory ProductionItem.fromMap(Map<String, Object?> map) {
    return ProductionItem(
      id: map['id'] as int?,
      ingredientId: map['ingredient_id'] as int?,
      ingredientName: map['ingredient_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: Unit.values.byName(map['unit'] as String),
    );
  }

  Map<String, Object?> toMap(int productionId) {
    return {
      if (id != null) 'id': id,
      'production_id': productionId,
      'ingredient_id': ingredientId,
      'ingredient_name': ingredientName,
      'quantity': quantity,
      'unit': unit.name,
    };
  }
}

Map<DateTime, List<Production>> groupByDay(List<Production> productions) {
  final days = <DateTime, List<Production>>{};
  for (final production in productions) {
    days.putIfAbsent(production.date, () => []).add(production);
  }
  return days;
}
