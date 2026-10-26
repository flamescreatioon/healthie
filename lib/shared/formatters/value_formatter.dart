/// Number and unit formatting.
///
/// One place decides how a value reads, so the dashboard, the charts, and the
/// export all agree.
library;

import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../../core/units/unit.dart';

/// Formats a number with a fixed number of decimals.
///
/// A trailing `.0` is dropped when the metric has no decimals, and a value
/// that rounds to zero never renders as `-0`.
String formatValue(double value, {int precision = 0}) {
  final rounded = roundTo(value, precision);
  if (precision == 0) return rounded.round().toString();
  return rounded.toStringAsFixed(precision);
}

/// Formats a number with an explicit sign, for deltas.
String formatSigned(double value, {int precision = 0}) {
  final rounded = roundTo(value, precision);
  final text = formatValue(rounded, precision: precision);
  if (rounded > 0) return '+$text';
  return text;
}

/// Formats a value with its unit, e.g. `68.2 kg`.
String formatValueWithUnit(
  double value,
  Unit unit, {
  int precision = 0,
}) =>
    '${formatValue(value, precision: precision)} ${unit.symbol}';

/// Formats a fraction as a percentage, e.g. `63%`.
String formatPercent(double fraction, {int precision = 0}) =>
    '${formatValue(fraction * 100, precision: precision)}%';

/// Formats a millimetre-of-mercury pair, e.g. `118/76 mmHg`.
String formatBloodPressure(double systolic, double? diastolic) {
  if (diastolic == null) return formatValue(systolic);
  return '${formatValue(systolic)}/${formatValue(diastolic)}';
}

/// Formats a kilogram value in the user's preferred mass unit.
String formatMass(
  double kilograms,
  Unit displayUnit, {
  int precision = 1,
}) {
  if (displayUnit == Unit.kilogram) {
    return formatValueWithUnit(kilograms, Unit.kilogram, precision: precision);
  }
  final pounds = convert(kilograms, Unit.kilogram, Unit.pound);
  return formatValueWithUnit(pounds, Unit.pound, precision: precision);
}

/// Formats a duration in days as a short human phrase.
String formatDayCount(int days) {
  if (days == 0) return 'today';
  if (days == 1) return '1 day';
  return '$days days';
}

/// A date-only formatter, used by charts and exports.
final DateFormat kShortDate = DateFormat('MMM d');

/// A date-and-time formatter.
final DateFormat kDateTime = DateFormat('MMM d, HH:mm');

/// Clamps a value into a range.
double clampTo(double value, double min, double max) =>
    math.min(math.max(value, min), max);
