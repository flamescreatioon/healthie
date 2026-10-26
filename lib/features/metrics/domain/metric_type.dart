/// The closed catalogue of metrics Healthie tracks.
///
/// The enum name is an implementation detail and may be renamed; [wireName] is
/// the stable string written to the database, the sync payload, and the API.
/// Never rename an existing `wireName` — old synced records reference it
/// forever.
library;

import '../../../core/units/unit.dart';

enum MetricType {
  /// A blood-pressure reading: systolic + diastolic, optionally with pulse.
  bloodPressure('blood_pressure'),

  /// Body weight, optionally with body-fat percentage and waist circumference.
  weight('weight'),

  /// Heart rate, in beats per minute.
  heartRate('heart_rate'),

  /// Blood oxygen saturation, as a percentage.
  spo2('spo2'),

  /// Body temperature.
  bodyTemperature('body_temperature'),

  /// Blood glucose concentration.
  bloodGlucose('blood_glucose');

  const MetricType(this.wireName);

  /// The stable persisted name.
  final String wireName;

  /// Looks a metric type up by its [wireName].
  static MetricType? fromWireName(String wireName) {
    for (final type in MetricType.values) {
      if (type.wireName == wireName) return type;
    }
    return null;
  }
}

/// A secondary or tertiary value carried by a measurement.
///
/// Blood pressure carries a diastolic pressure and a pulse; weight carries a
/// body-fat percentage and a waist circumference. Each component has its own
/// unit, precision, and plausible range — a diastolic of 400 mmHg and a
/// systolic of 120 mmHg must both be rejected, and the message has to say
/// which field is wrong.
class MetricComponent {
  const MetricComponent({
    required this.label,
    required this.unit,
    required this.min,
    required this.max,
    required this.precision,
    this.optional = true,
  });

  /// The field label shown to the user.
  final String label;

  /// The canonical unit this component is stored in.
  final Unit unit;

  /// The lowest plausible value, in canonical units.
  final double min;

  /// The highest plausible value, in canonical units.
  final double max;

  /// Decimal places this component is displayed and stored with.
  final int precision;

  /// Whether the component may be omitted entirely.
  final bool optional;
}

/// Everything Healthie knows about one metric type.
class MetricSpec {
  const MetricSpec({
    required this.type,
    required this.displayName,
    required this.canonicalUnit,
    required this.precision,
    required this.min,
    required this.max,
    required this.step,
    this.entryUnits = const [],
    this.secondary,
    this.tertiary,
  });

  final MetricType type;

  /// The name shown in the UI.
  final String displayName;

  /// The unit values of this metric are stored in.
  final Unit canonicalUnit;

  /// Decimal places the primary value is stored and displayed with.
  final int precision;

  /// The lowest plausible primary value, in canonical units.
  final double min;

  /// The highest plausible primary value, in canonical units.
  final double max;

  /// The amount a `+`/`-` stepper moves by.
  final double step;

  /// The units the user may enter this metric in.
  final List<Unit> entryUnits;

  /// The optional second component, when the metric has one.
  final MetricComponent? secondary;

  /// The optional third component, when the metric has one.
  final MetricComponent? tertiary;
}

/// The canonical metric catalogue.
abstract final class MetricCatalog {
  static const MetricSpec bloodPressure = MetricSpec(
    type: MetricType.bloodPressure,
    displayName: 'Blood Pressure',
    canonicalUnit: Unit.millimetreOfMercury,
    precision: 0,
    min: 50,
    max: 260,
    step: 1,
    entryUnits: [Unit.millimetreOfMercury],
    secondary: MetricComponent(
      label: 'Diastolic',
      unit: Unit.millimetreOfMercury,
      min: 30,
      max: 160,
      precision: 0,
    ),
    tertiary: MetricComponent(
      label: 'Resting Heart Rate',
      unit: Unit.beatsPerMinute,
      min: 20,
      max: 250,
      precision: 0,
    ),
  );

  static const MetricSpec weight = MetricSpec(
    type: MetricType.weight,
    displayName: 'Body Weight',
    canonicalUnit: Unit.kilogram,
    precision: 1,
    min: 20,
    max: 400,
    step: 0.1,
    entryUnits: [Unit.kilogram, Unit.pound],
    secondary: MetricComponent(
      label: 'Body Fat',
      unit: Unit.percent,
      min: 2,
      max: 70,
      precision: 1,
    ),
    tertiary: MetricComponent(
      label: 'Waist',
      unit: Unit.centimetre,
      min: 30,
      max: 200,
      precision: 1,
    ),
  );

  static const MetricSpec heartRate = MetricSpec(
    type: MetricType.heartRate,
    displayName: 'Heart Rate',
    canonicalUnit: Unit.beatsPerMinute,
    precision: 0,
    min: 20,
    max: 250,
    step: 1,
    entryUnits: [Unit.beatsPerMinute],
  );

  static const MetricSpec spo2 = MetricSpec(
    type: MetricType.spo2,
    displayName: 'Blood Oxygen',
    canonicalUnit: Unit.percent,
    precision: 0,
    min: 50,
    max: 100,
    step: 1,
    entryUnits: [Unit.percent],
  );

  static const MetricSpec bodyTemperature = MetricSpec(
    type: MetricType.bodyTemperature,
    displayName: 'Body Temperature',
    canonicalUnit: Unit.celsius,
    precision: 1,
    min: 30,
    max: 45,
    step: 0.1,
    entryUnits: [Unit.celsius, Unit.fahrenheit],
  );

  static const MetricSpec bloodGlucose = MetricSpec(
    type: MetricType.bloodGlucose,
    displayName: 'Blood Glucose',
    canonicalUnit: Unit.milligramPerDecilitre,
    precision: 0,
    min: 20,
    max: 600,
    step: 1,
    entryUnits: [
      Unit.milligramPerDecilitre,
      Unit.millimolePerLitre,
    ],
  );

  /// The specification for [type].
  static MetricSpec specFor(MetricType type) => switch (type) {
        MetricType.bloodPressure => bloodPressure,
        MetricType.weight => weight,
        MetricType.heartRate => heartRate,
        MetricType.spo2 => spo2,
        MetricType.bodyTemperature => bodyTemperature,
        MetricType.bloodGlucose => bloodGlucose,
      };

  /// Every metric the app can record.
  static List<MetricSpec> get all => [
        bloodPressure,
        weight,
        heartRate,
        spo2,
        bodyTemperature,
        bloodGlucose,
      ];
}
