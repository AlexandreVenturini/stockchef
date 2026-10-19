import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/item_card.dart';
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
  late Future<List<Recipe>> _recipes;

  @override
  void initState() {
    super.initState();
    _recipes = _repository.getAll();
  }

  void _reload() {
    setState(() {
      _recipes = _repository.getAll();
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
      body: FutureBuilder<List<Recipe>>(
        future: _recipes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Não foi possível carregar as receitas'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final recipes = snapshot.data!
              .where((recipe) => !recipe.isPreparation)
              .toList();
          if (recipes.isEmpty) {
            return const Center(child: Text('Nenhuma receita cadastrada'));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: 88),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              final count = recipe.items.length;
              return ItemCard(
                icon: Icons.menu_book_outlined,
                title: recipe.name,
                subtitle:
                    '$count ${count == 1 ? 'ingrediente' : 'ingredientes'}',
                trailing:
                    'Rende ${formatQuantity(recipe.yieldQuantity, recipe.yieldUnit)}',
                onTap: () => _openForm(recipe),
              );
            },
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
