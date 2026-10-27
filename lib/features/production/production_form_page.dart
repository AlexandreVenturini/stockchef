import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets/form_section.dart';
import '../ingredients/ingredient.dart';
import '../recipes/recipe.dart';
import '../recipes/recipe_repository.dart';
import 'production.dart';
import 'production_calculator.dart';
import 'production_repository.dart';

/// Tela de registro e edição de produção.
/// Sem [production] registra uma nova; com [production] edita a existente.
class ProductionFormPage extends StatefulWidget {
  const ProductionFormPage({super.key, this.production});

  final Production? production;

  @override
  State<ProductionFormPage> createState() => _ProductionFormPageState();
}

class _ProductionFormPageState extends State<ProductionFormPage> {
  final _recipeRepository = RecipeRepository();
  final _productionRepository = ProductionRepository();
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();

  late final Future<void> _loading;
  List<Recipe> _recipes = [];
  List<Ingredient> _ingredients = [];
  Recipe? _recipe;
  Unit _unit = Unit.kg;
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool get _isEditing => widget.production != null;

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  Future<void> _load() async {
    _recipes = await _recipeRepository.getAll();
    _ingredients = await _recipeRepository.getIngredients();

    final production = widget.production;
    if (production != null) {
      _date = production.date;
      _unit = production.unit;
      _quantityController.text = _plainNumber(
        production.unit.fromBase(production.quantity),
      );
      if (production.recipeId != null) {
        for (final recipe in _recipes) {
          if (recipe.id == production.recipeId) {
            _recipe = recipe;
            break;
          }
        }
      }
    }
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

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  ProductionPlan? get _plan {
    final recipe = _recipe;
    final value = parseNumber(_quantityController.text);
    if (recipe == null || value == null) return null;
    final produced = _unit.toBase(value);
    if (produced <= 0) return null;
    return planProduction(
      recipe: recipe,
      producedQuantity: produced,
      ingredients: _ingredients,
    );
  }

  void _selectRecipe(int id) {
    setState(() {
      _recipe = _recipes.firstWhere((recipe) => recipe.id == id);
      _unit = _recipe!.yieldUnit;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
    });
  }

  String? _validateQuantity(String? text) {
    final value = parseNumber(text ?? '');
    if (value == null) return 'Informe a quantidade';
    if (_unit.toBase(value) <= 0) return 'Precisa ser maior que zero';
    return null;
  }

  Future<bool> _confirmShortage(ProductionPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Falta ingrediente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final consumption in plan.shortages)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  '${consumption.ingredient.name}: tem '
                  '${formatQuantity(consumption.ingredient.stock, consumption.ingredient.unit)}'
                  ', precisa de '
                  '${formatQuantity(consumption.quantity, consumption.ingredient.unit)}',
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            const Text('Salvar mesmo assim? O estoque vai ficar negativo.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salvar mesmo assim'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final plan = _plan;
    if (plan == null) return;
    final willAffectStock = productionAffectsStock(_date);
    if (plan.hasShortage && willAffectStock && !await _confirmShortage(plan)) {
      return;
    }

    setState(() {
      _saving = true;
    });
    try {
      if (_isEditing) {
        await _productionRepository.update(
          id: widget.production!.id!,
          plan: plan,
          date: _date,
          unit: _unit,
        );
      } else {
        await _productionRepository.save(plan: plan, date: _date, unit: _unit);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Não foi possível salvar a produção'
                : 'Não foi possível registrar a produção',
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
        title: Text(_isEditing ? 'Editar produção' : 'Nova produção'),
      ),
      body: FutureBuilder<void>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Não foi possível carregar as receitas'),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_recipes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Cadastre uma receita na aba Receitas '
                  'antes de registrar uma produção',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _buildForm(context);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final plan = _plan;
    final units = _recipe?.yieldUnit.compatibleUnits ?? Unit.values;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FormSection(
                    title: 'O que foi produzido',
                    children: [
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Data',
                            prefixIcon: FieldIcon(
                              Icons.calendar_today_outlined,
                            ),
                          ),
                          child: Text(
                            '${formatDayLabel(_date)} · ${formatDate(_date)}',
                          ),
                        ),
                      ),
                      if (!productionAffectsStock(_date)) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _RetroactiveNote(date: _date),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<int>(
                        initialValue: _recipe?.id,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Receita ou preparo',
                          prefixIcon: FieldIcon(Icons.menu_book_outlined),
                        ),
                        items: [
                          for (final recipe in _recipes)
                            DropdownMenuItem(
                              value: recipe.id,
                              child: Text(
                                recipe.isPreparation
                                    ? '${recipe.name} (preparo)'
                                    : recipe.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        validator: (id) =>
                            id == null ? 'Escolha a receita' : null,
                        onChanged: (id) {
                          if (id != null) _selectRecipe(id);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _quantityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Quantidade produzida',
                                prefixIcon: FieldIcon(Icons.scale_outlined),
                              ),
                              validator: _validateQuantity,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          SizedBox(
                            width: 110,
                            child: DropdownButtonFormField<Unit>(
                              key: ValueKey(
                                'unit-${_recipe?.id}-${_unit.name}',
                              ),
                              initialValue: _unit,
                              decoration: const InputDecoration(
                                labelText: 'Unidade',
                              ),
                              items: [
                                for (final unit in units)
                                  DropdownMenuItem(
                                    value: unit,
                                    child: Text(unit.label),
                                  ),
                              ],
                              onChanged: (unit) {
                                if (unit == null) return;
                                setState(() {
                                  _unit = unit;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (plan != null) ...[
                    _PlanBanner(hasShortage: plan.hasShortage),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Vai sair do estoque',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final consumption in plan.consumptions)
                      _ConsumptionTile(consumption: consumption),
                    if (plan.recipe.isPreparation)
                      Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ListTile(
                          title: Text(
                            'Vai entrar no estoque: ${plan.recipe.name}',
                          ),
                          trailing: Text(
                            '+${formatQuantity(plan.producedQuantity, plan.recipe.yieldUnit)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.quantity,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
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
                child: Text(
                  _saving
                      ? 'Aguarde...'
                      : (_isEditing ? 'Salvar alterações' : 'Salvar produção'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RetroactiveNote extends StatelessWidget {
  const _RetroactiveNote({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md - 4),
      decoration: BoxDecoration(
        color: AppColors.warningBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Data retroativa (${formatDate(date)}): essa produção não vai '
              'abater o estoque atual, fica só no histórico.',
              style: const TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanBanner extends StatelessWidget {
  const _PlanBanner({required this.hasShortage});

  final bool hasShortage;

  @override
  Widget build(BuildContext context) {
    final color = hasShortage ? AppColors.alert : AppColors.success;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md - 4),
      decoration: BoxDecoration(
        color: hasShortage
            ? AppColors.alertBackground
            : AppColors.successBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            hasShortage
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              hasShortage
                  ? 'Falta ingrediente para essa produção. Você ainda pode salvar.'
                  : 'Tem estoque para tudo',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsumptionTile extends StatelessWidget {
  const _ConsumptionTile({required this.consumption});

  final Consumption consumption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ingredient = consumption.ingredient;
    final color = consumption.isShort ? theme.colorScheme.error : null;
    final status = consumption.isShort
        ? 'faltam ${formatQuantity(consumption.missing, ingredient.unit)}'
        : 'fica ${formatQuantity(consumption.remaining, ingredient.unit)}';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        title: Text(ingredient.name),
        subtitle: Text(
          'Tem ${formatQuantity(ingredient.stock, ingredient.unit)} · $status',
          style: TextStyle(color: color),
        ),
        trailing: Text(
          formatQuantity(consumption.quantity, ingredient.unit),
          style: theme.textTheme.titleMedium?.copyWith(color: color),
        ),
      ),
    );
  }
}
