import '../../core/units.dart';
import '../ingredients/ingredient.dart';
import '../recipes/recipe.dart';

class Consumption {
  const Consumption({required this.ingredient, required this.quantity});

  final Ingredient ingredient;
  final double quantity;

  double get remaining => roundBase(ingredient.stock - quantity);

  bool get isShort => remaining < 0;

  double get missing => isShort ? -remaining : 0;
}

class ProductionPlan {
  const ProductionPlan({
    required this.recipe,
    required this.producedQuantity,
    required this.factor,
    required this.consumptions,
  });

  final Recipe recipe;
  final double producedQuantity;
  final double factor;
  final List<Consumption> consumptions;

  List<Consumption> get shortages =>
      consumptions.where((consumption) => consumption.isShort).toList();

  bool get hasShortage => consumptions.any((consumption) => consumption.isShort);
}

ProductionPlan planProduction({
  required Recipe recipe,
  required double producedQuantity,
  required List<Ingredient> ingredients,
}) {
  if (producedQuantity <= 0) {
    throw ArgumentError.value(
      producedQuantity,
      'producedQuantity',
      'A quantidade produzida precisa ser maior que zero',
    );
  }

  final factor = producedQuantity / recipe.yieldQuantity;
  final ingredientsById = {
    for (final ingredient in ingredients) ingredient.id: ingredient,
  };

  final consumptions = recipe.items.map((item) {
    final ingredient = ingredientsById[item.ingredientId];
    if (ingredient == null) {
      throw StateError(
        'Ingrediente ${item.ingredientId} da receita "${recipe.name}" não encontrado',
      );
    }
    return Consumption(
      ingredient: ingredient,
      quantity: roundBase(item.quantity * factor),
    );
  }).toList();

  return ProductionPlan(
    recipe: recipe,
    producedQuantity: producedQuantity,
    factor: factor,
    consumptions: consumptions,
  );
}
