import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import 'production.dart';
import 'production_repository.dart';

class ProductionDetailPage extends StatefulWidget {
  const ProductionDetailPage({super.key, required this.production});

  final Production production;

  @override
  State<ProductionDetailPage> createState() => _ProductionDetailPageState();
}

class _ProductionDetailPageState extends State<ProductionDetailPage> {
  final _repository = ProductionRepository();
  bool _deleting = false;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir produção?'),
        content: const Text(
          'Os ingredientes consumidos voltam para o estoque.',
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

    setState(() => _deleting = true);
    await _repository.delete(widget.production.id!);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final production = widget.production;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(production.recipeName)),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Data'),
            trailing: Text(formatDate(production.date)),
          ),
          ListTile(
            title: const Text('Quantidade produzida'),
            trailing: Text(
              formatQuantity(production.quantity, production.unit),
              style: theme.textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(
              'Ingredientes consumidos',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          for (final item in production.items)
            ListTile(
              title: Text(item.ingredientName),
              trailing: Text(formatQuantity(item.quantity, item.unit)),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: OutlinedButton.icon(
            onPressed: _deleting ? null : _confirmDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Excluir produção'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
            ),
          ),
        ),
      ),
    );
  }
}
