import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stockchef/app.dart';
import 'package:stockchef/features/ingredients/ingredients_page.dart';
import 'package:stockchef/features/production/production_history_page.dart';
import 'package:stockchef/features/recipes/recipes_page.dart';

import 'helpers/test_database.dart';

void main() {
  late Database db;

  setUp(() async => db = await openTestDatabase());

  tearDown(() => closeTestDatabase(db));

  Finder tab(String label) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );

  testWidgets('abre na aba de ingredientes', (tester) async {
    await tester.pumpWidget(const StockChefApp());

    expect(tab('Ingredientes'), findsOneWidget);
    expect(tab('Receitas'), findsOneWidget);
    expect(tab('Produção'), findsOneWidget);
    expect(find.byType(IngredientsPage), findsOneWidget);
  });

  testWidgets('troca de tela ao tocar nas abas', (tester) async {
    await tester.pumpWidget(const StockChefApp());

    await tester.tap(tab('Receitas'));
    await tester.pumpAndSettle();
    expect(find.byType(RecipesPage), findsOneWidget);
    expect(find.byType(IngredientsPage), findsNothing);

    await tester.tap(tab('Produção'));
    await pumpAndLoad(tester);
    expect(find.byType(ProductionHistoryPage), findsOneWidget);
    expect(find.text('Nenhuma produção registrada'), findsOneWidget);
  });
}
