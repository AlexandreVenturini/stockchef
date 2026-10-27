import 'package:flutter/material.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/item_card.dart';
import '../../core/widgets/search_field.dart';
import 'ingredient.dart';
import 'ingredient_form_page.dart';
import 'ingredient_repository.dart';
import 'shopping_lists_page.dart';
import 'stock_entry_dialog.dart';

enum _StockFilter { all, outOfStock, lowStock }

enum _SortKey { name, price, stock }

class IngredientsPage extends StatefulWidget {
  const IngredientsPage({super.key});
  @override
  State<IngredientsPage> createState() => _IngredientsPageState();
}

class _IngredientsPageState extends State<IngredientsPage> {
  final _repository = IngredientRepository();
  late Future<List<Ingredient>> _ingredients;
  String _query = '';
  _StockFilter _stockFilter = _StockFilter.all;
  String? _unitFilter;
  String? _brandFilter;
  _SortKey _sortKey = _SortKey.name;

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

  Future<void> _openShoppingLists() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const ShoppingListsPage()));
    if (mounted) _reload();
  }

  List<Ingredient> _applyFilters(List<Ingredient> all) {
    var items = all.where((i) => matchesSearch(i.name, _query)).toList();
    switch (_stockFilter) {
      case _StockFilter.all:
        break;
      case _StockFilter.outOfStock:
        items = items.where((i) => i.isOutOfStock).toList();
      case _StockFilter.lowStock:
        items = items.where((i) => i.isLowStock).toList();
    }
    if (_unitFilter != null) {
      items = items.where((i) => i.unit.name == _unitFilter).toList();
    }
    if (_brandFilter != null) {
      items = items.where((i) => i.brand == _brandFilter).toList();
    }
    switch (_sortKey) {
      case _SortKey.name:
        items.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _SortKey.price:
        items.sort((a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
      case _SortKey.stock:
        items.sort((a, b) => a.stock.compareTo(b.stock));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ingredientes'),
      actions: [
        PopupMenuButton<_SortKey>(
          tooltip: 'Ordenar',
          icon: const Icon(Icons.sort),
          initialValue: _sortKey,
          onSelected: (key) => setState(() => _sortKey = key),
          itemBuilder: (context) => const [
            PopupMenuItem(value: _SortKey.name, child: Text('Nome')),
            PopupMenuItem(value: _SortKey.price, child: Text('Preço')),
            PopupMenuItem(value: _SortKey.stock, child: Text('Estoque')),
          ],
        ),
        IconButton(
          tooltip: 'Listas de compra',
          onPressed: _openShoppingLists,
          icon: const Icon(Icons.checklist),
        ),
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
        final all = snapshot.data!;
        if (all.isEmpty) {
          return EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Nenhum ingrediente cadastrado',
            message:
                'Cadastre os ingredientes com a quantidade que você tem hoje',
            actionLabel: 'Cadastrar primeiro ingrediente',
            onAction: _edit,
          );
        }
        final brands =
            {
              for (final i in all)
                if (i.brand != null) i.brand!,
            }.toList()
              ..sort();
        final units = {for (final i in all) i.unit}.toList()
          ..sort((a, b) => a.label.compareTo(b.label));
        final items = _applyFilters(all);
        return Column(
          children: [
            SearchField(
              hint: 'Buscar ingredientes',
              onChanged: (value) => setState(() => _query = value),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _StockFilterChip(
                      value: _stockFilter,
                      onChanged: (value) =>
                          setState(() => _stockFilter = value),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _FilterDropdown<String?>(
                      label: 'Unidade',
                      value: _unitFilter,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todas as unidades'),
                        ),
                        for (final unit in units)
                          DropdownMenuItem(
                            value: unit.name,
                            child: Text(unit.label),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _unitFilter = value),
                    ),
                    if (brands.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _FilterDropdown<String?>(
                        label: 'Marca',
                        value: _brandFilter,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todas as marcas'),
                          ),
                          for (final brand in brands)
                            DropdownMenuItem(value: brand, child: Text(brand)),
                        ],
                        onChanged: (value) =>
                            setState(() => _brandFilter = value),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
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
                          final priceText = item.price == null
                              ? null
                              : formatUnitPrice(item.price!, item.unit);
                          final subtitleParts = [
                            if (item.brand != null) item.brand!,
                            if (priceText != null) priceText,
                          ];
                          return ItemCard(
                            icon: Icons.inventory_2_outlined,
                            title: item.name,
                            subtitle: subtitleParts.isEmpty
                                ? null
                                : subtitleParts.join(' · '),
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

class _StockFilterChip extends StatelessWidget {
  const _StockFilterChip({required this.value, required this.onChanged});

  final _StockFilter value;
  final ValueChanged<_StockFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = {
      _StockFilter.all: 'Todos',
      _StockFilter.outOfStock: 'Sem estoque',
      _StockFilter.lowStock: 'Abaixo do mínimo',
    };
    return Row(
      children: [
        for (final option in _StockFilter.values)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: ChoiceChip(
              label: Text(labels[option]!),
              selected: value == option,
              onSelected: (_) => onChanged(option),
            ),
          ),
      ],
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: (selected) => onChanged(selected as T),
          hint: Text(label),
        ),
      ),
    );
  }
}
