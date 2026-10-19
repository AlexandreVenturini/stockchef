import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stockchef/core/theme.dart';
import 'package:stockchef/core/units.dart';
import 'package:stockchef/features/ingredients/ingredient.dart';
import 'package:stockchef/features/recipes/recipe.dart';
import 'package:stockchef/features/recipes/recipes_page.dart';

import '../../helpers/test_database.dart';

void main() {
  late Database db;

  setUp(() async => db = await openTestDatabase());

  tearDown(() => closeTestDatabase(db));

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const RecipesPage()),
    );
    await pumpAndLoad(tester);
  }

  Future<void> seedRecipe() async {
    final strawberryId = await db.insert(
      'ingredients',
      const Ingredient(name: 'Morango', unit: Unit.kg).toMap(),
    );
    final sugarId = await db.insert(
      'ingredients',
      const Ingredient(name: 'Açúcar', unit: Unit.kg).toMap(),
    );
    final recipe = Recipe(
      name: 'Calda de morango',
      yieldQuantity: 1000,
      yieldUnit: Unit.kg,
      items: [
        RecipeItem(ingredientId: strawberryId, quantity: 600, unit: Unit.g),
        RecipeItem(ingredientId: sugarId, quantity: 400, unit: Unit.g),
      ],
    );
    final id = await db.insert('recipes', recipe.toMap());
    for (final item in recipe.items) {
      await db.insert('recipe_items', item.toMap(id));
    }
  }

  testWidgets('sem receitas mostra a mensagem de lista vazia', (tester) async {
    await pumpPage(tester);

    expect(find.text('Nenhuma receita cadastrada'), findsOneWidget);
    expect(find.byTooltip('Nova receita'), findsOneWidget);
  });

  testWidgets('lista a receita com rendimento e número de ingredientes', (
    tester,
  ) async {
    await tester.runAsync(seedRecipe);
    await pumpPage(tester);

    expect(find.text('Calda de morango'), findsOneWidget);
    expect(find.text('2 ingredientes'), findsOneWidget);
    expect(find.text('Rende 1 kg'), findsOneWidget);
  });

  testWidgets('sem ingredientes cadastrados o formulário avisa', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Nova receita'));
    await pumpAndLoad(tester);

    expect(find.textContaining('Cadastre ao menos um ingrediente'), findsOneWidget);
  });

  testWidgets('salvar o formulário vazio mostra os erros', (tester) async {
    await tester.runAsync(seedRecipe);
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Nova receita'));
    await pumpAndLoad(tester);
    await tester.tap(find.text('Salvar receita'));
    await tester.pump();

    expect(find.text('Informe o nome da receita'), findsOneWidget);
    expect(find.text('Informe a quantidade'), findsOneWidget);
    expect(find.text('Adicione ao menos um ingrediente'), findsOneWidget);
    expect(find.text('Nova receita'), findsWidgets);
  });

  testWidgets('tocar na receita abre a edição com os dados preenchidos', (
    tester,
  ) async {
    await tester.runAsync(seedRecipe);
    await pumpPage(tester);

    await tester.tap(find.text('Calda de morango'));
    await pumpAndLoad(tester);

    expect(find.text('Editar receita'), findsOneWidget);
    expect(find.text('Calda de morango'), findsOneWidget);
    expect(find.text('600'), findsOneWidget);
    expect(find.text('400'), findsOneWidget);
    expect(find.byTooltip('Excluir receita'), findsOneWidget);
  });
}
