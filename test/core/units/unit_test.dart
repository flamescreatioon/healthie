import 'package:flutter_test/flutter_test.dart';
import 'package:healthie/core/units/unit.dart';

void main() {
  group('mass conversions', () {
    test('converts kilograms to pounds', () {
      expect(convert(78.4, Unit.kilogram, Unit.pound), closeTo(172.8424, 0.01));
    });

    test('converts pounds to kilograms', () {
      expect(convert(172.8424, Unit.pound, Unit.kilogram), closeTo(78.4, 0.01));
    });

    test('round-trips through the canonical unit without drift', () {
      final canonical = convert(78.4, Unit.kilogram, Unit.kilogram);
      final back = convert(canonical, Unit.kilogram, Unit.pound);
      expect(back, closeTo(172.8424, 0.01));
    });

    test('returns the same value when the units match', () {
      expect(convert(42, Unit.kilogram, Unit.kilogram), 42);
    });
  });

  group('length conversions', () {
    test('converts inches to centimetres', () {
      expect(convert(1, Unit.inch, Unit.centimetre), closeTo(2.54, 0.0001));
    });

    test('converts centimetres to inches', () {
      expect(convert(2.54, Unit.centimetre, Unit.inch), closeTo(1, 0.0001));
    });

    test('converts metres to centimetres', () {
      expect(convert(1, Unit.meter, Unit.centimetre), closeTo(100, 0.0001));
    });

    test('converts centimetres to metres', () {
      expect(convert(100, Unit.centimetre, Unit.meter), closeTo(1, 0.0001));
    });

    test('stores length in centimetres', () {
      expect(Unit.canonicalFor(UnitKind.length), Unit.centimetre);
    });
  });

  group('temperature conversions', () {
    test('converts fahrenheit to celsius', () {
      expect(convert(212, Unit.fahrenheit, Unit.celsius), closeTo(100, 0.0001));
    });

    test('converts celsius to fahrenheit', () {
      expect(convert(37, Unit.celsius, Unit.fahrenheit), closeTo(98.6, 0.01));
    });

    test('converts the freezing point exactly', () {
      expect(convert(32, Unit.fahrenheit, Unit.celsius), closeTo(0, 0.0001));
    });
  });

  group('glucose conversions', () {
    test('converts millimoles per litre to milligrams per decilitre', () {
      expect(
        convert(5, Unit.millimolePerLitre, Unit.milligramPerDecilitre),
        closeTo(90.09, 0.01),
      );
    });
  });

  group('dimension guard', () {
    test('refuses to convert between different dimensions', () {
      expect(
        () => convert(1, Unit.kilogram, Unit.millimetreOfMercury),
        throwsArgumentError,
      );
    });
  });

  group('roundTo', () {
    test('rounds to the requested number of decimals', () {
      expect(roundTo(68.249, 1), 68.2);
      expect(roundTo(68.25, 1), 68.3);
    });

    test('never returns negative zero', () {
      expect(roundTo(-0.001, 1), 0);
    });
  });

  group('canonical units', () {
    test('mass is stored in kilograms', () {
      expect(Unit.canonicalFor(UnitKind.mass), Unit.kilogram);
    });

    test('pressure is stored in millimetres of mercury', () {
      expect(Unit.canonicalFor(UnitKind.pressure), Unit.millimetreOfMercury);
    });

    test('reports whether a unit is already canonical', () {
      expect(Unit.kilogram.isCanonical, isTrue);
      expect(Unit.pound.isCanonical, isFalse);
    });
  });
}
