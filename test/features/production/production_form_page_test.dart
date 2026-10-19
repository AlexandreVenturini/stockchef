import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stockchef/core/theme.dart';
import 'package:stockchef/core/units.dart';
import 'package:stockchef/features/ingredients/ingredient.dart';
import 'package:stockchef/features/production/production_history_page.dart';
import 'package:stockchef/features/recipes/recipe.dart';

import '../../helpers/test_database.dart';

void main() {
  late Database db;

  setUp(() async => db = await openTestDatabase());

  tearDown(() => closeTestDatabase(db));

  Future<void> seed({double sugarStock = 3000}) async {
    final strawberryId = await db.insert(
      'ingredients',
      const Ingredient(name: 'Morango', unit: Unit.kg, stock: 5000).toMap(),
    );
    final sugarId = await db.insert(
      'ingredients',
      Ingredient(name: 'Açúcar', unit: Unit.kg, stock: sugarStock).toMap(),
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

  Future<double> stockOf(WidgetTester tester, String name) async {
    final rows = await tester.runAsync(
      () => db.query('ingredients', where: 'name = ?', whereArgs: [name]),
    );
    return Ingredient.fromMap(rows!.single).stock;
  }

  Future<void> openForm(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const ProductionHistoryPage()),
    );
    await pumpAndLoad(tester);
    await tester.tap(find.byTooltip('Registrar produção'));
    await pumpAndLoad(tester);
  }

  Future<void> fillForm(WidgetTester tester, String quantity) async {
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await pumpAndLoad(tester);
    await tester.tap(find.text('Calda de morango').last);
    await pumpAndLoad(tester);
    await tester.enterText(find.byType(TextFormField), quantity);
    await pumpAndLoad(tester);
  }

  testWidgets('sem receitas avisa para cadastrar uma antes', (tester) async {
    await openForm(tester);

    expect(find.textContaining('Cadastre uma receita'), findsOneWidget);
  });

  testWidgets('salvar vazio mostra os erros', (tester) async {
    await tester.runAsync(seed);
    await openForm(tester);

    await tester.tap(find.text('Salvar produção'));
    await tester.pump();

    expect(find.text('Escolha a receita'), findsOneWidget);
    expect(find.text('Informe a quantidade'), findsOneWidget);
  });

  testWidgets('prévia mostra quanto sai e quanto fica', (tester) async {
    await tester.runAsync(seed);
    await openForm(tester);

    await fillForm(tester, '2,5');

    expect(find.text('Vai sair do estoque'), findsOneWidget);
    expect(find.text('1,5 kg'), findsOneWidget);
    expect(find.text('Tem 5 kg · fica 3,5 kg'), findsOneWidget);
    expect(find.text('Tem 3 kg · fica 2 kg'), findsOneWidget);
  });

  testWidgets('salvar registra a produção e baixa o estoque', (tester) async {
    await tester.runAsync(seed);
    await openForm(tester);
    await fillForm(tester, '2,5');

    await tester.tap(find.text('Salvar produção'));
    await pumpAndLoad(tester);

    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text('Calda de morango'), findsOneWidget);
    expect(find.text('2,5 kg'), findsOneWidget);
    expect(await stockOf(tester, 'Morango'), 3500);
    expect(await stockOf(tester, 'Açúcar'), 2000);
  });

  testWidgets('com falta de ingrediente pede confirmação e salva', (
    tester,
  ) async {
    await tester.runAsync(() => seed(sugarStock: 600));
    await openForm(tester);
    await fillForm(tester, '2,5');

    expect(find.text('Tem 0,6 kg · faltam 0,4 kg'), findsOneWidget);

    await tester.tap(find.text('Salvar produção'));
    await pumpAndLoad(tester);

    expect(find.text('Falta ingrediente'), findsOneWidget);
    expect(find.text('Açúcar: tem 0,6 kg, precisa de 1 kg'), findsOneWidget);

    await tester.tap(find.text('Salvar mesmo assim'));
    await pumpAndLoad(tester);

    expect(find.text('Calda de morango'), findsOneWidget);
    expect(await stockOf(tester, 'Açúcar'), -400);
  });

  testWidgets('cancelar o aviso de falta não salva nada', (tester) async {
    await tester.runAsync(() => seed(sugarStock: 600));
    await openForm(tester);
    await fillForm(tester, '2,5');

    await tester.tap(find.text('Salvar produção'));
    await pumpAndLoad(tester);
    await tester.tap(find.text('Cancelar'));
    await pumpAndLoad(tester);

    expect(find.text('Nova produção'), findsOneWidget);
    expect(await stockOf(tester, 'Açúcar'), 600);
    final productions = await tester.runAsync(() => db.query('productions'));
    expect(productions, isEmpty);
  });
}
