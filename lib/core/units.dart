enum UnitFamily { mass, volume, count }

enum Unit {
  kg('kg', UnitFamily.mass, 1000),
  g('g', UnitFamily.mass, 1),
  l('L', UnitFamily.volume, 1000),
  ml('ml', UnitFamily.volume, 1),
  un('un', UnitFamily.count, 1);

  const Unit(this.label, this.family, this.factor);

  final String label;
  final UnitFamily family;
  final double factor;

  double toBase(double value) => roundBase(value * factor);

  double fromBase(double baseValue) => baseValue / factor;

  bool isCompatibleWith(Unit other) => family == other.family;

  List<Unit> get compatibleUnits =>
      Unit.values.where(isCompatibleWith).toList();
}

double roundBase(double value) => (value * 1000).roundToDouble() / 1000;
