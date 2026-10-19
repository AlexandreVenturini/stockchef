import 'package:intl/intl.dart';

import 'units.dart';

final _numberFormat = NumberFormat('#,##0.###', 'pt_BR');
final _dateFormat = DateFormat('dd/MM/yyyy');
final _dateKeyFormat = DateFormat('yyyy-MM-dd');
final _timeFormat = DateFormat('HH:mm');

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

String formatTime(DateTime dateTime) => _timeFormat.format(dateTime);

String formatLongDate(DateTime date) {
  final text = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(date);
  return text[0].toUpperCase() + text.substring(1);
}

String formatDayLabel(DateTime day, {DateTime? today}) {
  final now = today ?? DateTime.now();
  final target = DateTime(day.year, day.month, day.day);
  if (target == DateTime(now.year, now.month, now.day)) return 'Hoje';
  if (target == DateTime(now.year, now.month, now.day - 1)) return 'Ontem';
  return formatDate(day);
}
