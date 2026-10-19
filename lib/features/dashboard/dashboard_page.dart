import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/item_card.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/stat_card.dart';
import '../ingredients/ingredient.dart';
import '../production/production.dart';
import '../production/production_form_page.dart';
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
  late Future<_DashboardData> _data;

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

  void _reload() {
    setState(() {
      _data = _load();
    });
  }

  Future<void> _refresh() async {
    _reload();
    await _data;
  }

  Future<void> _openProductionForm() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ProductionFormPage()));
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 32),
            const SizedBox(width: AppSpacing.sm),
            const Text.rich(
              TextSpan(
                text: 'Stock',
                children: [
                  TextSpan(
                    text: 'Chef',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ],
              ),
              style: TextStyle(fontSize: 22),
            ),
          ],
        ),
      ),
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
    final missing = data.ingredients
        .where((item) => item.isOutOfStock)
        .toList();
    final low = data.ingredients.where((item) => item.isLowStock).toList();
    final ingredientCount = data.ingredients
        .where((item) => !item.isPreparation)
        .length;
    final preparationCount = data.recipes
        .where((recipe) => recipe.isPreparation)
        .length;
    final recipeCount = data.recipes.length - preparationCount;
    final today = data.todayProductions;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          const _Greeting(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: FilledButton.icon(
              onPressed: _openProductionForm,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Registrar produção'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md - 4),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.inventory_2_outlined,
                        label: 'Ingredientes',
                        value: '$ingredientCount',
                      ),
                    ),
                    Expanded(
                      child: StatCard(
                        icon: Icons.blender_outlined,
                        label: 'Preparos',
                        value: '$preparationCount',
                        color: AppColors.navigationSelected,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.menu_book_outlined,
                        label: 'Receitas',
                        value: '$recipeCount',
                        color: AppColors.quantity,
                      ),
                    ),
                    Expanded(
                      child: StatCard(
                        icon: Icons.soup_kitchen_outlined,
                        label: 'Produções hoje',
                        value: '${today.length}',
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SectionTitle('Em falta', trailing: _countLabel(missing.length)),
          if (missing.isEmpty)
            const _StatusLine('Tudo certo! Nada em falta')
          else
            for (final item in missing)
              _StockCard(item: item, alert: true, badge: 'Sem estoque'),
          SectionTitle('Abaixo do mínimo', trailing: _countLabel(low.length)),
          if (low.isEmpty)
            const _StatusLine('Nada abaixo do mínimo')
          else
            for (final item in low)
              _StockCard(item: item, alert: false, badge: 'Estoque baixo'),
          SectionTitle(
            'Produções de hoje',
            trailing: today.isEmpty ? null : '${today.length}',
          ),
          if (today.isEmpty)
            const _StatusLine('Nada produzido hoje ainda', ok: false)
          else
            for (final production in today)
              ItemCard(
                icon: Icons.soup_kitchen_outlined,
                title: production.recipeName,
                subtitle: formatTime(production.createdAt),
                trailing: formatQuantity(production.quantity, production.unit),
              ),
        ],
      ),
    );
  }

  String? _countLabel(int count) {
    if (count == 0) return null;
    return count == 1 ? '1 item' : '$count itens';
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Olá!',
            style: textTheme.headlineSmall?.copyWith(
              color: AppColors.title,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Veja o resumo do seu estoque',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatLongDate(DateTime.now()),
            style: textTheme.labelMedium?.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({
    required this.item,
    required this.alert,
    required this.badge,
  });

  final Ingredient item;
  final bool alert;
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
      alert: alert,
      warning: !alert,
      badge: badge,
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine(this.text, {this.ok = true});

  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.textSecondary;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.md - 4),
      decoration: BoxDecoration(
        color: ok ? AppColors.successBackground : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.info_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
