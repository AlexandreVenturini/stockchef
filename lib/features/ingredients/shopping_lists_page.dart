import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/item_card.dart';
import 'shopping_list.dart';
import 'shopping_list_detail_page.dart';
import 'shopping_list_form_page.dart';
import 'shopping_list_repository.dart';

class ShoppingListsPage extends StatefulWidget {
  const ShoppingListsPage({super.key});

  @override
  State<ShoppingListsPage> createState() => _ShoppingListsPageState();
}

class _ShoppingListsPageState extends State<ShoppingListsPage> {
  final _repository = ShoppingListRepository();
  late Future<List<ShoppingList>> _lists;

  @override
  void initState() {
    super.initState();
    _lists = _repository.getAll();
  }

  void _reload() {
    setState(() {
      _lists = _repository.getAll();
    });
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ShoppingListFormPage()),
    );
    if (created == true) _reload();
  }

  Future<void> _open(ShoppingList list) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ShoppingListDetailPage(list: list)),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listas de compra'),
        actions: [
          IconButton(
            tooltip: 'Nova lista',
            icon: const Icon(Icons.add),
            onPressed: _create,
          ),
        ],
      ),
      body: FutureBuilder<List<ShoppingList>>(
        future: _lists,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Não foi possível carregar as listas'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final lists = snapshot.data!;
          if (lists.isEmpty) {
            return EmptyState(
              icon: Icons.checklist,
              title: 'Nenhuma lista de compras',
              message:
                  'Crie uma lista com o que precisa comprar e marque os '
                  'itens conforme for comprando',
              actionLabel: 'Criar primeira lista',
              onAction: _create,
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            children: [
              for (final list in lists)
                _ShoppingListCard(list: list, onTap: () => _open(list)),
            ],
          );
        },
      ),
    );
  }
}

class _ShoppingListCard extends StatelessWidget {
  const _ShoppingListCard({required this.list, required this.onTap});

  final ShoppingList list;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = list.items.length;
    final checked = list.checkedCount;

    return ItemCard(
      icon: Icons.checklist,
      title: 'Lista de ${formatDate(list.createdAt)}',
      subtitle: list.isClosed
          ? 'Fechada em ${formatDate(list.closedAt!)}'
          : '$checked de $total comprados',
      trailing: list.isClosed ? 'Fechada' : 'Aberta',
      warning: !list.isClosed,
      onTap: onTap,
    );
  }
}
