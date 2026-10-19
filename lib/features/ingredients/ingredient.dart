import '../../core/units.dart';

class Ingredient {
  const Ingredient({
    this.id,
    required this.name,
    required this.unit,
    this.stock = 0,
    this.minStock,
    this.price,
  });

  final int? id;
  final String name;
  final Unit unit;
  final double stock;
  final double? minStock;
  final double? price;

  bool get isOutOfStock => stock <= 0;

  factory Ingredient.fromMap(Map<String, Object?> map) {
    return Ingredient(
      id: map['id'] as int?,
      name: map['name'] as String,
      unit: Unit.values.byName(map['unit'] as String),
      stock: (map['stock'] as num).toDouble(),
      minStock: (map['min_stock'] as num?)?.toDouble(),
      price: (map['price'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'unit': unit.name,
      'stock': stock,
      'min_stock': minStock,
      'price': price,
    };
  }
}
