/// The failure hierarchy crossing layer boundaries.
///
/// Repositories translate low-level exceptions (SQLite, HTTP, platform
/// channels) into these. Presentation code never sees a `SocketException` and
/// never renders a raw exception string to the user.
library;

sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  /// A developer-facing description. Never shown verbatim to the user.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The user entered something the app cannot accept.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {this.field});

  /// The field the message belongs to, when one can be singled out.
  final String? field;

  @override
  String toString() => 'ValidationFailure($field): $message';
}

/// The local database rejected or could not complete an operation.
final class StorageFailure extends AppFailure {
  const StorageFailure(super.message, {this.cause});

  final Object? cause;
}

/// The device could not reach the backend.
final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {this.cause});

  final Object? cause;
}

/// A platform permission was not granted, or the platform is unavailable.
final class PermissionFailure extends AppFailure {
  const PermissionFailure(super.message, {this.isDenied = false});

  /// True when the user actively declined, as opposed to the platform being
  /// missing or the request failing.
  final bool isDenied;
}

/// A sync operation failed and will be retried.
final class SyncFailure extends AppFailure {
  const SyncFailure(super.message, {this.isRetryable = true, this.cause});

  final bool isRetryable;
  final Object? cause;
}

/// The server permanently rejected a sync operation.
///
/// A 400, 403, or 422 means the payload itself is wrong, so retrying the same
/// bytes would fail the same way. The caller quarantines the row instead of
/// retrying it forever.
final class SyncPermanentFailure extends AppFailure {
  const SyncPermanentFailure(super.message, {this.statusCode});

  /// The HTTP status that rejected the change, when one did.
  final int? statusCode;
}
