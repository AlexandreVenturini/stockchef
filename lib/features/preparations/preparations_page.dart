import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/item_card.dart';
import '../../core/widgets/search_field.dart';
import '../recipes/recipe.dart';
import '../recipes/recipe_form_page.dart';
import 'preparation.dart';
import 'preparation_repository.dart';

class PreparationsPage extends StatefulWidget {
  const PreparationsPage({super.key});

  @override
  State<PreparationsPage> createState() => _PreparationsPageState();
}

class _PreparationsPageState extends State<PreparationsPage> {
  final _repository = PreparationRepository();
  late Future<List<Preparation>> _preparations;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _preparations = _repository.getAll();
  }

  void _reload() {
    setState(() {
      _preparations = _repository.getAll();
    });
  }

  Future<void> _openForm([Recipe? recipe]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecipeFormPage(recipe: recipe, isPreparation: true),
      ),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preparos'),
        actions: [
          IconButton(
            tooltip: 'Novo preparo',
            icon: const Icon(Icons.add),
            onPressed: _openForm,
          ),
        ],
      ),
      body: FutureBuilder<List<Preparation>>(
        future: _preparations,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Não foi possível carregar os preparos'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final preparations = snapshot.data!;
          if (preparations.isEmpty) {
            return EmptyState(
              icon: Icons.blender_outlined,
              title: 'Nenhum preparo cadastrado',
              message:
                  'Preparos são bases feitas antes, como caldas e massas, '
                  'que entram em outras receitas',
              actionLabel: 'Cadastrar primeiro preparo',
              onAction: _openForm,
            );
          }

          final filtered = preparations
              .where((item) => matchesSearch(item.recipe.name, _query))
              .toList();
          return Column(
            children: [
              SearchField(
                hint: 'Buscar preparos',
                onChanged: (text) => setState(() {
                  _query = text;
                }),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: 'Nenhum preparo encontrado',
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        children: [
                          for (final preparation in filtered)
                            _PreparationCard(
                              preparation: preparation,
                              onTap: () => _openForm(preparation.recipe),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PreparationCard extends StatelessWidget {
  const _PreparationCard({required this.preparation, required this.onTap});

  final Preparation preparation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final recipe = preparation.recipe;
    final stock = preparation.stockItem;
    return ItemCard(
      icon: Icons.blender_outlined,
      title: recipe.name,
      subtitle:
          'Rendimento: ${formatQuantity(recipe.yieldQuantity, recipe.yieldUnit)}',
      trailing: formatQuantity(stock.stock, stock.unit),
      alert: stock.isOutOfStock,
      warning: stock.isLowStock,
      badge: stock.isOutOfStock
          ? 'Sem estoque'
          : (stock.isLowStock ? 'Estoque baixo' : null),
      onTap: onTap,
    );
  }
}
