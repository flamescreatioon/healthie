/// The wire shapes of the Laravel sync protocol (`/api/v1/sync/*`).
///
/// Push: `POST sync/upload` with `{rows: [...]}` returns `{results: [...],
/// server_timestamp}`. Pull: `GET sync/changes?since=` returns `{changes:
/// [...], server_timestamp}`. Statuses: `applied | conflict | rejected |
/// invalid` — see docs/backend/04-sync-endpoints.md.
library;

/// One result row from `POST /api/v1/sync/upload`.
class SyncUploadResult {
  const SyncUploadResult({
    required this.entityId,
    required this.status,
    this.serverRow,
  });

  factory SyncUploadResult.fromJson(Map<String, dynamic> json) {
    return SyncUploadResult(
      entityId: json['entity_id'] as String?,
      status: json['status']! as String,
      serverRow: json['server_row'] as Map<String, dynamic>?,
    );
  }

  /// Null when the row itself was malformed (`invalid` without an id).
  final String? entityId;

  /// `applied`, `conflict`, `rejected`, or `invalid`.
  final String status;

  /// Present for `conflict` and `rejected`: the server's row wins.
  final Map<String, dynamic>? serverRow;

  bool get isApplied => status == 'applied';
  bool get isConflict => status == 'conflict';
  bool get isRejected => status == 'rejected';
}

/// One row from `GET /api/v1/sync/changes`.
class RemoteChange {
  const RemoteChange({
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.serverUpdatedAt,
  });

  factory RemoteChange.fromJson(Map<String, dynamic> json) {
    return RemoteChange(
      entityType: json['entity_type']! as String,
      entityId: json['entity_id']! as String,
      operation: json['operation']! as String,
      payload: Map<String, dynamic>.from(json['payload']! as Map),
      serverUpdatedAt:
          DateTime.parse(json['server_updated_at']! as String).toUtc(),
    );
  }

  final String entityType;
  final String entityId;

  /// `upsert` or `delete`.
  final String operation;
  final Map<String, dynamic> payload;
  final DateTime serverUpdatedAt;
}

/// The server's current watermark, for cursor advancement.
class SyncWatermark {
  const SyncWatermark(this.serverTimestamp);

  factory SyncWatermark.fromJson(Map<String, dynamic> json) {
    return SyncWatermark(
      DateTime.parse(json['server_timestamp']! as String).toUtc(),
    );
  }

  final DateTime serverTimestamp;
}
