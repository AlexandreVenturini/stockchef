import '../../core/units.dart';
import '../ingredients/ingredient.dart';

class Recipe {
  const Recipe({
    this.id,
    required this.name,
    required this.yieldQuantity,
    required this.yieldUnit,
    this.outputIngredientId,
    this.prepTimeMinutes,
    this.items = const [],
    this.steps = const [],
  });

  final int? id;
  final String name;
  final double yieldQuantity;
  final Unit yieldUnit;
  final int? outputIngredientId;
  final int? prepTimeMinutes;
  final List<RecipeItem> items;
  final List<RecipeStep> steps;

  bool get isPreparation => outputIngredientId != null;

  factory Recipe.fromMap(
    Map<String, Object?> map, {
    List<RecipeItem> items = const [],
    List<RecipeStep> steps = const [],
  }) {
    return Recipe(
      id: map['id'] as int?,
      name: map['name'] as String,
      yieldQuantity: (map['yield_qty'] as num).toDouble(),
      yieldUnit: Unit.values.byName(map['yield_unit'] as String),
      outputIngredientId: map['output_ingredient_id'] as int?,
      prepTimeMinutes: map['prep_time_minutes'] as int?,
      items: items,
      steps: steps,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'yield_qty': yieldQuantity,
      'yield_unit': yieldUnit.name,
      'output_ingredient_id': outputIngredientId,
      'prep_time_minutes': prepTimeMinutes,
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

/// Um passo do modo de preparo. [position] define a ordem de exibição.
class RecipeStep {
  const RecipeStep({this.id, required this.position, required this.description});

  final int? id;
  final int position;
  final String description;

  factory RecipeStep.fromMap(Map<String, Object?> map) {
    return RecipeStep(
      id: map['id'] as int?,
      position: map['position'] as int,
      description: map['description'] as String,
    );
  }

  Map<String, Object?> toMap(int recipeId) {
    return {
      if (id != null) 'id': id,
      'recipe_id': recipeId,
      'position': position,
      'description': description,
    };
  }
}

/// Custo estimado da receita: soma de quantidade × preço por unidade base de
/// cada ingrediente. Ingredientes sem preço cadastrado não entram na conta.
double recipeCost(Recipe recipe, Map<int, Ingredient> ingredientsById) {
  var total = 0.0;
  for (final item in recipe.items) {
    final price = ingredientsById[item.ingredientId]?.price;
    if (price == null) continue;
    total += item.quantity * price;
  }
  return total;
}

/// Se algum ingrediente da receita não tem preço cadastrado, o [recipeCost]
/// é parcial (não reflete o custo real da receita).
bool recipeCostIsPartial(Recipe recipe, Map<int, Ingredient> ingredientsById) {
  if (recipe.items.isEmpty) return false;
  return recipe.items.any(
    (item) => ingredientsById[item.ingredientId]?.price == null,
  );
}
