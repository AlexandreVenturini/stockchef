import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets/item_card.dart';
import '../../core/widgets/section_title.dart';
import '../ingredients/ingredient.dart';
import '../ingredients/shopping_list.dart';
import '../ingredients/shopping_list_detail_page.dart';
import '../ingredients/shopping_list_repository.dart';
import '../production/production_calculator.dart';
import 'recipe.dart';
import 'recipe_form_page.dart';
import 'recipe_repository.dart';

/// Valor especial no diálogo de escolha de lista que significa "criar uma
/// lista nova" em vez de usar uma já existente (ids reais nunca são -1).
const _newListId = -1;

/// Tela de leitura da receita: mostra os dados sem permitir editar.
/// O botão Editar abre o formulário; ao salvar ou excluir, fecha esta tela
/// também para que a lista de receitas seja atualizada.
class RecipeDetailPage extends StatefulWidget {
  const RecipeDetailPage({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  final _repository = RecipeRepository();
  late Future<List<Ingredient>> _ingredientsFuture;

  @override
  void initState() {
    super.initState();
    _ingredientsFuture = _repository.getIngredients();
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RecipeFormPage(recipe: widget.recipe)),
    );
    if (!mounted || changed != true) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _createShoppingList(List<Ingredient> ingredients) async {
    final recipe = widget.recipe;
    final chosen = await showDialog<(double, Unit)>(
      context: context,
      builder: (_) => _ProduceQuantityDialog(recipe: recipe),
    );
    if (chosen == null || !mounted) return;
    final (producedBase, _) = chosen;

    final plan = planProduction(
      recipe: recipe,
      producedQuantity: producedBase,
      ingredients: ingredients,
    );
    final shortages = plan.shortages;
    if (shortages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você já tem estoque suficiente para essa quantidade'),
        ),
      );
      return;
    }

    final shoppingListRepository = ShoppingListRepository();
    final openLists = (await shoppingListRepository.getAll())
        .where((list) => !list.isClosed)
        .toList();
    if (!mounted) return;

    var targetListId = _newListId;
    if (openLists.isNotEmpty) {
      final chosenId = await showDialog<int>(
        context: context,
        builder: (_) => _ChooseListDialog(lists: openLists),
      );
      if (chosenId == null) return;
      targetListId = chosenId;
    }

    final items = [
      for (final consumption in shortages)
        ShoppingListItem(
          ingredientId: consumption.ingredient.id,
          ingredientName: consumption.ingredient.name,
          quantity: consumption.missing,
          unit: consumption.ingredient.unit,
        ),
    ];
    final listId = targetListId == _newListId
        ? await shoppingListRepository.create(items)
        : await _addToExistingList(
            shoppingListRepository,
            targetListId,
            items,
          );
    if (!mounted) return;
    final list = await shoppingListRepository.getById(listId);
    if (!mounted || list == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ShoppingListDetailPage(list: list)),
    );
  }

  Future<int> _addToExistingList(
    ShoppingListRepository repository,
    int listId,
    List<ShoppingListItem> items,
  ) async {
    await repository.addItems(listId, items);
    return listId;
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.name),
        actions: [
          IconButton(
            tooltip: 'Editar receita',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _edit,
          ),
        ],
      ),
      body: FutureBuilder<List<Ingredient>>(
        future: _ingredientsFuture,
        builder: (context, snapshot) {
          final ingredients = snapshot.data ?? const <Ingredient>[];
          final ingredientsById = <int, Ingredient>{
            for (final ingredient in ingredients)
              if (ingredient.id != null) ingredient.id!: ingredient,
          };
          final names = {
            for (final entry in ingredientsById.entries)
              entry.key: entry.value.name,
          };

          return SingleChildScrollView(
            padding: const EdgeInsets.only(
              top: AppSpacing.xs,
              bottom: AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SummaryCard(recipe: recipe, ingredientsById: ingredientsById),
                if (recipe.items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: OutlinedButton.icon(
                      onPressed: snapshot.hasData
                          ? () => _createShoppingList(ingredients)
                          : null,
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                      label: const Text('Criar lista da receita'),
                    ),
                  ),
                SectionTitle(
                  'Ingredientes',
                  trailing: recipe.items.length == 1
                      ? '1 item'
                      : '${recipe.items.length} itens',
                ),
                if (recipe.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Text('Nenhum ingrediente cadastrado'),
                  ),
                for (final item in recipe.items)
                  ItemCard(
                    icon: Icons.inventory_2_outlined,
                    title: names[item.ingredientId] ?? '—',
                    trailing: formatQuantity(item.quantity, item.unit),
                  ),
                if (recipe.steps.isNotEmpty) ...[
                  const SectionTitle('Modo de preparo'),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final step in recipe.steps)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor:
                                          AppColors.iconBackground,
                                      child: Text(
                                        '${step.position + 1}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(child: Text(step.description)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.recipe, required this.ingredientsById});

  final Recipe recipe;
  final Map<int, Ingredient> ingredientsById;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cost = recipeCost(recipe, ingredientsById);
    final isPartial = recipeCostIsPartial(recipe, ingredientsById);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.iconBackground,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    recipe.isPreparation
                        ? Icons.blender_outlined
                        : Icons.menu_book_outlined,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rendimento',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        formatQuantity(recipe.yieldQuantity, recipe.yieldUnit),
                        style: textTheme.headlineSmall?.copyWith(
                          color: AppColors.quantity,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custo',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        recipe.items.isEmpty
                            ? '—'
                            : '${formatCurrency(cost)}${isPartial ? '*' : ''}',
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.quantity,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (recipe.prepTimeMinutes != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tempo de preparo',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          formatMinutes(recipe.prepTimeMinutes!),
                          style: textTheme.titleMedium?.copyWith(
                            color: AppColors.title,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (isPartial)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  '*Custo parcial: algum ingrediente ainda não tem preço',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo para escolher se os itens entram numa lista de compras já aberta
/// ou numa lista nova.
class _ChooseListDialog extends StatelessWidget {
  const _ChooseListDialog({required this.lists});

  final List<ShoppingList> lists;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar à lista de compras'),
      content: SizedBox(
        width: 320,
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Nova lista'),
              onTap: () => Navigator.of(context).pop(_newListId),
            ),
            const Divider(),
            for (final list in lists)
              ListTile(
                leading: const Icon(Icons.checklist),
                title: Text('Lista de ${formatDate(list.createdAt)}'),
                subtitle: Text(
                  '${list.checkedCount} de ${list.items.length} comprados',
                ),
                onTap: () => Navigator.of(context).pop(list.id),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

/// Diálogo que pede quanto da receita a pessoa quer fazer, para calcular a
/// lista de compras a partir das proporções dela.
class _ProduceQuantityDialog extends StatefulWidget {
  const _ProduceQuantityDialog({required this.recipe});

  final Recipe recipe;

  @override
  State<_ProduceQuantityDialog> createState() =>
      _ProduceQuantityDialogState();
}

class _ProduceQuantityDialogState extends State<_ProduceQuantityDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _quantity;
  late Unit _unit;

  @override
  void initState() {
    super.initState();
    _unit = widget.recipe.yieldUnit;
    final text = _unit.fromBase(widget.recipe.yieldQuantity).toStringAsFixed(3);
    final trimmed = text.contains('.')
        ? text.replaceFirst(RegExp(r'\.?0+$'), '')
        : text;
    _quantity = TextEditingController(text: trimmed.replaceAll('.', ','));
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_form.currentState!.validate()) return;
    final value = parseNumber(_quantity.text)!;
    Navigator.of(context).pop((_unit.toBase(value), _unit));
  }

  @override
  Widget build(BuildContext context) {
    final units = widget.recipe.yieldUnit.compatibleUnits;
    return AlertDialog(
      title: const Text('Quanto você quer fazer?'),
      content: Form(
        key: _form,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _quantity,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Quantidade'),
                validator: (text) {
                  final value = parseNumber(text ?? '');
                  return value == null || value <= 0
                      ? 'Informe a quantidade'
                      : null;
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 110,
              child: DropdownButtonFormField<Unit>(
                initialValue: _unit,
                decoration: const InputDecoration(labelText: 'Unidade'),
                items: [
                  for (final unit in units)
                    DropdownMenuItem(value: unit, child: Text(unit.label)),
                ],
                onChanged: (unit) {
                  if (unit != null) setState(() => _unit = unit);
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Calcular lista')),
      ],
    );
  }
}
