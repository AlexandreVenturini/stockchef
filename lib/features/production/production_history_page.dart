import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/item_card.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/section_title.dart';
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
  String _query = '';

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
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ProductionFormPage()));
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
            return EmptyState(
              icon: Icons.soup_kitchen_outlined,
              title: 'Nenhuma produção registrada',
              message:
                  'Registre o que foi produzido e o estoque é atualizado sozinho',
              actionLabel: 'Registrar primeira produção',
              onAction: _openForm,
            );
          }

          final filtered = productions
              .where(
                (production) => matchesSearch(production.recipeName, _query),
              )
              .toList();
          final days = groupByDay(filtered);
          return Column(
            children: [
              SearchField(
                hint: 'Buscar produções',
                onChanged: (text) => setState(() {
                  _query = text;
                }),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: 'Nenhuma produção encontrada',
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        children: [
                          for (final day in days.entries) ...[
                            SectionTitle(
                              formatDayLabel(day.key),
                              trailing: day.value.length == 1
                                  ? '1 produção'
                                  : '${day.value.length} produções',
                            ),
                            for (final production in day.value)
                              ItemCard(
                                icon: Icons.soup_kitchen_outlined,
                                title: production.recipeName,
                                subtitle: formatTime(production.createdAt),
                                trailing: formatQuantity(
                                  production.quantity,
                                  production.unit,
                                ),
                                onTap: () => _openDetail(production),
                              ),
                          ],
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
