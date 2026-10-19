import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/search_field.dart';
import 'recipe.dart';
import 'recipe_form_page.dart';
import 'recipe_repository.dart';

class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key});

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  final _repository = RecipeRepository();
  late Future<(List<Recipe>, Map<int, String>)> _data;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<(List<Recipe>, Map<int, String>)> _load() async {
    final recipes = await _repository.getAll();
    final ingredients = await _repository.getIngredients();
    return (
      recipes,
      {for (final ingredient in ingredients) ingredient.id!: ingredient.name},
    );
  }

  void _reload() {
    setState(() {
      _data = _load();
    });
  }

  Future<void> _openForm([Recipe? recipe]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RecipeFormPage(recipe: recipe)),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receitas')),
      body: FutureBuilder<(List<Recipe>, Map<int, String>)>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Não foi possível carregar as receitas'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final (allRecipes, names) = snapshot.data!;
          final recipes = allRecipes
              .where((recipe) => !recipe.isPreparation)
              .toList();
          if (recipes.isEmpty) {
            return EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Nenhuma receita cadastrada',
              message:
                  'Cadastre suas receitas com os ingredientes e quanto cada uma rende',
              actionLabel: 'Cadastrar primeira receita',
              onAction: _openForm,
            );
          }

          final filtered = recipes
              .where((recipe) => matchesSearch(recipe.name, _query))
              .toList();
          return Column(
            children: [
              SearchField(
                hint: 'Buscar receitas',
                onChanged: (text) => setState(() {
                  _query = text;
                }),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: 'Nenhuma receita encontrada',
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 88),
                        children: [
                          for (final recipe in filtered)
                            _RecipeCard(
                              recipe: recipe,
                              ingredientNames: [
                                for (final item in recipe.items)
                                  names[item.ingredientId] ?? '',
                              ],
                              onTap: () => _openForm(recipe),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Nova receita'),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.ingredientNames,
    required this.onTap,
  });

  final Recipe recipe;
  final List<String> ingredientNames;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final count = recipe.items.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.iconBackground,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Rende ${formatQuantity(recipe.yieldQuantity, recipe.yieldUnit)}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.quantity,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '$count ${count == 1 ? 'ingrediente' : 'ingredientes'}',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      ingredientNames.join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
