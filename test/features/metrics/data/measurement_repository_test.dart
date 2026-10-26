import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthie/core/database/app_database.dart';
import 'package:healthie/core/sync/sync_outbox_dao.dart';
import 'package:healthie/core/units/unit.dart';
import 'package:healthie/core/utils/date_range.dart';
import 'package:healthie/core/utils/date_utils.dart';
import 'package:healthie/features/metrics/data/measurement_dao.dart';
import 'package:healthie/features/metrics/data/measurement_repository_impl.dart';
import 'package:healthie/features/metrics/domain/measurement.dart';
import 'package:healthie/features/metrics/domain/metric_type.dart';
import 'package:healthie/features/metrics/domain/reading_context.dart';

Measurement measurement({
  required String id,
  required DateTime at,
  double systolic = 118,
  double diastolic = 76,
  double? pulse = 71,
}) {
  return Measurement(
    id: id,
    metricType: MetricType.bloodPressure,
    value: systolic,
    unit: Unit.millimetreOfMercury,
    secondaryValue: diastolic,
    secondaryUnit: Unit.millimetreOfMercury,
    tertiaryValue: pulse,
    tertiaryUnit: pulse == null ? null : Unit.beatsPerMinute,
    recordedAt: at.toUtc(),
    localDay: startOfLocalDay(at),
    createdAt: at.toUtc(),
    updatedAt: at.toUtc(),
    context: const MeasurementContext(
      posture: BodyPosture.sitting,
      arm: MeasurementArm.left,
      circumstances: {ReadingCircumstance.resting},
      notes: 'Felt well rested',
    ),
  );
}

void main() {
  late AppDatabase database;
  late MeasurementRepositoryImpl repository;
  late SyncOutboxDao outbox;

  final period = DateRange(
    start: DateTime(2026, 3, 1),
    end: DateTime(2026, 4, 1),
  );

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    outbox = SyncOutboxDao(database);
    repository = MeasurementRepositoryImpl(
      database,
      MeasurementDao(database),
      outbox,
    );
  });

  tearDown(() => database.close());

  test('saves a measurement and reads it back', () async {
    await repository.save(
      measurement(id: 'a', at: DateTime(2026, 3, 10, 8, 15)),
    );

    final stored = await repository.findById('a');
    expect(stored, isNotNull);
    expect(stored!.value, 118);
    expect(stored.secondaryValue, 76);
    expect(stored.tertiaryValue, 71);
    expect(stored.context.posture, BodyPosture.sitting);
    expect(stored.context.arm, MeasurementArm.left);
    expect(stored.context.notes, 'Felt well rested');
    expect(stored.context.circumstances, {ReadingCircumstance.resting});
  });

  test('preserves the local day of a late-evening reading', () async {
    final at = DateTime(2026, 3, 10, 23, 30);
    await repository.save(measurement(id: 'late', at: at));

    final stored = await repository.findById('late');
    expect(stored!.localDay, DateTime(2026, 3, 10));
  });

  test('reads back only the measurements inside the range', () async {
    await repository.save(
      measurement(id: 'in', at: DateTime(2026, 3, 10, 8)),
    );
    await repository.save(
      measurement(id: 'out', at: DateTime(2026, 4, 10, 8)),
    );

    final stored = await repository.allMeasurements(period);
    expect(stored.map((m) => m.id), ['in']);
  });

  test('returns measurements newest first', () async {
    await repository.save(
      measurement(id: 'older', at: DateTime(2026, 3, 10, 8)),
    );
    await repository.save(
      measurement(id: 'newer', at: DateTime(2026, 3, 20, 8)),
    );

    final stored = await repository.allMeasurements(period);
    expect(stored.map((m) => m.id), ['newer', 'older']);
  });

  test('enqueues a sync operation for every write', () async {
    expect(await outbox.pendingCount(), 0);

    await repository.save(
      measurement(id: 'a', at: DateTime(2026, 3, 10, 8)),
    );

    expect(await outbox.pendingCount(), 1);
    final pending = await outbox.pending();
    expect(pending.single.operation, 'upsert');
    expect(pending.single.entityId, 'a');
  });

  test('soft-deletes rather than removing the record', () async {
    await repository.save(
      measurement(id: 'a', at: DateTime(2026, 3, 10, 8)),
    );

    final deletedAt = DateTime.utc(2026, 3, 11);
    await repository.softDelete('a', deletedAt: deletedAt);

    final stored = await repository.findById('a');
    expect(stored, isNotNull);
    expect(stored!.deletedAt, deletedAt);

    final visible = await repository.allMeasurements(period);
    expect(visible, isEmpty);
  });

  test('enqueues a delete operation when a record is soft-deleted', () async {
    await repository.save(
      measurement(id: 'a', at: DateTime(2026, 3, 10, 8)),
    );
    await repository.softDelete('a', deletedAt: DateTime.utc(2026, 3, 11));

    final pending = await outbox.pending();
    expect(pending.single.operation, 'delete');
  });

  test('restores a soft-deleted record', () async {
    await repository.save(
      measurement(id: 'a', at: DateTime(2026, 3, 10, 8)),
    );
    await repository.softDelete('a', deletedAt: DateTime.utc(2026, 3, 11));
    await repository.restore('a', updatedAt: DateTime.utc(2026, 3, 11, 1));

    final visible = await repository.allMeasurements(period);
    expect(visible.single.id, 'a');
  });

  test('updates an existing record without creating a second row', () async {
    final original = measurement(id: 'a', at: DateTime(2026, 3, 10, 8));
    await repository.save(original);

    await repository.save(
      original.copyWith(value: 125, updatedAt: DateTime.utc(2026, 3, 11)),
    );

    final stored = await repository.allMeasurements(period);
    expect(stored, hasLength(1));
    expect(stored.single.value, 125);
  });

  test('reports the latest measurement of a type', () async {
    await repository.save(
      measurement(id: 'older', at: DateTime(2026, 3, 10, 8)),
    );
    await repository.save(
      measurement(id: 'newer', at: DateTime(2026, 3, 20, 8)),
    );

    final latest = await repository.latestOf(MetricType.bloodPressure);
    expect(latest!.id, 'newer');
  });

  test('emits new measurements on the watch stream', () async {
    final emitted = <List<Measurement>>[];
    final subscription = repository
        .watchAllMeasurements(range: period)
        .listen(emitted.add);

    await repository.save(
      measurement(id: 'a', at: DateTime(2026, 3, 10, 8)),
    );
    await pumpEventQueue();

    expect(emitted.last.single.id, 'a');
    await subscription.cancel();
  });

  test('keeps the local day of a reading stable across a write', () async {
    final original = measurement(id: 'a', at: DateTime(2026, 3, 10, 23, 30));
    await repository.save(original);
    await repository.save(original.copyWith(value: 120));

    final stored = await repository.findById('a');
    expect(stored!.localDay, DateTime(2026, 3, 10));
    expect(stored.recordedAt, DateTime(2026, 3, 10, 23, 30).toUtc());
  });
}
