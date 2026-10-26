import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthie/shared/form/entry_widgets.dart';

void main() {
  group('parseNumeric', () {
    test('parses a plain decimal', () {
      expect(parseNumeric('78.4'), 78.4);
    });

    test('parses an integer', () {
      expect(parseNumeric('120'), 120);
    });

    test('parses a decimal comma', () {
      expect(parseNumeric('78,4'), 78.4);
    });

    test('strips thousands separators written with a comma', () {
      expect(parseNumeric('1,200'), 1200);
    });

    test('strips thousands separators written with a point', () {
      expect(parseNumeric('1.200'), 1200);
    });

    test('accepts a trailing separator while typing', () {
      expect(parseNumeric('78.'), 78);
    });

    test('returns null for empty input', () {
      expect(parseNumeric(''), isNull);
      expect(parseNumeric('   '), isNull);
    });

    test('returns null for text that is not a number', () {
      expect(parseNumeric('abc'), isNull);
    });

    test('ignores surrounding whitespace', () {
      expect(parseNumeric('  68.2  '), 68.2);
    });
  });

  group('NumericField', () {
    testWidgets('shows the label and the unit', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NumericField(
              label: 'Weight',
              value: '68.2',
              onChanged: _ignore,
              unit: null,
            ),
          ),
        ),
      );

      expect(find.text('Weight'), findsOneWidget);
    });

    testWidgets('reports edits to the parent', (tester) async {
      String? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NumericField(
              label: 'Weight',
              value: '',
              onChanged: (value) => latest = value,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '68.2');
      expect(latest, '68.2');
    });
  });
}

void _ignore(String value) {}
