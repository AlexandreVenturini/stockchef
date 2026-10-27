import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets/form_section.dart';
import 'ingredient.dart';
import 'ingredient_repository.dart';
import 'shopping_list.dart';
import 'shopping_list_repository.dart';

/// Tela de criação de uma lista de compras: escolhe os ingredientes e
/// quantidades a comprar. Fecha com `true` quando a lista é criada.
class ShoppingListFormPage extends StatefulWidget {
  const ShoppingListFormPage({super.key});

  @override
  State<ShoppingListFormPage> createState() => _ShoppingListFormPageState();
}

class _ItemDraft {
  _ItemDraft({this.ingredient, String quantity = '', this.unit = Unit.kg})
    : quantity = TextEditingController(text: quantity);

  final Key key = UniqueKey();
  Ingredient? ingredient;
  Unit unit;
  final TextEditingController quantity;

  void dispose() => quantity.dispose();
}

class _ShoppingListFormPageState extends State<ShoppingListFormPage> {
  final _repository = ShoppingListRepository();
  final _ingredientRepository = IngredientRepository();
  final _formKey = GlobalKey<FormState>();
  final _items = <_ItemDraft>[_ItemDraft()];

  late final Future<List<Ingredient>> _ingredientsFuture;
  String? _itemsError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ingredientsFuture = _ingredientRepository.getAll();
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _itemsError = null;
      _items.add(_ItemDraft());
    });
  }

  void _removeItem(_ItemDraft item) {
    setState(() => _items.remove(item));
    item.dispose();
  }

  /// Ingredientes que ainda podem ser escolhidos nesta linha: os que não
  /// estão em outra linha.
  List<Ingredient> _availableFor(_ItemDraft item, List<Ingredient> all) {
    final usedElsewhere = {
      for (final other in _items)
        if (other != item && other.ingredient != null) other.ingredient!.id,
    };
    return all
        .where((ingredient) => !usedElsewhere.contains(ingredient.id))
        .toList();
  }

  String? _validateQuantity(String? text, Unit unit) {
    final value = parseNumber(text ?? '');
    if (value == null) return 'Informe a quantidade';
    if (value <= 0 || unit.toBase(value) <= 0) {
      return 'Precisa ser maior que zero';
    }
    return null;
  }

  Future<void> _save() async {
    final formValid = _formKey.currentState!.validate();
    final hasItems = _items.any((item) => item.ingredient != null);
    setState(() {
      _itemsError = hasItems ? null : 'Adicione ao menos um item';
    });
    if (!formValid || !hasItems) return;

    setState(() => _saving = true);
    try {
      await _repository.create([
        for (final item in _items)
          if (item.ingredient != null)
            ShoppingListItem(
              ingredientId: item.ingredient!.id,
              ingredientName: item.ingredient!.name,
              quantity: item.unit.toBase(parseNumber(item.quantity.text)!),
              unit: item.unit,
            ),
      ]);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar a lista')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova lista de compras')),
      body: FutureBuilder<List<Ingredient>>(
        future: _ingredientsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Não foi possível carregar os ingredientes'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final ingredients = snapshot.data!;
          if (ingredients.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Cadastre ao menos um ingrediente na aba Ingredientes '
                  'antes de criar uma lista de compras',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _buildForm(ingredients);
        },
      ),
    );
  }

  Widget _buildForm(List<Ingredient> ingredients) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                for (final item in _items) _buildItem(item, ingredients),
                if (_itemsError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      _itemsError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _items.length >= ingredients.length
                      ? null
                      : _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar item'),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                ),
                child: Text(_saving ? 'Aguarde...' : 'Criar lista'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(_ItemDraft item, List<Ingredient> ingredients) {
    final ingredient = item.ingredient;
    final units = ingredient?.unit.compatibleUnits ?? Unit.values;

    return Card(
      key: item.key,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: ingredient?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Ingrediente'),
                    items: [
                      for (final option in _availableFor(item, ingredients))
                        DropdownMenuItem(
                          value: option.id,
                          child: Text(
                            option.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    validator: (id) =>
                        id == null ? 'Escolha o ingrediente' : null,
                    onChanged: (id) {
                      if (id == null) return;
                      setState(() {
                        item.ingredient = ingredients.firstWhere(
                          (value) => value.id == id,
                        );
                        if (!item.unit.isCompatibleWith(item.ingredient!.unit)) {
                          item.unit = item.ingredient!.unit;
                        }
                      });
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Remover item',
                  icon: const Icon(Icons.close),
                  onPressed: _items.length > 1
                      ? () => _removeItem(item)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(labelText: 'Quantidade'),
                    validator: (text) => _validateQuantity(text, item.unit),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<Unit>(
                    key: ValueKey('unit-${ingredient?.id}-${item.unit.name}'),
                    initialValue: item.unit,
                    decoration: const InputDecoration(labelText: 'Unidade'),
                    items: [
                      for (final unit in units)
                        DropdownMenuItem(value: unit, child: Text(unit.label)),
                    ],
                    onChanged: (unit) {
                      if (unit != null) setState(() => item.unit = unit);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
