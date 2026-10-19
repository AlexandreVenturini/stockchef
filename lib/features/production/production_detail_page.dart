import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/item_card.dart';
import '../../core/widgets/section_title.dart';
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
    final consumed = production.items.where((i) => i.quantity > 0).toList();
    final produced = production.items.where((i) => i.quantity < 0).toList();

    return Scaffold(
      appBar: AppBar(title: Text(production.recipeName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryCard(production: production),
            SectionTitle(
              'Ingredientes consumidos',
              trailing: consumed.length == 1
                  ? '1 item'
                  : '${consumed.length} itens',
            ),
            for (final item in consumed)
              ItemCard(
                icon: Icons.inventory_2_outlined,
                title: item.ingredientName,
                trailing: formatQuantity(item.quantity, item.unit),
              ),
            if (produced.isNotEmpty) const SectionTitle('Entrou no estoque'),
            for (final item in produced)
              ItemCard(
                icon: Icons.blender_outlined,
                title: item.ingredientName,
                trailing: '+${formatQuantity(-item.quantity, item.unit)}',
              ),
          ],
        ),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.production});

  final Production production;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dayLabel = formatDayLabel(production.date);
    final date = formatDate(production.date);
    final dateText = dayLabel == date ? date : '$dayLabel · $date';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.iconBackground,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.soup_kitchen_outlined,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quantidade produzida',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    formatQuantity(production.quantity, production.unit),
                    style: textTheme.headlineSmall?.copyWith(
                      color: AppColors.quantity,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '$dateText às ${formatTime(production.createdAt)}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
