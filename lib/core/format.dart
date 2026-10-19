import 'package:intl/intl.dart';

import 'units.dart';

final _numberFormat = NumberFormat('#,##0.###', 'pt_BR');
final _dateFormat = DateFormat('dd/MM/yyyy');
final _dateKeyFormat = DateFormat('yyyy-MM-dd');

String formatNumber(double value) => _numberFormat.format(value);

String formatQuantity(double baseValue, Unit unit) =>
    '${formatNumber(unit.fromBase(baseValue))} ${unit.label}';

double? parseNumber(String text) {
  var normalized = text.trim().replaceAll(' ', '');
  if (normalized.contains(',')) {
    normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
  }
  final value = double.tryParse(normalized);
  if (value == null || !value.isFinite) return null;
  return value;
}

String formatDate(DateTime date) => _dateFormat.format(date);

String toDateKey(DateTime date) => _dateKeyFormat.format(date);

DateTime fromDateKey(String key) => _dateKeyFormat.parse(key);
