/// The canonical unit system for Healthie.
///
/// Every stored measurement carries a unit. Values are stored in the metric's
/// canonical unit (kg for mass, cm for length, mmHg for pressure, °C for
/// temperature) and converted only at the boundaries: once when the user
/// types a value, and once when a value is rendered.
///
/// A unitless number is a bug: "78.4" means nothing until you know whether it
/// is kilograms or pounds.
library;

/// The physical dimension a [Unit] measures.
///
/// Conversions are only defined within a kind. Mixing kinds (converting
/// kilograms into millimetres of mercury) is a programming error, not a
/// runtime condition.
enum UnitKind {
  mass,
  length,
  pressure,
  temperature,
  ratio,
  rate,
  concentration,
}

/// A unit of measure with a stable, user-facing symbol.
///
/// The enum name is an implementation detail; [symbol] is what is displayed
/// and what is persisted.
enum Unit {
  kilogram('kg', UnitKind.mass),
  pound('lb', UnitKind.mass),
  centimetre('cm', UnitKind.length),
  inch('in', UnitKind.length),
  meter('m', UnitKind.length),
  millimetreOfMercury('mmHg', UnitKind.pressure),
  beatsPerMinute('bpm', UnitKind.rate),
  percent('%', UnitKind.ratio),
  celsius('°C', UnitKind.temperature),
  fahrenheit('°F', UnitKind.temperature),
  milligramPerDecilitre('mg/dL', UnitKind.concentration),
  millimolePerLitre('mmol/L', UnitKind.concentration);

  const Unit(this.symbol, this.kind);

  /// The symbol shown to the user and stored alongside the value.
  final String symbol;

  /// The physical dimension this unit measures.
  final UnitKind kind;

  /// The unit values of this kind are stored in.
  static Unit canonicalFor(UnitKind kind) => switch (kind) {
        UnitKind.mass => Unit.kilogram,
        UnitKind.length => Unit.centimetre,
        UnitKind.pressure => Unit.millimetreOfMercury,
        UnitKind.temperature => Unit.celsius,
        UnitKind.ratio => Unit.percent,
        UnitKind.rate => Unit.beatsPerMinute,
        UnitKind.concentration => Unit.milligramPerDecilitre,
      };

  /// True when this unit is already the canonical unit for its kind.
  bool get isCanonical => this == canonicalFor(kind);
}

/// Converts [value] expressed in [from] into the canonical unit of its kind.
///
/// The canonical unit is kilograms for mass, centimetres for length,
/// millimetres of mercury for pressure, degrees Celsius for temperature,
/// per cent for ratios, beats per minute for rates, and milligrams per
/// decilitre for concentrations.
double toCanonical(double value, Unit from) {
  return switch (from) {
    Unit.kilogram => value,
    Unit.pound => value * 0.45359237,
    Unit.centimetre => value,
    Unit.inch => value * 2.54,
    Unit.meter => value * 100,
    Unit.millimetreOfMercury => value,
    Unit.beatsPerMinute => value,
    Unit.percent => value,
    Unit.celsius => value,
    Unit.fahrenheit => (value - 32) * 5 / 9,
    Unit.milligramPerDecilitre => value,
    Unit.millimolePerLitre => value * 18.0182,
  };
}

/// Converts a canonical [value] into [to].
double fromCanonical(double canonical, Unit to) {
  return switch (to) {
    Unit.kilogram => canonical,
    Unit.pound => canonical / 0.45359237,
    Unit.centimetre => canonical,
    Unit.inch => canonical / 2.54,
    Unit.meter => canonical / 100,
    Unit.millimetreOfMercury => canonical,
    Unit.beatsPerMinute => canonical,
    Unit.percent => canonical,
    Unit.celsius => canonical,
    Unit.fahrenheit => canonical * 9 / 5 + 32,
    Unit.milligramPerDecilitre => canonical,
    Unit.millimolePerLitre => canonical / 18.0182,
  };
}

/// Converts [value] from one unit to another within the same dimension.
///
/// Throws an [ArgumentError] when the dimensions differ. The check runs
/// before any assertion so the behaviour is the same whether or not asserts
/// are enabled.
double convert(double value, Unit from, Unit to) {
  if (from == to) return value;
  if (from.kind != to.kind) {
    throw ArgumentError(
      'Cannot convert ${from.symbol} to ${to.symbol}: different dimensions.',
    );
  }
  return fromCanonical(toCanonical(value, from), to);
}

/// Rounds [value] to [decimals] places, avoiding `-0.0`.
double roundTo(double value, int decimals) {
  final factor = _pow10(decimals);
  final rounded = (value * factor).roundToDouble() / factor;
  return rounded == 0 ? 0 : rounded;
}

double _pow10(int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}
