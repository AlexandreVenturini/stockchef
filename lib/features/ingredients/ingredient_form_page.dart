import 'package:flutter/material.dart';
import '../../core/format.dart';
import '../../core/units.dart';
import 'ingredient.dart';
import 'ingredient_repository.dart';

class IngredientFormPage extends StatefulWidget {
  const IngredientFormPage({super.key, this.ingredient});
  final Ingredient? ingredient;
  @override
  State<IngredientFormPage> createState() => _IngredientFormPageState();
}

class _IngredientFormPageState extends State<IngredientFormPage> {
  final _form = GlobalKey<FormState>();
  final _repository = IngredientRepository();
  late final TextEditingController _name;
  late final TextEditingController _stock;
  late Unit _unit;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final item = widget.ingredient;
    _unit = item?.unit ?? Unit.kg;
    _name = TextEditingController(text: item?.name ?? '');
    _stock = TextEditingController(
      text: formatNumber(_unit.fromBase(item?.stock ?? 0)),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final old = widget.ingredient;
      await _repository.save(
        Ingredient(
          id: old?.id,
          name: _name.text.trim(),
          unit: _unit,
          stock: _unit.toBase(parseNumber(_stock.text)!),
          minStock: old?.minStock,
          price: old?.price,
          brand: old?.brand,
          isPreparation: old?.isPreparation ?? false,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível salvar o ingrediente');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir ingrediente?'),
        content: Text('Excluir ${widget.ingredient!.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.delete(widget.ingredient!.id!);
      if (mounted) Navigator.pop(context, true);
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message.toString());
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível excluir o ingrediente');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.ingredient == null ? 'Novo ingrediente' : 'Editar ingrediente',
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _name,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Informe o nome'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Unit>(
              initialValue: _unit,
              decoration: const InputDecoration(labelText: 'Unidade'),
              items: (widget.ingredient?.unit.compatibleUnits ?? Unit.values)
                  .map((u) => DropdownMenuItem(value: u, child: Text(u.label)))
                  .toList(),
              onChanged: _busy
                  ? null
                  : (unit) {
                      if (unit == null) return;
                      setState(() {
                        final value = parseNumber(_stock.text);
                        if (value != null && _unit.isCompatibleWith(unit)) {
                          _stock.text = formatNumber(
                            unit.fromBase(_unit.toBase(value)),
                          );
                        }
                        _unit = unit;
                      });
                    },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stock,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Estoque atual',
                helperText: 'Pode ser zero ou negativo',
              ),
              validator: (value) => parseNumber(value ?? '') == null
                  ? 'Informe um número válido'
                  : null,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Aguarde...' : 'Salvar'),
            ),
            if (widget.ingredient != null)
              TextButton(
                onPressed: _busy ? null : _delete,
                child: const Text('Excluir ingrediente'),
              ),
          ],
        ),
      ),
    ),
  );
}
