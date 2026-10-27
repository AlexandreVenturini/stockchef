import 'package:flutter/material.dart';
import '../../core/format.dart';
import '../../core/units.dart';
import 'ingredient.dart';
import 'ingredient_repository.dart';

class StockEntryDialog extends StatefulWidget {
  const StockEntryDialog({super.key, required this.ingredient});
  final Ingredient ingredient;
  @override
  State<StockEntryDialog> createState() => _StockEntryDialogState();
}

class _StockEntryDialogState extends State<StockEntryDialog> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  late Unit _unit;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _unit = widget.ingredient.unit;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final price = parseNumber(_price.text);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await IngredientRepository().addStock(
        widget.ingredient.id!,
        parseNumber(_quantity.text)!,
        _unit,
        totalPrice: price,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível adicionar ao estoque');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Adicionar ao estoque'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.ingredient.name),
              Text(
                'Estoque atual: ${formatQuantity(widget.ingredient.stock, widget.ingredient.unit)}',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantity,
                enabled: !_busy,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Quantidade comprada',
                ),
                validator: (text) {
                  final value = parseNumber(text ?? '');
                  return value == null || value <= 0 || _unit.toBase(value) <= 0
                      ? 'Informe uma quantidade maior que zero'
                      : null;
                },
              ),
              DropdownButtonFormField<Unit>(
                initialValue: _unit,
                decoration: const InputDecoration(labelText: 'Unidade'),
                items: widget.ingredient.unit.compatibleUnits
                    .map(
                      (u) => DropdownMenuItem(value: u, child: Text(u.label)),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (unit) {
                        if (unit != null) setState(() => _unit = unit);
                      },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _price,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Preço pago (opcional)',
                  helperText: 'Atualiza o preço do ingrediente',
                ),
                validator: (text) {
                  if ((text ?? '').trim().isEmpty) return null;
                  final value = parseNumber(text!);
                  return value == null || value < 0
                      ? 'Informe um preço válido'
                      : null;
                },
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Aguarde...' : 'Adicionar'),
        ),
      ],
    ),
  );
}
