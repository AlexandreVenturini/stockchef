import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets/form_section.dart';
import '../ingredients/ingredient.dart';
import '../preparations/preparation_repository.dart';
import 'recipe.dart';
import 'recipe_repository.dart';

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

class _RecipeFormPageState extends State<RecipeFormPage> {
  final _repository = RecipeRepository();
  final _preparationRepository = PreparationRepository();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _yieldController = TextEditingController();
  final _items = <_ItemDraft>[];

  late final Future<List<Ingredient>> _ingredientsFuture;
  Unit _yieldUnit = Unit.kg;
  String? _itemsError;
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
    for (final item in recipe.items) {
      _items.add(
        _ItemDraft(
          ingredient: byId[item.ingredientId],
          quantity: _plainNumber(item.unit.fromBase(item.quantity)),
          unit: item.unit,
        ),
      );
    }
    return ingredients;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _yieldController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  /// Número para preencher um campo de texto: sem separador de milhar,
  /// com vírgula decimal (formato que o `parseNumber` entende).
  String _plainNumber(double value) {
    final text = value.toStringAsFixed(3);
    final trimmed = text.contains('.')
        ? text.replaceFirst(RegExp(r'\.?0+$'), '')
        : text;
    return trimmed.replaceAll('.', ',');
  }

  void _addItem() {
    setState(() {
      _itemsError = null;
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

  String? _validateQuantity(String? text, Unit unit) {
    final value = parseNumber(text ?? '');
    if (value == null) return 'Informe a quantidade';
    if (value <= 0 || unit.toBase(value) <= 0) {
      return 'Precisa ser maior que zero';
    }
    return null;
  }

  Future<void> _save() async {
    final formValid = _formKey.currentState!.validate();
    final hasItems = _items.isNotEmpty;
    setState(() {
      _itemsError = hasItems ? null : 'Adicione ao menos um ingrediente';
    });
    if (!formValid || !hasItems) return;

    final recipe = Recipe(
      id: widget.recipe?.id,
      name: _nameController.text.trim(),
      yieldQuantity: _yieldUnit.toBase(parseNumber(_yieldController.text)!),
      yieldUnit: _yieldUnit,
      outputIngredientId: widget.recipe?.outputIngredientId,
      items: [
        for (final item in _items)
          RecipeItem(
            ingredientId: item.ingredient!.id!,
            quantity: item.unit.toBase(parseNumber(item.quantity.text)!),
            unit: item.unit,
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

    if (ingredients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Cadastre ao menos um ingrediente na aba Ingredientes '
            'antes de criar ${_isPreparation ? 'um preparo' : 'uma receita'}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

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
                if (_itemsError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      _itemsError!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _items.length >= _selectable(ingredients).length
                      ? null
                      : _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar ingrediente'),
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
                child: Text('Salvar $_kind'),
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
                  child: DropdownButtonFormField<int>(
                    initialValue: ingredient?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Ingrediente'),
                    items: [
                      for (final option in _availableFor(item, ingredients))
                        DropdownMenuItem(
                          value: option.id,
                          child: Text(
                            option.isPreparation
                                ? '${option.name} (preparo)'
                                : option.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    validator: (id) =>
                        id == null ? 'Escolha o ingrediente' : null,
                    onChanged: (id) {
                      if (id == null) return;
                      _selectIngredient(
                        item,
                        ingredients.firstWhere((value) => value.id == id),
                      );
                    },
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
}

final _numberFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
];
