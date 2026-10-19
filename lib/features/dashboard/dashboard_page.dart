import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/item_card.dart';
import '../ingredients/ingredient.dart';
import '../production/production.dart';
import '../production/production_repository.dart';
import '../recipes/recipe.dart';
import '../recipes/recipe_repository.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardData {
  const _DashboardData({
    required this.ingredients,
    required this.recipes,
    required this.todayProductions,
  });

  final List<Ingredient> ingredients;
  final List<Recipe> recipes;
  final List<Production> todayProductions;
}

class _DashboardPageState extends State<DashboardPage> {
  late final Future<_DashboardData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_DashboardData> _load() async {
    final recipeRepository = RecipeRepository();
    final ingredients = await recipeRepository.getIngredients();
    final recipes = await recipeRepository.getAll();
    final history = await ProductionRepository().getHistory();
    final today = toDateKey(DateTime.now());
    return _DashboardData(
      ingredients: ingredients,
      recipes: recipes,
      todayProductions: history
          .where((production) => toDateKey(production.date) == today)
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Início')),
      body: FutureBuilder<_DashboardData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Não foi possível carregar o resumo'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildContent(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildContent(_DashboardData data) {
    final missing = data.ingredients.where((item) => item.isOutOfStock);
    final low = data.ingredients.where((item) => item.isLowStock);
    final ingredientCount = data.ingredients
        .where((item) => !item.isPreparation)
        .length;
    final preparationCount = data.recipes
        .where((recipe) => recipe.isPreparation)
        .length;
    final recipeCount = data.recipes.length - preparationCount;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              _TotalCard(label: 'Ingredientes', value: ingredientCount),
              _TotalCard(label: 'Preparos', value: preparationCount),
              _TotalCard(label: 'Receitas', value: recipeCount),
            ],
          ),
        ),
        const _SectionTitle('Em falta'),
        if (missing.isEmpty) const _EmptyLine('Nada em falta'),
        for (final item in missing)
          _StockCard(item: item, badge: 'Sem estoque'),
        const _SectionTitle('Abaixo do mínimo'),
        if (low.isEmpty) const _EmptyLine('Nada abaixo do mínimo'),
        for (final item in low) _StockCard(item: item, badge: 'Estoque baixo'),
        const _SectionTitle('Produções de hoje'),
        if (data.todayProductions.isEmpty)
          const _EmptyLine('Nenhuma produção hoje'),
        for (final production in data.todayProductions)
          ItemCard(
            icon: Icons.soup_kitchen_outlined,
            title: production.recipeName,
            subtitle: formatTime(production.createdAt),
            trailing: formatQuantity(production.quantity, production.unit),
          ),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(AppSpacing.xs),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            children: [
              Text(
                '$value',
                style: textTheme.headlineSmall?.copyWith(
                  color: AppColors.quantity,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.item, required this.badge});

  final Ingredient item;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return ItemCard(
      icon: item.isPreparation
          ? Icons.blender_outlined
          : Icons.inventory_2_outlined,
      title: item.name,
      subtitle: item.isPreparation ? 'Preparo' : item.brand,
      trailing: formatQuantity(item.stock, item.unit),
      alert: true,
      badge: badge,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
