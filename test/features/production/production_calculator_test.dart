import 'package:flutter_test/flutter_test.dart';
import 'package:stockchef/core/units.dart';
import 'package:stockchef/features/ingredients/ingredient.dart';
import 'package:stockchef/features/production/production_calculator.dart';
import 'package:stockchef/features/recipes/recipe.dart';

void main() {
  const strawberry = Ingredient(
    id: 1,
    name: 'Morango',
    unit: Unit.kg,
    stock: 5000,
  );
  const sugar = Ingredient(id: 2, name: 'Açúcar', unit: Unit.kg, stock: 3000);

  const syrup = Recipe(
    id: 10,
    name: 'Calda de morango',
    yieldQuantity: 1000,
    yieldUnit: Unit.kg,
    items: [
      RecipeItem(ingredientId: 1, quantity: 600, unit: Unit.g),
      RecipeItem(ingredientId: 2, quantity: 400, unit: Unit.g),
    ],
  );

  double consumed(ProductionPlan plan, Ingredient ingredient) => plan
      .consumptions
      .singleWhere((consumption) => consumption.ingredient.id == ingredient.id)
      .quantity;

  test('produzir mais que o rendimento multiplica as quantidades', () {
    final plan = planProduction(
      recipe: syrup,
      producedQuantity: Unit.kg.toBase(2.5),
      ingredients: [strawberry, sugar],
    );

    expect(plan.recipe.name, 'Calda de morango');
    expect(plan.producedQuantity, 2500);
    expect(plan.factor, 2.5);
    expect(consumed(plan, strawberry), 1500);
    expect(consumed(plan, sugar), 1000);
  });

  test('produzir menos que o rendimento reduz as quantidades', () {
    final plan = planProduction(
      recipe: syrup,
      producedQuantity: Unit.g.toBase(500),
      ingredients: [strawberry, sugar],
    );

    expect(plan.factor, 0.5);
    expect(consumed(plan, strawberry), 300);
    expect(consumed(plan, sugar), 200);
  });

  test('mostra quanto sobra de cada ingrediente', () {
    final plan = planProduction(
      recipe: syrup,
      producedQuantity: 2500,
      ingredients: [strawberry, sugar],
    );

    final strawberryLine = plan.consumptions.first;
    expect(strawberryLine.remaining, 3500);
    expect(strawberryLine.isShort, isFalse);
    expect(plan.hasShortage, isFalse);
  });

  test('aponta o ingrediente que vai faltar e quanto falta', () {
    const littleSugar = Ingredient(
      id: 2,
      name: 'Açúcar',
      unit: Unit.kg,
      stock: 600,
    );

    final plan = planProduction(
      recipe: syrup,
      producedQuantity: 2500,
      ingredients: [strawberry, littleSugar],
    );

    expect(plan.hasShortage, isTrue);
    expect(plan.shortages, hasLength(1));
    expect(plan.shortages.single.ingredient.name, 'Açúcar');
    expect(plan.shortages.single.remaining, -400);
    expect(plan.shortages.single.missing, 400);
  });

  test('estoque exatamente igual ao necessário não é falta', () {
    const exactSugar = Ingredient(
      id: 2,
      name: 'Açúcar',
      unit: Unit.kg,
      stock: 1000,
    );

    final plan = planProduction(
      recipe: syrup,
      producedQuantity: 2500,
      ingredients: [strawberry, exactSugar],
    );

    expect(plan.hasShortage, isFalse);
    expect(plan.consumptions.last.remaining, 0);
  });

  test('arredonda divisões que não fecham', () {
    const jars = Recipe(
      name: 'Potes de calda',
      yieldQuantity: 3,
      yieldUnit: Unit.un,
      items: [RecipeItem(ingredientId: 2, quantity: 1000, unit: Unit.g)],
    );

    final plan = planProduction(
      recipe: jars,
      producedQuantity: 1,
      ingredients: [sugar],
    );

    expect(consumed(plan, sugar), 333.333);
  });

  test('recusa quantidade produzida zero ou negativa', () {
    expect(
      () => planProduction(
        recipe: syrup,
        producedQuantity: 0,
        ingredients: [strawberry, sugar],
      ),
      throwsArgumentError,
    );
  });

  test('avisa quando falta um ingrediente da receita na lista', () {
    expect(
      () => planProduction(
        recipe: syrup,
        producedQuantity: 1000,
        ingredients: [strawberry],
      ),
      throwsStateError,
    );
  });
}
