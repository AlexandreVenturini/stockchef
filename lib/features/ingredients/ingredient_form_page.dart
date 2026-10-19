import 'package:flutter/material.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets/form_section.dart';
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
  late final TextEditingController _brand;
  late final TextEditingController _stock;
  late final TextEditingController _minStock;
  late Unit _unit;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final item = widget.ingredient;
    _unit = item?.unit ?? Unit.kg;
    _name = TextEditingController(text: item?.name ?? '');
    _brand = TextEditingController(text: item?.brand ?? '');
    _stock = TextEditingController(
      text: formatNumber(_unit.fromBase(item?.stock ?? 0)),
    );
    final minStock = item?.minStock;
    _minStock = TextEditingController(
      text: minStock == null ? '' : formatNumber(_unit.fromBase(minStock)),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _stock.dispose();
    _minStock.dispose();
    super.dispose();
  }

  String? _validateMinStock(String? text) {
    if ((text ?? '').trim().isEmpty) return null;
    final value = parseNumber(text!);
    if (value == null || value < 0) return 'Informe um número válido';
    return null;
  }

  void _convertField(TextEditingController controller, Unit from, Unit to) {
    final value = parseNumber(controller.text);
    if (value == null || !from.isCompatibleWith(to)) return;
    controller.text = formatNumber(to.fromBase(from.toBase(value)));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final old = widget.ingredient;
      final brand = _brand.text.trim();
      final minStock = parseNumber(_minStock.text);
      await _repository.save(
        Ingredient(
          id: old?.id,
          name: _name.text.trim(),
          unit: _unit,
          stock: _unit.toBase(parseNumber(_stock.text)!),
          minStock: minStock == null ? null : _unit.toBase(minStock),
          price: old?.price,
          brand: brand.isEmpty ? null : brand,
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
        actions: [
          if (widget.ingredient != null)
            IconButton(
              tooltip: 'Excluir ingrediente',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _delete,
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FormSection(
                      title: 'Dados do ingrediente',
                      children: [
                        TextFormField(
                          controller: _name,
                          enabled: !_busy,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Nome',
                            prefixIcon: FieldIcon(Icons.inventory_2_outlined),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Informe o nome'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _brand,
                          enabled: !_busy,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Marca (opcional)',
                            prefixIcon: FieldIcon(Icons.sell_outlined),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<Unit>(
                          initialValue: _unit,
                          decoration: const InputDecoration(
                            labelText: 'Unidade',
                            prefixIcon: FieldIcon(Icons.straighten),
                          ),
                          items:
                              (widget.ingredient?.unit.compatibleUnits ??
                                      Unit.values)
                                  .map(
                                    (u) => DropdownMenuItem(
                                      value: u,
                                      child: Text(u.label),
                                    ),
                                  )
                                  .toList(),
                          onChanged: _busy
                              ? null
                              : (unit) {
                                  if (unit == null) return;
                                  setState(() {
                                    _convertField(_stock, _unit, unit);
                                    _convertField(_minStock, _unit, unit);
                                    _unit = unit;
                                  });
                                },
                        ),
                      ],
                    ),
                    FormSection(
                      title: 'Estoque',
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _stock,
                                enabled: !_busy,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Estoque atual',
                                  helperText: 'Pode ser zero ou negativo',
                                  helperMaxLines: 2,
                                ),
                                validator: (value) =>
                                    parseNumber(value ?? '') == null
                                    ? 'Informe um número válido'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _minStock,
                                enabled: !_busy,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Estoque mínimo',
                                  helperText:
                                      'Opcional: avisa quando ficar abaixo',
                                  helperMaxLines: 2,
                                ),
                                validator: _validateMinStock,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                  ),
                  child: Text(_busy ? 'Aguarde...' : 'Salvar'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
