import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stockchef/core/widgets/item_card.dart';
import 'package:stockchef/features/ingredients/ingredients_page.dart';
import '../../helpers/test_database.dart';

void main() {
  late Database db;
  setUp(() async => db = await openTestDatabase());
  tearDown(() => closeTestDatabase(db));

  Finder badge(String text) =>
      find.descendant(of: find.byType(ItemCard), matching: find.text(text));

  testWidgets('cadastra ingrediente e adiciona compra ao saldo negativo', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: IngredientsPage()));
    await pumpAndLoad(tester);
    await tester.tap(find.text('Cadastrar primeiro ingrediente'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome'),
      'Farinha',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Estoque atual'),
      '-0,5',
    );
    await tester.tap(find.text('Salvar'));
    await pumpAndLoad(tester);
    await tester.pumpAndSettle();
    expect(find.text('-0,5 kg'), findsOneWidget);
    expect(badge('Sem estoque'), findsOneWidget);
    await tester.tap(find.byTooltip('Adicionar ao estoque'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantidade comprada'),
      '1,5',
    );
    await tester.tap(find.text('Adicionar'));
    await pumpAndLoad(tester);
    await tester.pumpAndSettle();
    expect(find.text('1 kg'), findsOneWidget);
    expect(badge('Sem estoque'), findsNothing);
  });
}
