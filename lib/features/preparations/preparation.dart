import '../ingredients/ingredient.dart';
import '../recipes/recipe.dart';

class Preparation {
  const Preparation({required this.recipe, required this.stockItem});

  final Recipe recipe;
  final Ingredient stockItem;
}
