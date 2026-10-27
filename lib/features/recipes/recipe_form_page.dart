import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets/form_section.dart';
import '../ingredients/ingredient.dart';
import '../ingredients/ingredient_form_page.dart';
import '../ingredients/ingredient_search_field.dart';
import '../preparations/preparation_repository.dart';
import 'recipe.dart';
import 'recipe_repository.dart';

/// Número para preencher um campo de texto: sem separador de milhar, com
/// vírgula decimal (formato que o `parseNumber` entende).
String _plainNumber(double value) {
  final text = value.toStringAsFixed(3);
  final trimmed = text.contains('.')
      ? text.replaceFirst(RegExp(r'\.?0+$'), '')
      : text;
  return trimmed.replaceAll('.', ',');
}

/// Tela de cadastro e edição de receita.
/// Sem [recipe] cria uma nova; com [recipe] edita a existente.
/// Fecha com `true` quando algo foi salvo ou excluído.
class RecipeFormPage extends StatefulWidget {
  const RecipeFormPage({super.key, this.recipe, this.isPreparation = false});

  final Recipe? recipe;
  final bool isPreparation;

  @override
  State<RecipeFormPage> createState() => _RecipeFormPageState();
}

class _ItemDraft {
  _ItemDraft({this.ingredient, String quantity = '', this.unit = Unit.g})
    : quantity = TextEditingController(text: quantity);

  final Key key = UniqueKey();
  Ingredient? ingredient;
  Unit unit;
  final TextEditingController quantity;

  void dispose() => quantity.dispose();
}

class _StepDraft {
  _StepDraft([String description = ''])
    : description = TextEditingController(text: description);

  final Key key = UniqueKey();
  final TextEditingController description;

  void dispose() => description.dispose();
}

class _RecipeFormPageState extends State<RecipeFormPage> {
  final _repository = RecipeRepository();
  final _preparationRepository = PreparationRepository();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _yieldController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _items = <_ItemDraft>[];
  final _steps = <_StepDraft>[];

  late Future<List<Ingredient>> _ingredientsFuture;
  Unit _yieldUnit = Unit.kg;
  bool _saving = false;

  bool get _isEditing => widget.recipe != null;

  bool get _isPreparation =>
      widget.isPreparation || (widget.recipe?.isPreparation ?? false);

  String get _kind => _isPreparation ? 'preparo' : 'receita';

  List<Unit> get _yieldUnits => _isPreparation && _isEditing
      ? widget.recipe!.yieldUnit.compatibleUnits
      : Unit.values;

  List<Ingredient> _selectable(List<Ingredient> all) {
    final ownStock = widget.recipe?.outputIngredientId;
    return all.where((ingredient) => ingredient.id != ownStock).toList();
  }

  @override
  void initState() {
    super.initState();
    _ingredientsFuture = _repository.getIngredients().then(_fillFromRecipe);
  }

  /// Preenche os campos quando está editando. Roda uma vez, depois que os
  /// ingredientes carregaram (os itens precisam do ingrediente para a unidade).
  List<Ingredient> _fillFromRecipe(List<Ingredient> ingredients) {
    final recipe = widget.recipe;
    if (recipe == null) return ingredients;

    final byId = {
      for (final ingredient in ingredients) ingredient.id: ingredient,
    };
    _nameController.text = recipe.name;
    _yieldUnit = recipe.yieldUnit;
    _yieldController.text = _plainNumber(
      recipe.yieldUnit.fromBase(recipe.yieldQuantity),
    );
    if (recipe.prepTimeMinutes != null) {
      _prepTimeController.text = '${recipe.prepTimeMinutes}';
    }
    for (final item in recipe.items) {
      _items.add(
        _ItemDraft(
          ingredient: byId[item.ingredientId],
          quantity: _plainNumber(item.unit.fromBase(item.quantity)),
          unit: item.unit,
        ),
      );
    }
    for (final step in recipe.steps) {
      _steps.add(_StepDraft(step.description));
    }
    return ingredients;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _yieldController.dispose();
    _prepTimeController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(_ItemDraft());
    });
  }

  void _removeItem(_ItemDraft item) {
    setState(() {
      _items.remove(item);
    });
    item.dispose();
  }

  void _selectIngredient(_ItemDraft item, Ingredient ingredient) {
    setState(() {
      item.ingredient = ingredient;
      if (!item.unit.isCompatibleWith(ingredient.unit)) {
        item.unit = ingredient.unit;
      }
    });
  }

  /// Abre o cadastro de ingrediente sem saltar da tela: ao voltar, já
  /// seleciona o ingrediente recém-criado nesta linha.
  Future<void> _createIngredientInline(_ItemDraft item) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const IngredientFormPage()),
    );
    if (!mounted || created != true) return;
    final ingredients = await _repository.getIngredients();
    final newest = ingredients.reduce(
      (a, b) => (a.id ?? 0) > (b.id ?? 0) ? a : b,
    );
    setState(() {
      _ingredientsFuture = Future.value(ingredients);
      _selectIngredient(item, newest);
    });
  }

  /// Ingredientes que ainda podem ser escolhidos nesta linha: os que não
  /// estão em outra linha (o banco não aceita o mesmo ingrediente duas vezes).
  List<Ingredient> _availableFor(_ItemDraft item, List<Ingredient> all) {
    final usedElsewhere = {
      for (final other in _items)
        if (other != item && other.ingredient != null) other.ingredient!.id,
    };
    return _selectable(
      all,
    ).where((ingredient) => !usedElsewhere.contains(ingredient.id)).toList();
  }

  void _addStep() {
    setState(() => _steps.add(_StepDraft()));
  }

  void _removeStep(_StepDraft step) {
    setState(() => _steps.remove(step));
    step.dispose();
  }

  void _moveStep(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _steps.length) return;
    setState(() {
      final step = _steps.removeAt(index);
      _steps.insert(target, step);
    });
  }

  /// Importa os ingredientes de outra receita já cadastrada, escalados pela
  /// proporção entre a quantidade escolhida e o rendimento dela. Ingredientes
  /// já presentes nesta receita têm a quantidade somada.
  Future<void> _importFromRecipe(List<Ingredient> ingredients) async {
    final allRecipes = await _repository.getAll();
    final candidates = allRecipes
        .where((r) => r.id != widget.recipe?.id && r.items.isNotEmpty)
        .toList();
    if (!mounted) return;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma outra receita com ingredientes cadastrada'),
        ),
      );
      return;
    }

    final result = await showDialog<_ImportResult>(
      context: context,
      builder: (_) => _ImportFromRecipeDialog(recipes: candidates),
    );
    if (result == null) return;

    final ingredientsById = {
      for (final ingredient in ingredients) ingredient.id: ingredient,
    };
    final factor = result.producedQuantityBase / result.recipe.yieldQuantity;
    setState(() {
      for (final sourceItem in result.recipe.items) {
        final scaledBase = roundBase(sourceItem.quantity * factor);
        _ItemDraft? existing;
        for (final draft in _items) {
          if (draft.ingredient?.id == sourceItem.ingredientId) {
            existing = draft;
            break;
          }
        }
        if (existing != null) {
          final currentBase = existing.unit.toBase(
            parseNumber(existing.quantity.text) ?? 0,
          );
          existing.quantity.text = _plainNumber(
            existing.unit.fromBase(roundBase(currentBase + scaledBase)),
          );
        } else {
          final ingredient = ingredientsById[sourceItem.ingredientId];
          if (ingredient == null) continue;
          _items.add(
            _ItemDraft(
              ingredient: ingredient,
              quantity: _plainNumber(sourceItem.unit.fromBase(scaledBase)),
              unit: sourceItem.unit,
            ),
          );
        }
      }
    });
  }

  String? _validateQuantity(String? text, Unit unit) {
    final value = parseNumber(text ?? '');
    if (value == null) return 'Informe a quantidade';
    if (value <= 0 || unit.toBase(value) <= 0) {
      return 'Precisa ser maior que zero';
    }
    return null;
  }

  String? _validatePrepTime(String? text) {
    if ((text ?? '').trim().isEmpty) return null;
    final value = int.tryParse(text!.trim());
    if (value == null || value <= 0) return 'Informe um tempo válido';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final prepTime = _prepTimeController.text.trim();
    final nonEmptySteps = _steps
        .where((step) => step.description.text.trim().isNotEmpty)
        .toList();

    final recipe = Recipe(
      id: widget.recipe?.id,
      name: _nameController.text.trim(),
      yieldQuantity: _yieldUnit.toBase(parseNumber(_yieldController.text)!),
      yieldUnit: _yieldUnit,
      outputIngredientId: widget.recipe?.outputIngredientId,
      prepTimeMinutes: prepTime.isEmpty ? null : int.parse(prepTime),
      items: [
        for (final item in _items)
          if (item.ingredient != null)
            RecipeItem(
              ingredientId: item.ingredient!.id!,
              quantity: item.unit.toBase(parseNumber(item.quantity.text)!),
              unit: item.unit,
            ),
      ],
      steps: [
        for (var i = 0; i < nonEmptySteps.length; i++)
          RecipeStep(
            position: i,
            description: nonEmptySteps[i].description.text.trim(),
          ),
      ],
    );

    setState(() => _saving = true);
    try {
      if (_isPreparation) {
        await _preparationRepository.save(recipe);
      } else {
        await _repository.save(recipe);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar o $_kind')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir $_kind?'),
        content: const Text(
          'As produções já registradas continuam no histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      if (_isPreparation) {
        await _preparationRepository.delete(widget.recipe!);
      } else {
        await _repository.delete(widget.recipe!.id!);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isPreparation
                ? 'Não foi possível excluir: o preparo é usado em alguma receita'
                : 'Não foi possível excluir a receita',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Editar $_kind'
              : (_isPreparation ? 'Novo preparo' : 'Nova receita'),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Excluir $_kind',
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _confirmDelete,
            ),
        ],
      ),
      body: FutureBuilder<List<Ingredient>>(
        future: _ingredientsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Não foi possível carregar os ingredientes'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildForm(context, snapshot.data!);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<Ingredient> ingredients) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                FormSection(
                  title: _isPreparation
                      ? 'Dados do preparo'
                      : 'Dados da receita',
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: _isPreparation
                            ? 'Nome do preparo'
                            : 'Nome da receita',
                        prefixIcon: FieldIcon(
                          _isPreparation
                              ? Icons.blender_outlined
                              : Icons.menu_book_outlined,
                        ),
                      ),
                      validator: (text) => (text ?? '').trim().isEmpty
                          ? (_isPreparation
                                ? 'Informe o nome do preparo'
                                : 'Informe o nome da receita')
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _yieldController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: _numberFormatters,
                            decoration: const InputDecoration(
                              labelText: 'Rendimento',
                              prefixIcon: FieldIcon(Icons.scale_outlined),
                            ),
                            validator: (text) =>
                                _validateQuantity(text, _yieldUnit),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        SizedBox(
                          width: 110,
                          child: DropdownButtonFormField<Unit>(
                            initialValue: _yieldUnit,
                            decoration: const InputDecoration(
                              labelText: 'Unidade',
                            ),
                            items: [
                              for (final unit in _yieldUnits)
                                DropdownMenuItem(
                                  value: unit,
                                  child: Text(unit.label),
                                ),
                            ],
                            onChanged: (unit) {
                              if (unit != null) {
                                setState(() => _yieldUnit = unit);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _prepTimeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Tempo de preparo em minutos (opcional)',
                        prefixIcon: FieldIcon(Icons.timer_outlined),
                      ),
                      validator: _validatePrepTime,
                    ),
                  ],
                ),
                Text(
                  'Ingredientes',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.title,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final item in _items) _buildItem(item, ingredients),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar ingrediente'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _importFromRecipe(ingredients),
                        icon: const Icon(Icons.library_add_outlined),
                        label: const Text(
                          'Importar de outra receita',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Modo de preparo',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.title,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < _steps.length; i++)
                  _buildStep(i, _steps[i]),
                OutlinedButton.icon(
                  onPressed: _addStep,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar etapa'),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                ),
                child: Text(_saving ? 'Aguarde...' : 'Salvar $_kind'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(_ItemDraft item, List<Ingredient> ingredients) {
    final ingredient = item.ingredient;
    final units = ingredient?.unit.compatibleUnits ?? Unit.values;

    return Card(
      key: item.key,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: IngredientSearchField(
                    options: _availableFor(item, ingredients),
                    selected: ingredient,
                    onSelected: (selected) => _selectIngredient(item, selected),
                    onCreateNew: () => _createIngredientInline(item),
                  ),
                ),
                IconButton(
                  tooltip: 'Remover ingrediente',
                  icon: const Icon(Icons.close),
                  onPressed: () => _removeItem(item),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: _numberFormatters,
                    decoration: const InputDecoration(labelText: 'Quantidade'),
                    validator: (text) => _validateQuantity(text, item.unit),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<Unit>(
                    // A chave muda com o ingrediente para o campo recarregar
                    // a unidade quando ela é ajustada automaticamente.
                    key: ValueKey('unit-${ingredient?.id}-${item.unit.name}'),
                    initialValue: item.unit,
                    decoration: const InputDecoration(labelText: 'Unidade'),
                    items: [
                      for (final unit in units)
                        DropdownMenuItem(value: unit, child: Text(unit.label)),
                    ],
                    onChanged: (unit) {
                      if (unit != null) setState(() => item.unit = unit);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int index, _StepDraft step) {
    return Card(
      key: step.key,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.iconBackground,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextFormField(
                controller: step.description,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'O que fazer'),
              ),
            ),
            Column(
              children: [
                IconButton(
                  tooltip: 'Mover para cima',
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: index == 0 ? null : () => _moveStep(index, -1),
                ),
                IconButton(
                  tooltip: 'Mover para baixo',
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: index == _steps.length - 1
                      ? null
                      : () => _moveStep(index, 1),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Remover etapa',
              icon: const Icon(Icons.close),
              onPressed: () => _removeStep(step),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportResult {
  const _ImportResult({required this.recipe, required this.producedQuantityBase});

  final Recipe recipe;
  final double producedQuantityBase;
}

/// Diálogo para escolher uma receita já cadastrada e a quantidade a usar
/// dela; o chamador escala os ingredientes pela proporção.
class _ImportFromRecipeDialog extends StatefulWidget {
  const _ImportFromRecipeDialog({required this.recipes});

  final List<Recipe> recipes;

  @override
  State<_ImportFromRecipeDialog> createState() =>
      _ImportFromRecipeDialogState();
}

class _ImportFromRecipeDialogState extends State<_ImportFromRecipeDialog> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  Recipe? _recipe;
  Unit _unit = Unit.kg;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  void _selectRecipe(Recipe recipe) {
    setState(() {
      _recipe = recipe;
      _unit = recipe.yieldUnit;
      _quantity.text = _plainNumber(recipe.yieldUnit.fromBase(recipe.yieldQuantity));
    });
  }

  void _confirm() {
    if (!_form.currentState!.validate() || _recipe == null) return;
    final value = parseNumber(_quantity.text)!;
    Navigator.of(context).pop(
      _ImportResult(
        recipe: _recipe!,
        producedQuantityBase: _unit.toBase(value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipe = _recipe;
    final units = recipe?.yieldUnit.compatibleUnits ?? Unit.values;

    return AlertDialog(
      title: const Text('Importar ingredientes de outra receita'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<int>(
                initialValue: recipe?.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Receita'),
                items: [
                  for (final option in widget.recipes)
                    DropdownMenuItem(
                      value: option.id,
                      child: Text(option.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                validator: (id) => id == null ? 'Escolha a receita' : null,
                onChanged: (id) {
                  if (id == null) return;
                  _selectRecipe(
                    widget.recipes.firstWhere((option) => option.id == id),
                  );
                },
              ),
              if (recipe != null) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantity,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Quantidade a usar',
                        ),
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
                        key: ValueKey('unit-${recipe.id}-${_unit.name}'),
                        initialValue: _unit,
                        decoration: const InputDecoration(labelText: 'Unidade'),
                        items: [
                          for (final unit in units)
                            DropdownMenuItem(
                              value: unit,
                              child: Text(unit.label),
                            ),
                        ],
                        onChanged: (unit) {
                          if (unit != null) setState(() => _unit = unit);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Adicionar')),
      ],
    );
  }
}

final _numberFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
];
