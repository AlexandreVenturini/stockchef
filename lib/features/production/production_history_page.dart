import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import 'production.dart';
import 'production_detail_page.dart';
import 'production_form_page.dart';
import 'production_repository.dart';

class ProductionHistoryPage extends StatefulWidget {
  const ProductionHistoryPage({super.key});

  @override
  State<ProductionHistoryPage> createState() => _ProductionHistoryPageState();
}

class _ProductionHistoryPageState extends State<ProductionHistoryPage> {
  final _repository = ProductionRepository();
  late Future<List<Production>> _history;

  @override
  void initState() {
    super.initState();
    _history = _repository.getHistory();
  }

  void _reload() {
    setState(() {
      _history = _repository.getHistory();
    });
  }

  Future<void> _openDetail(Production production) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductionDetailPage(production: production),
      ),
    );
    if (deleted == true) _reload();
  }

  Future<void> _openForm() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ProductionFormPage()),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produção'),
        actions: [
          IconButton(
            tooltip: 'Registrar produção',
            icon: const Icon(Icons.add),
            onPressed: _openForm,
          ),
        ],
      ),
      body: FutureBuilder<List<Production>>(
        future: _history,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Não foi possível carregar o histórico'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final productions = snapshot.data!;
          if (productions.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma produção registrada\nToque em + para registrar',
                textAlign: TextAlign.center,
              ),
            );
          }

          final days = groupByDay(productions);
          return ListView(
            children: [
              for (final day in days.entries) ...[
                _DayHeader(day: day.key),
                for (final production in day.value)
                  ListTile(
                    title: Text(production.recipeName),
                    subtitle: Text(formatTime(production.createdAt)),
                    trailing: Text(
                      formatQuantity(production.quantity, production.unit),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () => _openDetail(production),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        formatDayLabel(day),
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
