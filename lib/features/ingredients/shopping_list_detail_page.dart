import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import 'shopping_list.dart';
import 'shopping_list_repository.dart';

/// Tela de uma lista de compras: marca os itens conforme vai comprando.
/// A lista fecha sozinha (e guarda a data) quando todos os itens são
/// marcados, e os itens marcados já somam no estoque do ingrediente.
class ShoppingListDetailPage extends StatefulWidget {
  const ShoppingListDetailPage({super.key, required this.list});

  final ShoppingList list;

  @override
  State<ShoppingListDetailPage> createState() =>
      _ShoppingListDetailPageState();
}

class _ShoppingListDetailPageState extends State<ShoppingListDetailPage> {
  final _repository = ShoppingListRepository();
  late ShoppingList _list;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _list = widget.list;
  }

  Future<void> _toggle(ShoppingListItem item, bool? checked) async {
    if (checked == null || _busy) return;

    double? pricePaid;
    if (checked) {
      final result = await showDialog<(bool, double?)>(
        context: context,
        builder: (_) => _PricePromptDialog(item: item),
      );
      if (result == null || !result.$1) return;
      pricePaid = result.$2;
    }

    setState(() => _busy = true);
    await _repository.setChecked(
      _list.id!,
      item.id!,
      checked,
      pricePaid: pricePaid,
    );
    final reloaded = await _repository.getById(_list.id!);
    if (!mounted) return;
    setState(() {
      if (reloaded != null) _list = reloaded;
      _busy = false;
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir lista?'),
        content: const Text(
          'Os itens já marcados como comprados são retirados do estoque.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    await _repository.delete(_list.id!);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de compras'),
        actions: [
          IconButton(
            tooltip: 'Excluir lista',
            icon: const Icon(Icons.delete_outline),
            onPressed: _busy ? null : _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusCard(list: list),
            const SizedBox(height: AppSpacing.md),
            for (final item in list.items)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: CheckboxListTile(
                  value: item.checked,
                  onChanged: _busy ? null : (checked) => _toggle(item, checked),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(item.ingredientName),
                  subtitle: Text(
                    item.pricePaid == null
                        ? formatQuantity(item.quantity, item.unit)
                        : '${formatQuantity(item.quantity, item.unit)} · '
                              '${formatCurrency(item.pricePaid!)}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pergunta quanto foi pago pela quantidade deste item ao marcar o check.
/// Retorna (prosseguir?, preço informado). "Pular" prossegue sem preço.
class _PricePromptDialog extends StatefulWidget {
  const _PricePromptDialog({required this.item});

  final ShoppingListItem item;

  @override
  State<_PricePromptDialog> createState() => _PricePromptDialogState();
}

class _PricePromptDialogState extends State<_PricePromptDialog> {
  final _price = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _save() {
    final text = _price.text.trim();
    if (text.isEmpty) {
      Navigator.of(context).pop((true, null));
      return;
    }
    final value = parseNumber(text);
    if (value == null || value < 0) {
      setState(() => _error = 'Informe um preço válido');
      return;
    }
    Navigator.of(context).pop((true, value));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return AlertDialog(
      title: const Text('Quanto você pagou?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item.ingredientName} · ${formatQuantity(item.quantity, item.unit)}',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _price,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Preço pago (opcional)',
              helperText: 'Atualiza o preço do ingrediente',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop((false, null)),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop((true, null)),
          child: const Text('Pular'),
        ),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.list});

  final ShoppingList list;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final total = list.items.length;
    final checked = list.checkedCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Criada em ${formatDate(list.createdAt)}',
                    style: textTheme.bodyMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: list.isClosed
                        ? AppColors.successBackground
                        : AppColors.warningBackground,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Text(
                    list.isClosed ? 'Fechada' : 'Aberta',
                    style: textTheme.labelSmall?.copyWith(
                      color: list.isClosed
                          ? AppColors.success
                          : AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (list.isClosed) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Fechada em ${formatDate(list.closedAt!)}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$checked de $total itens comprados',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
