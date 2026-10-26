/// Unit tests for the database encryption key provider.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthie/core/database/database_key.dart';

/// In-memory stand-in for the platform keystore.
class _FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SecureStorageDatabaseKeyProvider', () {
    test('creates a 256-bit key on first launch', () async {
      final storage = _FakeSecureStorage();
      final provider = SecureStorageDatabaseKeyProvider(storage: storage);

      final key = await provider.getOrCreateKey();

      expect(key, hasLength(32));
    });

    test('returns the same key on subsequent launches', () async {
      final storage = _FakeSecureStorage();
      final provider = SecureStorageDatabaseKeyProvider(storage: storage);

      final first = await provider.getOrCreateKey();
      final second = await provider.getOrCreateKey();

      expect(second, orderedEquals(first));
    });

    test('generates a fresh key per install', () async {
      final first =
          await SecureStorageDatabaseKeyProvider(storage: _FakeSecureStorage())
              .getOrCreateKey();
      final second =
          await SecureStorageDatabaseKeyProvider(storage: _FakeSecureStorage())
              .getOrCreateKey();

      expect(second, isNot(orderedEquals(first)));
    });

    test('deleteKey removes the stored key', () async {
      final storage = _FakeSecureStorage();
      final provider = SecureStorageDatabaseKeyProvider(storage: storage);

      await provider.getOrCreateKey();
      await provider.deleteKey();

      expect(storage.values, isEmpty);
      // Next launch generates a new key rather than reusing the old one.
      final fresh = await provider.getOrCreateKey();
      expect(storage.values, hasLength(1));
      expect(fresh, hasLength(32));
    });
  });
}
