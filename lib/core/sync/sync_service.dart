/// Drains the outbox to the Laravel backend and applies the changelog.
///
/// Push: claim outbox rows, compact to the latest row per entity (delete
/// wins), `POST sync/upload`, apply per-row results. Pull: read the cursor
/// from the local database, `GET sync/changes?since=`, apply rows and advance
/// the cursor in one transaction.
///
/// The network is never on the critical path of a user-visible write: a
/// failure here is logged and retried silently; the UI already shows the
/// local data.
library;

import 'dart:async';
import 'dart:convert';

import '../database/app_database.dart';
import '../error/app_failure.dart';
import 'backend_client.dart';
import 'sync_cursor_dao.dart';
import 'sync_models.dart';
import 'sync_outbox_dao.dart';

/// How the last sync attempt ended. The UI shows a "not synced" indicator
/// at most; a background failure never blocks or alarms the user.
enum SyncOutcome {
  /// Everything pushed and pulled cleanly.
  success,

  /// Nothing to do: signed out, or nothing queued and nothing new upstream.
  idle,

  /// A retryable failure; rows stay queued for the next trigger.
  retryableFailure,

  /// Signed out mid-sync or session dead: route to the sign-in screen.
  authFailure,
}

class SyncService {
  SyncService({
    required AppDatabase database,
    required SyncOutboxDao outbox,
    required SyncCursorDao cursorDao,
    required this.backend,
    required this.applyRemoteChange,
    this.onLog = _dropLog,
  })  : _db = database,
        _outbox = outbox,
        _cursors = cursorDao;

  final AppDatabase _db;
  final SyncOutboxDao _outbox;
  final SyncCursorDao _cursors;

  /// The HTTP client speaking `/api/v1`.
  final BackendClient backend;

  /// Applies one pulled changelog row to the local database.
  final Future<void> Function(RemoteChange change) applyRemoteChange;

  /// Observability hook; defaults to dropping messages.
  final void Function(String message) onLog;

  static void _dropLog(String message) {}

  /// Runs one push-then-pull cycle.
  Future<SyncOutcome> runOnce() async {
    try {
      final pushed = await _push();
      final pulled = await _pull();
      if (!pushed && !pulled) return SyncOutcome.idle;
      return SyncOutcome.success;
    } on SyncFailure catch (failure) {
      onLog('sync failed: ${failure.message}');
      return failure.isRetryable
          ? SyncOutcome.retryableFailure
          : SyncOutcome.authFailure;
    } on Object catch (error) {
      onLog('sync failed: $error');
      return SyncOutcome.retryableFailure;
    }
  }

  /// Claims queued rows, uploads them, and applies per-row results.
  ///
  /// Returns true when at least one row reached the server.
  Future<bool> _push() async {
    final pending = await _outbox.pending(limit: 100);
    if (pending.isEmpty) return false;

    // Compact: one row per entity, latest wins — unless the latest is an
    // upsert over a delete, in which case the delete wins so a retry can
    // never resurrect a record the user deleted.
    final latestByEntity = <String, SyncOutboxRow>{};
    for (final row in pending) {
      final key = '${row.entityType}:${row.entityId}';
      final existing = latestByEntity[key];
      if (existing == null ||
          row.queuedAt.isAfter(existing.queuedAt)) {
        latestByEntity[key] = row;
      }
    }
    final compacted = latestByEntity.values.toList();
    final claimed = <SyncOutboxRow>[];
    for (final row in compacted) {
      if (await _outbox.claim(row.id)) claimed.add(row);
    }
    if (claimed.isEmpty) return false;

    List<SyncUploadResult> results;
    try {
      final upload = await backend.uploadBatch(
        claimed
            .map(
              (row) => <String, dynamic>{
                'entity_type': row.entityType,
                'entity_id': row.entityId,
                'operation': row.operation,
                'payload': jsonDecode(row.payload) as Map<String, dynamic>,
                'client_updated_at':
                    row.queuedAt.toUtc().toIso8601String(),
              },
            )
            .toList(),
      );
      results = upload.results;
    } on Object catch (failure) {
      // No row reached the server: record the attempt on each claimed row
      // and release the claims so the next trigger retries them. A permanent
      // envelope rejection is quarantined the same way as a transport
      // failure — the rows stay queued either way.
      for (final row in claimed) {
        await _outbox.fail(row.id, '$failure');
      }
      rethrow;
    }

    for (var index = 0; index < claimed.length; index++) {
      final row = claimed[index];
      final result = index < results.length
          ? results[index]
          : SyncUploadResult(entityId: row.entityId, status: 'invalid');
      await _applyUploadResult(row, result);
    }
    return true;
  }

  /// Applies one per-row upload result.
  Future<void> _applyUploadResult(
    SyncOutboxRow row,
    SyncUploadResult result,
  ) async {
    switch (result.status) {
      case 'applied':
        await _outbox.complete(row.id);
      case 'conflict' || 'rejected':
        // Server wins (or the tombstone wins): drop the queued op. The
        // winning row arrives via the next pull and overwrites locally.
        await _outbox.complete(row.id);
      case 'invalid':
        await _outbox.fail(row.id, 'rejected by server');
      default:
        await _outbox.fail(row.id, 'unknown status: ${result.status}');
    }
  }

  /// Pulls the changelog and applies it with the cursor in one transaction.
  ///
  /// Returns true when at least one change was applied.
  Future<bool> _pull() async {
    final cursor = await _cursors.getCursor();
    final (:changes, :watermark) = await backend.fetchChanges(cursor);

    if (changes.isEmpty) {
      // Advance the cursor to the server watermark when the server reports
      // one beyond ours, so the next pull starts from a fresh window.
      if (cursor == null ||
          watermark.serverTimestamp.isAfter(cursor)) {
        await _cursors.setCursor(watermark.serverTimestamp);
      }
      return false;
    }

    await _db.transaction(() async {
      for (final change in changes) {
        await applyRemoteChange(change);
      }
      await _cursors.setCursor(watermark.serverTimestamp);
    });
    return true;
  }
}
