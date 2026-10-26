import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthie/app/providers.dart';
import 'package:healthie/app/theme/app_theme.dart';
import 'package:healthie/core/utils/clock.dart';
import 'package:healthie/core/utils/date_range.dart';
import 'package:healthie/features/blood_pressure/presentation/blood_pressure_entry_screen.dart';
import 'package:healthie/features/metrics/domain/measurement.dart';
import 'package:healthie/features/metrics/domain/measurement_repository.dart';
import 'package:healthie/features/metrics/domain/metric_type.dart';

class FakeMeasurementRepository implements MeasurementRepository {
  FakeMeasurementRepository({this.existing = const []});

  final List<Measurement> saved = [];
  final List<Measurement> existing;

  @override
  Future<List<Measurement>> allMeasurements(DateRange range) async => existing;

  @override
  Future<List<Measurement>> measurementsFor(
    MetricType type,
    DateRange range,
  ) async =>
      existing;

  @override
  Future<Measurement?> findById(String id) async {
    for (final measurement in existing) {
      if (measurement.id == id) return measurement;
    }
    return null;
  }

  @override
  Future<Measurement?> latestOf(MetricType type) async =>
      existing.isEmpty ? null : existing.first;

  @override
  Future<void> restore(String id, {required DateTime updatedAt}) async {}

  @override
  Future<void> save(Measurement measurement) async => saved.add(measurement);

  @override
  Future<void> softDelete(String id, {required DateTime deletedAt}) async {}

  @override
  Stream<List<Measurement>> watchAllMeasurements({required DateRange range}) =>
      Stream.value(existing);

  @override
  Stream<List<Measurement>> watchMeasurements({
    required MetricType type,
    required DateRange range,
  }) =>
      Stream.value(existing);
}

void main() {
  late FakeMeasurementRepository repository;

  setUp(() {
    repository = FakeMeasurementRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    // The entry sheet is a long scroll. A tall viewport lets the whole form
    // build in one frame, so the assertions are about content rather than
    // about scroll position.
    tester.view.physicalSize = const Size(1200, 7200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          measurementRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(
            FixedClock(DateTime(2026, 3, 10, 9, 41)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const BloodPressureEntryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the systolic and diastolic inputs', (tester) async {
    await pumpScreen(tester);

    expect(find.text('SYSTOLIC'), findsOneWidget);
    expect(find.text('DIASTOLIC'), findsOneWidget);
    expect(find.text('Blood Pressure Reading'), findsOneWidget);
  });

  testWidgets('starts with no reading rather than a fabricated one',
      (tester) async {
    await pumpScreen(tester);

    // Nothing is pre-filled: a "normal looking" reading the user never took
    // must never be one tap away from being saved.
    expect(find.text('Enter both values'), findsOneWidget);
    expect(find.text('120'), findsNothing);
  });

  testWidgets('classifies 118/76 as normal', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('value-field-Systolic')),
      '118',
    );
    await tester.enterText(
      find.byKey(const ValueKey('value-field-Diastolic')),
      '76',
    );
    await tester.pumpAndSettle();

    expect(find.text('Normal range'), findsOneWidget);
    expect(find.text('AHA/ACC 2017'), findsOneWidget);
  });

  testWidgets('classifies 120/80 as stage 1, not normal', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('value-field-Systolic')),
      '120',
    );
    await tester.enterText(
      find.byKey(const ValueKey('value-field-Diastolic')),
      '80',
    );
    await tester.pumpAndSettle();

    // A diastolic of 80 is not "below 80", so 120/80 is Stage 1 under the
    // AHA/ACC 2017 guideline.
    expect(find.text('Stage 1 hypertension'), findsOneWidget);
  });

  testWidgets('reclassifies when the systolic value changes', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('value-field-Systolic')),
      '125',
    );
    await tester.enterText(
      find.byKey(const ValueKey('value-field-Diastolic')),
      '79',
    );
    await tester.pumpAndSettle();

    expect(find.text('Elevated'), findsOneWidget);
  });

  testWidgets('shows emergency guidance for a crisis reading', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('value-field-Systolic')),
      '190',
    );
    await tester.pumpAndSettle();

    expect(find.text('Immediate Action Guidance'), findsOneWidget);
    expect(
      find.textContaining('seek emergency medical care'),
      findsOneWidget,
    );
  });

  testWidgets('raises the safety alert before the diastolic is entered',
      (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('value-field-Systolic')),
      '200',
    );
    await tester.pumpAndSettle();

    // The alert must not wait for the second value.
    expect(find.text('Immediate Action Guidance'), findsOneWidget);
  });

  testWidgets('rejects a systolic value outside the plausible range',
      (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('value-field-Systolic')),
      '400',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Enter a systolic value between'), findsOneWidget);
    expect(repository.saved, isEmpty);
  });

  testWidgets('saves the reading with its context', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('value-field-Systolic')),
      '124',
    );
    await tester.enterText(
      find.byKey(const ValueKey('value-field-Diastolic')),
      '82',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    final saved = repository.saved.single;
    expect(saved.value, 124);
    expect(saved.secondaryValue, 82);
    expect(saved.metricType, MetricType.bloodPressure);
    expect(saved.context.posture, isNotNull);
    expect(saved.context.arm, isNotNull);
  });

  testWidgets('keeps the entered values when the save is rejected',
      (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('value-field-Diastolic')),
      '400',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();

    expect(find.text('400'), findsOneWidget);
    expect(repository.saved, isEmpty);
  });

  testWidgets('rejects entry when systolic is less than or equal to diastolic',
      (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('value-field-Systolic')),
      '90',
    );
    await tester.enterText(
      find.byKey(const ValueKey('value-field-Diastolic')),
      '110',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();

    expect(find.text('Systolic must be higher than diastolic'), findsOneWidget);
    expect(repository.saved, isEmpty);
  });

  testWidgets('rejects entry when pulse pressure is narrower than 15 mmHg',
      (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('value-field-Systolic')),
      '110',
    );
    await tester.enterText(
      find.byKey(const ValueKey('value-field-Diastolic')),
      '100',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Pulse pressure (systolic - diastolic) is implausibly narrow'),
      findsOneWidget,
    );
    expect(repository.saved, isEmpty);
  });

  testWidgets('resets fields when save and add another is pressed',
      (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('value-field-Systolic')),
      '120',
    );
    await tester.enterText(
      find.byKey(const ValueKey('value-field-Diastolic')),
      '80',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save & add another'));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    expect(find.text('Reading recorded. Ready for next entry.'), findsOneWidget);
  });
}
