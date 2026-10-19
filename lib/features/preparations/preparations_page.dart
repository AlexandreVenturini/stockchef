import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/widgets/item_card.dart';
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
            return const Center(
              child: Text(
                'Nenhum preparo cadastrado\nToque em + para cadastrar',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView(
            children: [
              for (final preparation in preparations)
                ItemCard(
                  icon: Icons.blender_outlined,
                  title: preparation.recipe.name,
                  subtitle:
                      'Rende ${formatQuantity(preparation.recipe.yieldQuantity, preparation.recipe.yieldUnit)}',
                  trailing: formatQuantity(
                    preparation.stockItem.stock,
                    preparation.stockItem.unit,
                  ),
                  alert:
                      preparation.stockItem.isOutOfStock ||
                      preparation.stockItem.isLowStock,
                  badge: preparation.stockItem.isOutOfStock
                      ? 'Sem estoque'
                      : (preparation.stockItem.isLowStock
                            ? 'Estoque baixo'
                            : null),
                  onTap: () => _openForm(preparation.recipe),
                ),
            ],
          );
        },
      ),
    );
  }
}
