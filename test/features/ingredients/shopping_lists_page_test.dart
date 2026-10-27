import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stockchef/core/theme.dart';
import 'package:stockchef/core/units.dart';
import 'package:stockchef/features/ingredients/ingredient.dart';
import 'package:stockchef/features/ingredients/shopping_lists_page.dart';

import '../../helpers/test_database.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await openTestDatabase();
    await db.insert(
      'ingredients',
      const Ingredient(name: 'Farinha', unit: Unit.kg, stock: 1000).toMap(),
    );
  });

  tearDown(() => closeTestDatabase(db));

  Future<double> stockOfFlour() async {
    final rows = await db.query(
      'ingredients',
      where: 'name = ?',
      whereArgs: ['Farinha'],
    );
    return Ingredient.fromMap(rows.single).stock;
  }

  testWidgets('sem listas mostra a mensagem de lista vazia', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const ShoppingListsPage()),
    );
    await pumpAndLoad(tester);

    expect(find.text('Nenhuma lista de compras'), findsOneWidget);
  });

  testWidgets('criar lista, marcar o item soma no estoque e fecha a lista', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const ShoppingListsPage()),
    );
    await pumpAndLoad(tester);

    await tester.tap(find.byTooltip('Nova lista'));
    await pumpAndLoad(tester);

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await pumpAndLoad(tester);
    await tester.tap(find.text('Farinha').last);
    await pumpAndLoad(tester);
    await tester.enterText(find.byType(TextFormField), '2');
    await pumpAndLoad(tester);

    await tester.tap(find.text('Criar lista'));
    await pumpAndLoad(tester);

    expect(find.text('Nenhuma lista de compras'), findsNothing);
    expect(find.textContaining('Aberta'), findsWidgets);

    await tester.tap(find.textContaining('Lista de'));
    await pumpAndLoad(tester);

    expect(find.byType(CheckboxListTile), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await pumpAndLoad(tester);

    expect(find.text('Quanto você pagou?'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Preço pago (opcional)'),
      '20',
    );
    await tester.tap(find.text('Salvar'));
    await pumpAndLoad(tester);

    expect(find.text('Fechada'), findsWidgets);
    expect(await stockOfFlour(), 3000);
    final flourRows = await db.query(
      'ingredients',
      where: 'name = ?',
      whereArgs: ['Farinha'],
    );
    expect(Ingredient.fromMap(flourRows.single).price, closeTo(0.01, 1e-9));
  });
}
