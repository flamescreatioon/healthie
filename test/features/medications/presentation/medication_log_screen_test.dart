import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:healthie/app/theme/app_theme.dart';
import 'package:healthie/features/medications/domain/medication.dart';
import 'package:healthie/features/medications/domain/medication_repository.dart';
import 'package:healthie/features/medications/presentation/medication_log_screen.dart';
import 'package:healthie/features/medications/presentation/providers/medication_providers.dart';

class FakeMedicationRepository implements MedicationRepository {
  final List<MedicationLog> logged = [];

  @override
  Stream<List<Medication>> watchMedications() => const Stream.empty();

  @override
  Future<List<Medication>> getMedications() async => [];

  @override
  Future<void> saveMedication(Medication medication) async {}

  @override
  Future<void> deleteMedication(String id) async {}

  @override
  Stream<List<MedicationLog>> watchMedicationLogs() => const Stream.empty();

  @override
  Future<List<MedicationLog>> getMedicationLogs() async => logged;

  @override
  Future<List<MedicationLog>> getLogsForMedication(String medicationId) async =>
      logged.where((log) => log.medicationId == medicationId).toList();

  @override
  Future<void> logMedication(MedicationLog log) async {
    logged.add(log);
  }
}

void main() {
  late FakeMedicationRepository repository;

  setUp(() {
    repository = FakeMedicationRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const MedicationLogScreen(medicationId: 'med-1'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows status chips and defaults to taken', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Taken'), findsOneWidget);
    expect(find.text('Skipped'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Log Dose'),
      findsOneWidget,
    );
  });

  testWidgets('saves a taken log with notes', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('medication-log-notes-field')),
      'Took with food',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log Dose'));
    await tester.pumpAndSettle();

    expect(repository.logged, hasLength(1));
    final log = repository.logged.single;
    expect(log.medicationId, 'med-1');
    expect(log.status, MedicationLogStatus.taken);
    expect(log.notes, 'Took with food');
  });

  testWidgets('saves a skipped log without notes', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Skipped'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log Dose'));
    await tester.pumpAndSettle();

    expect(repository.logged, hasLength(1));
    expect(repository.logged.single.status, MedicationLogStatus.skipped);
    expect(repository.logged.single.notes, isNull);
  });
}
