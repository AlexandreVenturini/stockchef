import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets/search_field.dart' show matchesSearch;
import 'ingredient.dart';

/// Campo de busca com autocompletar para escolher um ingrediente dentre
/// [options]: digita e filtra pelo nome (e marca, se houver). Quando
/// [onCreateNew] é informado, mostra um botão para cadastrar um ingrediente
/// novo sem sair da tela.
class IngredientSearchField extends StatefulWidget {
  const IngredientSearchField({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.onCreateNew,
    this.errorText,
    this.label = 'Ingrediente',
  });

  final List<Ingredient> options;
  final Ingredient? selected;
  final ValueChanged<Ingredient> onSelected;
  final VoidCallback? onCreateNew;
  final String? errorText;
  final String label;

  @override
  State<IngredientSearchField> createState() => _IngredientSearchFieldState();
}

class _IngredientSearchFieldState extends State<IngredientSearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.selected?.name ?? '');
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(IngredientSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected?.id != oldWidget.selected?.id) {
      _controller.text = widget.selected?.name ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Iterable<Ingredient> _optionsFor(TextEditingValue value) {
    if (value.text.isEmpty) return widget.options;
    return widget.options.where(
      (option) =>
          matchesSearch(option.name, value.text) ||
          (option.brand != null && matchesSearch(option.brand!, value.text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Ingredient>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: _optionsFor,
      displayStringForOption: (option) => option.name,
      onSelected: widget.onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            errorText: widget.errorText,
            suffixIcon: widget.onCreateNew == null
                ? null
                : IconButton(
                    tooltip: 'Novo ingrediente',
                    icon: const Icon(Icons.add),
                    onPressed: widget.onCreateNew,
                  ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 360),
              child: list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Text('Nenhum ingrediente encontrado'),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final option = list[index];
                        return ListTile(
                          dense: true,
                          title: Text(option.name),
                          subtitle: option.isPreparation
                              ? const Text('Preparo')
                              : (option.brand == null
                                    ? null
                                    : Text(option.brand!)),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }
}
