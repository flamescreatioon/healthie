import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthie/app/providers.dart';
import 'package:healthie/app/theme/app_theme.dart';
import 'package:healthie/core/units/unit.dart';
import 'package:healthie/core/utils/clock.dart';
import 'package:healthie/core/utils/date_range.dart';
import 'package:healthie/features/metrics/domain/measurement.dart';
import 'package:healthie/features/metrics/domain/measurement_repository.dart';
import 'package:healthie/features/metrics/domain/metric_type.dart';
import 'package:healthie/features/profile/domain/health_profile.dart';
import 'package:healthie/features/profile/domain/profile_repository.dart';
import 'package:healthie/features/weight/presentation/weight_entry_screen.dart';

class FakeWeightRepository implements MeasurementRepository {
  FakeWeightRepository({this.existing = const []});

  final List<Measurement> saved = [];
  final List<Measurement> existing;

  @override
  Future<List<Measurement>> allMeasurements(DateRange range) async => existing;

  @override
  Future<List<Measurement>> measurementsFor(MetricType type, DateRange range) async =>
      existing;

  @override
  Future<Measurement?> findById(String id) async => null;

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

class FakeProfileRepository implements ProfileRepository {
  @override
  Future<HealthProfile> load() async => const HealthProfile(id: 'test-profile');

  @override
  Stream<HealthProfile> watch() =>
      Stream.value(const HealthProfile(id: 'test-profile'));

  @override
  Future<void> save(HealthProfile profile) async {}

  @override
  Future<List<HealthGoal>> goals() async => const [];

  @override
  Future<void> saveGoal(HealthGoal goal) async {}

  @override
  Future<void> deleteGoal(String id) async {}
}

void main() {
  late FakeWeightRepository repository;

  setUp(() {
    repository = FakeWeightRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 7200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          measurementRepositoryProvider.overrideWithValue(repository),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          clockProvider.overrideWithValue(
            FixedClock(DateTime(2026, 3, 10, 9, 41)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const WeightEntryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('entering weight in kg saves canonical kg to repository',
      (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('weight-value-field')),
      '72.5',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save weight reading'));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    final saved = repository.saved.single;
    expect(saved.value, 72.5);
    expect(saved.unit, Unit.kilogram);
    expect(saved.metricType, MetricType.weight);
  });

  testWidgets('entering weight in lb converts and saves canonical kg to repository',
      (tester) async {
    await pumpScreen(tester);

    // Switch unit to lb
    await tester.tap(find.text('lb'));
    await tester.pumpAndSettle();

    // Enter 154.32 lb (which is ~70.0 kg)
    await tester.enterText(
      find.byKey(const ValueKey('weight-value-field')),
      '154.32',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save weight reading'));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    final saved = repository.saved.single;
    expect(saved.unit, Unit.kilogram);
    // 154.32 lb is ~70.0 kg, definitely NOT 154.32 kg
    expect(saved.value, closeTo(70.0, 0.1));
  });

  testWidgets('switching from kg to lb and back preserves canonical kg',
      (tester) async {
    await pumpScreen(tester);

    // Enter 70.0 kg
    await tester.enterText(
      find.byKey(const ValueKey('weight-value-field')),
      '70.0',
    );
    await tester.pumpAndSettle();

    // Switch to lb: display should become ~154.3
    await tester.tap(find.text('lb'));
    await tester.pumpAndSettle();
    expect(find.text('154.3'), findsOneWidget);

    // Now save: canonical kg must STILL be 70 kg
    await tester.tap(find.text('Save weight reading'));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    final saved = repository.saved.single;
    expect(saved.unit, Unit.kilogram);
    expect(saved.value, 70.0);
  });
}
