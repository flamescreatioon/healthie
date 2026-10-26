/// Owns the database encryption key: creation, storage, and retrieval.
///
/// The 256-bit key is generated once with a CSPRNG and kept in
/// `FlutterSecureStorage`, which is backed by the Android Keystore
/// (hardware-backed where the device supports it). The key never appears in
/// logs, is never synced, and never leaves the device.
///
/// Losing the key means losing the database — that is the point. There is no
/// recovery path by design.
library;

import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../error/app_failure.dart';

/// Creates, stores, and retrieves the database encryption key.
abstract interface class DatabaseKeyProvider {
  /// Returns the existing key, creating and persisting one on first launch.
  ///
  /// Throws [StorageFailure] when the platform keystore is unavailable.
  Future<List<int>> getOrCreateKey();
}

/// [DatabaseKeyProvider] backed by the platform keystore.
final class SecureStorageDatabaseKeyProvider
    implements DatabaseKeyProvider {
  SecureStorageDatabaseKeyProvider({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _keyName = 'healthie_db_key_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<List<int>> getOrCreateKey() async {
    try {
      final existing = await _storage.read(key: _keyName);
      if (existing != null && existing.isNotEmpty) {
        return _decode(existing);
      }
      final fresh = _generate();
      await _storage.write(key: _keyName, value: _encode(fresh));
      return fresh;
    } on Object catch (error) {
      throw StorageFailure(
        'Could not access the encrypted database key.',
        cause: error,
      );
    }
  }

  /// Deletes the stored key. Used on explicit data wipe; the database file
  /// must be deleted alongside, otherwise it becomes permanently unreadable.
  Future<void> deleteKey() async {
    try {
      await _storage.delete(key: _keyName);
    } on Object catch (error) {
      throw StorageFailure(
        'Could not delete the encrypted database key.',
        cause: error,
      );
    }
  }

  /// Generates 32 random bytes with a cryptographically secure RNG.
  static List<int> _generate() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256));
  }

  /// Hex-encodes the key for storage. Hex keeps the value printable and
  /// sidesteps base64 padding quirks across platform keystore backends.
  static String _encode(List<int> bytes) => bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();

  static List<int> _decode(String encoded) {
    final bytes = <int>[];
    for (var i = 0; i + 1 < encoded.length; i += 2) {
      bytes.add(int.parse(encoded.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}
