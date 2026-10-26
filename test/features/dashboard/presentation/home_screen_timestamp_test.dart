import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthie/app/theme/app_theme.dart';
import 'package:healthie/core/units/unit.dart';
import 'package:healthie/core/utils/date_utils.dart';
import 'package:healthie/features/dashboard/presentation/home_screen.dart';
import 'package:healthie/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:healthie/features/metrics/domain/measurement.dart';
import 'package:healthie/features/metrics/domain/metric_type.dart';
import 'package:healthie/features/profile/domain/health_profile.dart';
import 'package:healthie/features/profile/presentation/providers/profile_providers.dart';
import 'package:healthie/features/reminders/presentation/providers/reminder_providers.dart';

void main() {
  Future<void> pumpHome(
    WidgetTester tester, {
    required List<Measurement> measurements,
  }) async {
    tester.view.physicalSize = const Size(1200, 7200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardMeasurementsProvider.overrideWith(
            (ref) => Stream.value(measurements),
          ),
          profileProvider.overrideWith(
            (ref) => Stream.value(const HealthProfile(id: 'test', displayName: 'Alex')),
          ),
          remindersProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('historical blood pressure reading does not display Today',
      (tester) async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    final reading = Measurement(
      id: 'bp-1',
      metricType: MetricType.bloodPressure,
      value: 120,
      unit: Unit.millimetreOfMercury,
      secondaryValue: 80,
      secondaryUnit: Unit.millimetreOfMercury,
      recordedAt: yesterday,
      localDay: startOfLocalDay(yesterday),
      createdAt: yesterday,
      updatedAt: yesterday,
    );

    await pumpHome(tester, measurements: [reading]);

    // Subtitle must say Yesterday, NOT Today
    expect(find.textContaining('Yesterday, '), findsOneWidget);
    expect(find.textContaining('Today, '), findsNothing);

    // Disclaimer must be present
    expect(
      find.textContaining('Healthie is for personal health tracking and informational purposes only'),
      findsOneWidget,
    );
  });

  testWidgets('reading taken today displays Today with time', (tester) async {
    final now = DateTime.now();

    final reading = Measurement(
      id: 'bp-2',
      metricType: MetricType.bloodPressure,
      value: 118,
      unit: Unit.millimetreOfMercury,
      secondaryValue: 78,
      secondaryUnit: Unit.millimetreOfMercury,
      recordedAt: now,
      localDay: startOfLocalDay(now),
      createdAt: now,
      updatedAt: now,
    );

    await pumpHome(tester, measurements: [reading]);

    expect(find.textContaining('Today, '), findsOneWidget);
  });
}
