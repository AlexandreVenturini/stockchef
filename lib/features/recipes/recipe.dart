import '../../core/units.dart';

class Recipe {
  const Recipe({
    this.id,
    required this.name,
    required this.yieldQuantity,
    required this.yieldUnit,
    this.outputIngredientId,
    this.items = const [],
  });

  final int? id;
  final String name;
  final double yieldQuantity;
  final Unit yieldUnit;
  final int? outputIngredientId;
  final List<RecipeItem> items;

  factory Recipe.fromMap(
    Map<String, Object?> map, {
    List<RecipeItem> items = const [],
  }) {
    return Recipe(
      id: map['id'] as int?,
      name: map['name'] as String,
      yieldQuantity: (map['yield_qty'] as num).toDouble(),
      yieldUnit: Unit.values.byName(map['yield_unit'] as String),
      outputIngredientId: map['output_ingredient_id'] as int?,
      items: items,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'yield_qty': yieldQuantity,
      'yield_unit': yieldUnit.name,
      'output_ingredient_id': outputIngredientId,
    };
  }
}

class RecipeItem {
  const RecipeItem({
    this.id,
    required this.ingredientId,
    required this.quantity,
    required this.unit,
  });

  final int? id;
  final int ingredientId;
  final double quantity;
  final Unit unit;

  factory RecipeItem.fromMap(Map<String, Object?> map) {
    return RecipeItem(
      id: map['id'] as int?,
      ingredientId: map['ingredient_id'] as int,
      quantity: (map['quantity'] as num).toDouble(),
      unit: Unit.values.byName(map['unit'] as String),
    );
  }

  Map<String, Object?> toMap(int recipeId) {
    return {
      if (id != null) 'id': id,
      'recipe_id': recipeId,
      'ingredient_id': ingredientId,
      'quantity': quantity,
      'unit': unit.name,
    };
  }
}
