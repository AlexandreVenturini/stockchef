import 'package:flutter/material.dart';
import '../../core/format.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/item_card.dart';
import '../../core/widgets/search_field.dart';
import 'ingredient.dart';
import 'ingredient_form_page.dart';
import 'ingredient_repository.dart';
import 'stock_entry_dialog.dart';

class IngredientsPage extends StatefulWidget {
  const IngredientsPage({super.key});
  @override
  State<IngredientsPage> createState() => _IngredientsPageState();
}

class _IngredientsPageState extends State<IngredientsPage> {
  final _repository = IngredientRepository();
  late Future<List<Ingredient>> _ingredients;
  String _query = '';
  @override
  void initState() {
    super.initState();
    _ingredients = _repository.getAll();
  }

  void _reload() {
    setState(() {
      _ingredients = _repository.getAll();
    });
  }

  Future<void> _edit([Ingredient? item]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => IngredientFormPage(ingredient: item)),
    );
    if (mounted && changed == true) _reload();
  }

  Future<void> _purchase(Ingredient item) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => StockEntryDialog(ingredient: item),
    );
    if (mounted && changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ingredientes'),
      actions: [
        IconButton(
          tooltip: 'Novo ingrediente',
          onPressed: _edit,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: FutureBuilder<List<Ingredient>>(
      future: _ingredients,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _reload,
              child: const Text('Falha ao carregar. Tentar novamente'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Nenhum ingrediente cadastrado',
            message:
                'Cadastre os ingredientes com a quantidade que você tem hoje',
            actionLabel: 'Cadastrar primeiro ingrediente',
            onAction: _edit,
          );
        }
        final items = snapshot.data!
            .where((i) => matchesSearch(i.name, _query))
            .toList();
        return Column(
          children: [
            SearchField(
              hint: 'Buscar ingredientes',
              onChanged: (value) => setState(() => _query = value),
            ),
            Expanded(
              child: items.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off,
                      title: 'Nenhum ingrediente encontrado',
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        _reload();
                        await _ingredients;
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ItemCard(
                            icon: Icons.inventory_2_outlined,
                            title: item.name,
                            subtitle: item.brand,
                            trailing: formatQuantity(item.stock, item.unit),
                            alert: item.isOutOfStock,
                            warning: item.isLowStock,
                            badge: item.isOutOfStock
                                ? 'Sem estoque'
                                : (item.isLowStock ? 'Estoque baixo' : null),
                            onTap: () => _edit(item),
                            actionIcon: Icons.add_shopping_cart,
                            actionTooltip: 'Adicionar ao estoque',
                            onAction: () => _purchase(item),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    ),
  );
}
