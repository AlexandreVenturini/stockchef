import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stockchef/core/units.dart';
import 'package:stockchef/features/ingredients/ingredient.dart';
import 'package:stockchef/features/recipes/recipe.dart';
import 'package:stockchef/features/recipes/recipe_repository.dart';

import '../../helpers/test_database.dart';

void main() {
  late Database db;
  late RecipeRepository repository;
  late int strawberryId;
  late int sugarId;

  setUp(() async {
    db = await openTestDatabase();
    repository = RecipeRepository();
    strawberryId = await db.insert(
      'ingredients',
      const Ingredient(name: 'Morango', unit: Unit.kg).toMap(),
    );
    sugarId = await db.insert(
      'ingredients',
      const Ingredient(name: 'Açúcar', unit: Unit.kg).toMap(),
    );
  });

  tearDown(() => closeTestDatabase(db));

  Recipe sauce({int? id, String name = 'Calda de morango'}) => Recipe(
    id: id,
    name: name,
    yieldQuantity: 1000,
    yieldUnit: Unit.kg,
    items: [
      RecipeItem(ingredientId: strawberryId, quantity: 600, unit: Unit.g),
      RecipeItem(ingredientId: sugarId, quantity: 400, unit: Unit.g),
    ],
  );

  test('salva receita nova e lê de volta com os itens', () async {
    final id = await repository.save(sauce());
    final saved = await repository.getById(id);

    expect(saved, isNotNull);
    expect(saved!.name, 'Calda de morango');
    expect(saved.yieldQuantity, 1000);
    expect(saved.yieldUnit, Unit.kg);
    expect(saved.items, hasLength(2));
    expect(saved.items.first.ingredientId, strawberryId);
    expect(saved.items.first.quantity, 600);
  });

  test('getById devolve null quando a receita não existe', () async {
    expect(await repository.getById(999), isNull);
  });

  test('getAll devolve em ordem alfabética, ignorando maiúsculas', () async {
    await repository.save(sauce(name: 'calda de uva'));
    await repository.save(sauce(name: 'Brigadeiro'));
    await repository.save(sauce(name: 'Zabaione'));

    final names = (await repository.getAll()).map((r) => r.name).toList();

    expect(names, ['Brigadeiro', 'calda de uva', 'Zabaione']);
  });

  test('atualizar troca os dados e substitui os itens', () async {
    final id = await repository.save(sauce());

    await repository.save(
      Recipe(
        id: id,
        name: 'Calda doce',
        yieldQuantity: 2000,
        yieldUnit: Unit.kg,
        items: [
          RecipeItem(ingredientId: sugarId, quantity: 1500, unit: Unit.g),
        ],
      ),
    );

    final updated = await repository.getById(id);
    expect(updated!.name, 'Calda doce');
    expect(updated.yieldQuantity, 2000);
    expect(updated.items, hasLength(1));
    expect(updated.items.single.ingredientId, sugarId);
    expect(await repository.getAll(), hasLength(1));
    expect(await db.query('recipe_items'), hasLength(1));
  });

  test('excluir remove a receita e seus itens', () async {
    final id = await repository.save(sauce());

    await repository.delete(id);

    expect(await repository.getAll(), isEmpty);
    expect(await db.query('recipe_items'), isEmpty);
  });

  test('excluir mantém o histórico de produção, sem vínculo', () async {
    final id = await repository.save(sauce());
    await db.insert('productions', {
      'recipe_id': id,
      'recipe_name': 'Calda de morango',
      'date': '2026-10-19',
      'quantity': 1000,
      'unit': 'kg',
      'created_at': DateTime(2026, 10, 19).toIso8601String(),
    });

    await repository.delete(id);

    final productions = await db.query('productions');
    expect(productions, hasLength(1));
    expect(productions.single['recipe_id'], isNull);
    expect(productions.single['recipe_name'], 'Calda de morango');
  });

  test('não salva receita sem nome ou sem rendimento', () async {
    final blankName = Recipe(
      name: '  ',
      yieldQuantity: 1000,
      yieldUnit: Unit.kg,
      items: sauce().items,
    );
    final noYield = Recipe(
      name: 'X',
      yieldQuantity: 0,
      yieldUnit: Unit.kg,
      items: sauce().items,
    );

    await expectLater(repository.save(blankName), throwsArgumentError);
    await expectLater(repository.save(noYield), throwsArgumentError);
    expect(await repository.getAll(), isEmpty);
  });

  test('salva receita sem nenhum ingrediente', () async {
    const noItems = Recipe(name: 'X', yieldQuantity: 1000, yieldUnit: Unit.kg);

    final id = await repository.save(noItems);
    final saved = await repository.getById(id);

    expect(saved, isNotNull);
    expect(saved!.items, isEmpty);
  });

  test('salva e lê de volta tempo de preparo e etapas, em ordem', () async {
    final recipe = Recipe(
      name: 'Calda de morango',
      yieldQuantity: 1000,
      yieldUnit: Unit.kg,
      prepTimeMinutes: 45,
      items: sauce().items,
      steps: const [
        RecipeStep(position: 0, description: 'Ferva a água'),
        RecipeStep(position: 1, description: 'Adicione o morango'),
      ],
    );

    final id = await repository.save(recipe);
    final saved = await repository.getById(id);

    expect(saved!.prepTimeMinutes, 45);
    expect(saved.steps.map((s) => s.description), [
      'Ferva a água',
      'Adicione o morango',
    ]);
  });

  test('atualizar substitui as etapas antigas pelas novas', () async {
    final id = await repository.save(
      Recipe(
        name: 'Calda de morango',
        yieldQuantity: 1000,
        yieldUnit: Unit.kg,
        items: sauce().items,
        steps: const [RecipeStep(position: 0, description: 'Passo antigo')],
      ),
    );

    await repository.save(
      Recipe(
        id: id,
        name: 'Calda de morango',
        yieldQuantity: 1000,
        yieldUnit: Unit.kg,
        items: sauce().items,
        steps: const [RecipeStep(position: 0, description: 'Passo novo')],
      ),
    );

    final updated = await repository.getById(id);
    expect(updated!.steps.map((s) => s.description), ['Passo novo']);
  });

  test('não salva o mesmo ingrediente duas vezes na receita', () async {
    final duplicated = Recipe(
      name: 'Repetida',
      yieldQuantity: 1000,
      yieldUnit: Unit.kg,
      items: [
        RecipeItem(ingredientId: sugarId, quantity: 100, unit: Unit.g),
        RecipeItem(ingredientId: sugarId, quantity: 200, unit: Unit.g),
      ],
    );

    await expectLater(repository.save(duplicated), throwsArgumentError);
    expect(await repository.getAll(), isEmpty);
  });

  test('falha no meio não deixa receita pela metade', () async {
    final invalid = Recipe(
      name: 'Quebrada',
      yieldQuantity: 1000,
      yieldUnit: Unit.kg,
      items: [
        RecipeItem(ingredientId: sugarId, quantity: 100, unit: Unit.g),
        const RecipeItem(ingredientId: 9999, quantity: 100, unit: Unit.g),
      ],
    );

    await expectLater(repository.save(invalid), throwsA(isA<DatabaseException>()));

    expect(await repository.getAll(), isEmpty);
  });

  test('getIngredients lista os ingredientes em ordem alfabética', () async {
    final names = (await repository.getIngredients()).map((i) => i.name);

    expect(names, ['Açúcar', 'Morango']);
  });

  test('não apaga ingrediente que está em uma receita', () async {
    await repository.save(sauce());

    await expectLater(
      db.delete('ingredients', where: 'id = ?', whereArgs: [sugarId]),
      throwsA(isA<DatabaseException>()),
    );
  });
}
