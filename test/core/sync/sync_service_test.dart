import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthie/core/database/app_database.dart';
import 'package:healthie/core/sync/backend_client.dart';
import 'package:healthie/core/sync/sync_cursor_dao.dart';
import 'package:healthie/core/sync/sync_models.dart';
import 'package:healthie/core/sync/sync_outbox_dao.dart';
import 'package:healthie/core/sync/sync_service.dart';
import 'package:http/testing.dart';

AppDatabase _database() => AppDatabase.forTesting(NativeDatabase.memory());

/// A backend stub: queued upload responses, then queued changelog responses.
class FakeBackendClient extends BackendClient {
  FakeBackendClient({
    required this.uploadResponses,
    required this.changesResponses,
  }) : super(baseUrl: 'https://example.test', tokenProvider: () async => 't');

  final List<({List<SyncUploadResult> results, SyncWatermark watermark})>
      uploadResponses;
  final List<({List<RemoteChange> changes, SyncWatermark watermark})>
      changesResponses;

  final List<List<Map<String, dynamic>>> uploadedBatches = [];

  @override
  Future<({List<SyncUploadResult> results, SyncWatermark watermark})>
      uploadBatch(List<Map<String, dynamic>> rows) async {
    uploadedBatches.add(rows);
    return uploadResponses.removeAt(0);
  }

  @override
  Future<({List<RemoteChange> changes, SyncWatermark watermark})> fetchChanges(
    DateTime? since,
  ) async {
    return changesResponses.removeAt(0);
  }
}

SyncWatermark _watermark([int seconds = 0]) => SyncWatermark(
      DateTime.utc(2026, 3, 10, 12).add(Duration(seconds: seconds)),
    );

void main() {
  late AppDatabase database;
  late SyncOutboxDao outbox;
  late SyncCursorDao cursors;

  setUp(() {
    database = _database();
    outbox = SyncOutboxDao(database);
    cursors = SyncCursorDao(database);
  });

  tearDown(() => database.close());

  Future<void> enqueueUpsert(String id) => outbox.enqueue(
        operation: 'upsert',
        entityType: 'measurements',
        entityId: id,
        payload: <String, dynamic>{'id': id},
      );

  test('push completes applied rows and reports success', () async {
    await enqueueUpsert('a');
    final backend = FakeBackendClient(
      uploadResponses: [
        (
          results: [
            const SyncUploadResult(entityId: 'a', status: 'applied'),
          ],
          watermark: _watermark(),
        ),
      ],
      changesResponses: [(
        changes: const [],
        watermark: _watermark(),
      )],
    );
    final service = SyncService(
      database: database,
      outbox: outbox,
      cursorDao: cursors,
      backend: backend,
      applyRemoteChange: (_) async {},
    );

    expect(await service.runOnce(), SyncOutcome.success);
    expect(await outbox.pendingCount(), 0);
    expect(await cursors.getCursor(), _watermark().serverTimestamp);
  });

  test('conflict drops the queued op so the pull can overwrite locally',
      () async {
    await enqueueUpsert('a');
    final backend = FakeBackendClient(
      uploadResponses: [
        (
          results: [
            const SyncUploadResult(entityId: 'a', status: 'conflict'),
          ],
          watermark: _watermark(),
        ),
      ],
      changesResponses: [(
        changes: const [],
        watermark: _watermark(),
      )],
    );
    final service = SyncService(
      database: database,
      outbox: outbox,
      cursorDao: cursors,
      backend: backend,
      applyRemoteChange: (_) async {},
    );

    expect(await service.runOnce(), SyncOutcome.success);
    expect(await outbox.pendingCount(), 0);
  });

  test('invalid rows are quarantined with an attempt recorded', () async {
    await enqueueUpsert('a');
    final backend = FakeBackendClient(
      uploadResponses: [
        (
          results: [
            const SyncUploadResult(entityId: 'a', status: 'invalid'),
          ],
          watermark: _watermark(),
        ),
      ],
      changesResponses: [(
        changes: const [],
        watermark: _watermark(),
      )],
    );
    final service = SyncService(
      database: database,
      outbox: outbox,
      cursorDao: cursors,
      backend: backend,
      applyRemoteChange: (_) async {},
    );

    expect(await service.runOnce(), SyncOutcome.success);

    final pending = await outbox.pending();
    expect(pending, hasLength(1));
    expect(pending.single.attempts, 1);
    expect(pending.single.lastError, isNotNull);
  });

  test('pull applies changes and advances the cursor in one transaction',
      () async {
    final applied = <String>[];
    final backend = FakeBackendClient(
      uploadResponses: [],
      changesResponses: [(
        changes: [
          RemoteChange(
            entityType: 'measurements',
            entityId: 'remote-1',
            operation: 'upsert',
            payload: const {'id': 'remote-1'},
            serverUpdatedAt: DateTime.utc(2026, 3, 10, 12),
          ),
        ],
        watermark: _watermark(),
      )],
    );
    final service = SyncService(
      database: database,
      outbox: outbox,
      cursorDao: cursors,
      backend: backend,
      applyRemoteChange: (change) async {
        applied.add(change.entityId);
      },
    );

    expect(await service.runOnce(), SyncOutcome.success);
    expect(applied, ['remote-1']);
    expect(await cursors.getCursor(), _watermark().serverTimestamp);
  });

  test('retryable network failure keeps rows queued', () async {
    await enqueueUpsert('a');
    final failing = BackendClient(
      baseUrl: 'https://example.test',
      tokenProvider: () async => 't',
      httpClient: MockClient(
        (_) async => throw const SocketException('no connection'),
      ),
    );
    final service = SyncService(
      database: database,
      outbox: outbox,
      cursorDao: cursors,
      backend: failing,
      applyRemoteChange: (_) async {},
    );

    expect(await service.runOnce(), SyncOutcome.retryableFailure);
    expect(await outbox.pendingCount(), 1);
  });

  test('missing token routes to sign-in, not to retry', () async {
    final unsigned = BackendClient(
      baseUrl: 'https://example.test',
      tokenProvider: () async => null,
    );
    final service = SyncService(
      database: database,
      outbox: outbox,
      cursorDao: cursors,
      backend: unsigned,
      applyRemoteChange: (_) async {},
    );

    expect(await service.runOnce(), SyncOutcome.authFailure);
  });
}
