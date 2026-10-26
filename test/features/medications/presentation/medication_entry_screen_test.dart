import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:healthie/app/theme/app_theme.dart';
import 'package:healthie/features/medications/domain/medication.dart';
import 'package:healthie/features/medications/domain/medication_repository.dart';
import 'package:healthie/features/medications/presentation/medication_entry_screen.dart';
import 'package:healthie/features/medications/presentation/providers/medication_providers.dart';

class FakeMedicationRepository implements MedicationRepository {
  final List<Medication> saved = [];
  final List<String> deleted = [];

  @override
  Stream<List<Medication>> watchMedications() => const Stream.empty();

  @override
  Future<List<Medication>> getMedications() async => saved;

  @override
  Future<void> saveMedication(Medication medication) async {
    saved.add(medication);
  }

  @override
  Future<void> deleteMedication(String id) async {
    deleted.add(id);
  }

  @override
  Stream<List<MedicationLog>> watchMedicationLogs() => const Stream.empty();

  @override
  Future<List<MedicationLog>> getMedicationLogs() async => [];

  @override
  Future<List<MedicationLog>> getLogsForMedication(String medicationId) async =>
      [];

  @override
  Future<void> logMedication(MedicationLog log) async {}
}

void main() {
  late FakeMedicationRepository repository;

  setUp(() {
    repository = FakeMedicationRepository();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    Medication? existing,
  }) async {
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
              MedicationEntryScreen(medication: existing),
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

  testWidgets('shows the entry fields and remind toggle', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Medication Name'), findsOneWidget);
    expect(find.text('Dosage Instructions'), findsOneWidget);
    expect(find.text('Schedule Times'), findsOneWidget);
    expect(find.text('Remind me at these times'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Add Medication'),
      findsOneWidget,
    );
  });

  testWidgets('requires a name before saving', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Add Medication'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a medication name'), findsOneWidget);
    expect(repository.saved, isEmpty);
  });

  testWidgets('requires a schedule before saving', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('medication-name-field')),
      'Lisinopril 10mg',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add Medication'));
    await tester.pumpAndSettle();

    expect(
      find.text('Please enter at least one time (e.g. 08:00, 20:00)'),
      findsOneWidget,
    );
    expect(repository.saved, isEmpty);
  });

  testWidgets('saves the medication without reminders by default',
      (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('medication-name-field')),
      'Lisinopril 10mg',
    );
    await tester.enterText(
      find.byKey(const ValueKey('medication-dosage-field')),
      'Take one tablet by mouth',
    );
    // The schedule field is read-only and picker-driven: tapping it opens
    // the time picker, like a user would. `enterText` silently no-ops on a
    // read-only field, leaving validation to reject the save.
    await tester.tap(find.byKey(const ValueKey('medication-schedule-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add Medication'));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.name, 'Lisinopril 10mg');
    expect(repository.saved.single.schedule, isNotEmpty);
  });

  testWidgets('prefills fields when editing an existing medication',
      (tester) async {
    await pumpScreen(
      tester,
      existing: Medication(
        id: 'med-1',
        name: 'Metformin 500mg',
        dosageInstructions: 'With breakfast',
        schedule: '07:30',
        startDate: DateTime(2026, 1, 1),
        endDate: null,
        active: true,
      ),
    );

    expect(find.text('Metformin 500mg'), findsOneWidget);
    expect(find.text('Update Medication'), findsWidgets);
  });
}
