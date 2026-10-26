import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthie/app/theme/app_theme.dart';
import 'package:healthie/features/medications/domain/medication.dart';
import 'package:healthie/features/medications/domain/medication_repository.dart';
import 'package:healthie/features/medications/presentation/medication_screen.dart';
import 'package:healthie/features/medications/presentation/providers/medication_providers.dart';
import 'package:healthie/features/reminders/domain/reminder.dart';
import 'package:healthie/features/reminders/domain/reminder_repository.dart';
import 'package:healthie/features/reminders/presentation/providers/reminder_providers.dart';

class FakeMedicationRepository implements MedicationRepository {
  FakeMedicationRepository({
    this.medications = const [],
    this.logs = const [],
  });

  final List<Medication> medications;
  final List<MedicationLog> logs;

  @override
  Stream<List<Medication>> watchMedications() => Stream.value(medications);

  @override
  Future<List<Medication>> getMedications() async => medications;

  @override
  Future<void> saveMedication(Medication medication) async {}

  @override
  Future<void> deleteMedication(String id) async {}

  @override
  Stream<List<MedicationLog>> watchMedicationLogs() => Stream.value(logs);

  @override
  Future<List<MedicationLog>> getMedicationLogs() async => logs;

  @override
  Future<List<MedicationLog>> getLogsForMedication(String medicationId) async =>
      logs.where((log) => log.medicationId == medicationId).toList();

  @override
  Future<void> logMedication(MedicationLog log) async {}
}

class FakeReminderRepository implements ReminderRepository {
  FakeReminderRepository({this.reminders = const []});

  final List<Reminder> reminders;

  @override
  Stream<List<Reminder>> watchAll() => Stream.value(reminders);

  @override
  Future<void> upsert(Reminder reminder) async {}

  @override
  Future<void> delete(String id) async {}
}

/// A repository whose streams never emit, holding the UI in its loading
/// state. Deterministic — no timers, no real database.
class _NeverMedicationRepository extends FakeMedicationRepository {
  _NeverMedicationRepository() : super(medications: const [], logs: const []);

  @override
  Stream<List<Medication>> watchMedications() => const Stream.empty();

  @override
  Stream<List<MedicationLog>> watchMedicationLogs() => const Stream.empty();
}

Medication _medication({String id = 'med-1', String schedule = '08:00, 20:00'}) {
  return Medication(
    id: id,
    name: 'Lisinopril 10mg',
    dosageInstructions: 'Take one tablet by mouth',
    schedule: schedule,
    startDate: DateTime(2026, 1, 1),
    endDate: null,
    active: true,
  );
}

MedicationLog _log({String medicationId = 'med-1'}) {
  return MedicationLog(
    id: 'log-1',
    medicationId: medicationId,
    scheduledAt: DateTime(2026, 3, 10, 8),
    status: MedicationLogStatus.taken,
    recordedAt: DateTime(2026, 3, 10, 8, 5),
  );
}

Reminder _doseReminder({String medicationId = 'med-1'}) {
  return Reminder(
    id: 'rem-1',
    kind: ReminderKind.medication,
    metricType: 'medication:$medicationId',
    title: 'Take Lisinopril 10mg',
    hour: 8,
    minute: 0,
  );
}

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    List<Medication> medications = const [],
    List<MedicationLog> logs = const [],
    List<Reminder> reminders = const [],
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(
            FakeMedicationRepository(medications: medications, logs: logs),
          ),
          remindersProvider.overrideWith((ref) => Stream.value(reminders)),
          medicationLogsProvider.overrideWith((ref) => Stream.value(logs)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MedicationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows an empty state when no medications exist', (tester) async {
    await pumpScreen(tester);

    expect(find.text('No medications yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add Medication'), findsOneWidget);
  });

  testWidgets('shows a loading placeholder while medications load',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(
            _NeverMedicationRepository(),
          ),
        ],
        child: const MaterialApp(home: MedicationScreen()),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
  });

  testWidgets('lists medications with next dose and log action', (tester) async {
    await pumpScreen(tester, medications: [_medication()]);

    expect(find.text('Lisinopril 10mg'), findsOneWidget);
    expect(find.text('Take one tablet by mouth'), findsOneWidget);
    expect(find.text('Log dose'), findsOneWidget);
    expect(find.textContaining('Next:'), findsOneWidget);
  });

  testWidgets('shows an adherence chip when logs exist', (tester) async {
    await pumpScreen(
      tester,
      medications: [_medication()],
      logs: [_log()],
    );

    expect(find.text('100%'), findsOneWidget);
    expect(find.text('adherent'), findsOneWidget);
  });

  testWidgets('shows no adherence chip without logs', (tester) async {
    await pumpScreen(tester, medications: [_medication()]);

    expect(find.text('adherent'), findsNothing);
  });

  testWidgets('shows the reminder toggle reflecting linked reminders',
      (tester) async {
    await pumpScreen(
      tester,
      medications: [_medication()],
      reminders: [_doseReminder()],
    );

    expect(find.text('Reminders on'), findsOneWidget);
  });

  testWidgets('offers to enable reminders when none are linked', (tester) async {
    await pumpScreen(tester, medications: [_medication()]);

    expect(find.text('Remind me'), findsOneWidget);
  });
}
