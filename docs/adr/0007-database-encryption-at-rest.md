# ADR 0007 — Database encryption at rest (SQLCipher)

## Status

Accepted. Implemented: SQLCipher-encrypted Drift database, key in the
platform keystore, plaintext→encrypted migration on upgrade.

## Context

The local Drift database is the source of truth and holds blood pressure,
weight, heart rate, medications, reminders, and notes. Until this change it
was a plaintext SQLite file: readable by anyone with file access (rooted
device, backup extraction, lost unlocked phone connected to a PC). The
`health-privacy-compliance` skill explicitly calls for Keystore-backed
encryption "if the threat model calls for it" — unauthorized file access to
years of health history qualifies.

## Decision

- **Whole-database encryption via SQLCipher**, not per-column encryption.
  Filtering and range queries (`local_day`, `metric_type`, values) keep using
  indexes unchanged; per-column AES would force decrypt-everything-then-filter
  and would leak metadata (dates, types, counts) anyway.
- **Cipher binary**: `sqlite3` 3.x's bundled SQLCipher build, selected via a
  `hooks.user_defines.sqlite3.source: sqlcipher` block in `pubspec.yaml`.
  Explicitly **not** `sqlcipher_flutter_libs` (0.7.0+eol, a no-op pin kept only
  as a transitive leftover — removed from direct deps) and **not**
  `sqlite3_flutter_libs` (EOL per `flutter-project-setup`).
- **Key lifecycle** (`lib/core/database/database_key.dart`): 256-bit CSPRNG
  key, generated on first launch, stored under `healthie_db_key_v1` in
  `flutter_secure_storage` (Android Keystore / iOS Keychain). Key bytes are
  bound as a `PRAGMA key = ?` blob parameter — never interpolated, never
  logged. No recovery path: key loss is data loss, stated in
  `docs/privacy-and-security.md`.
- **Opening** (`lib/core/database/encrypted_database.dart` + `main.dart`):
  key read → plaintext migration check → `driftDatabase` with a `setup`
  callback applying the key. The DB is opened eagerly before `runApp` and
  handed to Riverpod via `databaseProvider` override, keeping the whole
  provider graph synchronous. Keystore failure shows `DatabaseErrorApp`
  (fail-closed) instead of running unlocked.
- **Migration**: legacy plaintext `healthie.sqlite` is re-encrypted in place
  with `PRAGMA rekey` after a readability guard; a no-op for fresh and
  already-encrypted installs. A crash mid-rekey leaves plaintext that simply
  retries next launch.
- **Tests** (`flutter-testing`): key provider unit tests (create / stable /
  fresh-per-install / delete); full suite green (186 passing).

## Consequences

- APK grows (~3–5 MB native SQLCipher/OpenSSL libs); one extra permission-free
  dependency.
- In-memory test databases (`AppDatabase.forTesting`) stay unencrypted —
  correct, since encryption is a storage-layer property, not a model property.
- Desktop dev builds use the SQLCipher binary too; `flutter_secure_storage`
  falls back to plaintext storage on Windows/Linux dev machines (platform
  limitation, documented upstream) — production Android/iOS use the Keystore.
- Server-side encryption (TLS, Supabase at rest) remains a separate layer when
  cloud sync ships; this ADR covers only the on-device file.
- Pre-ship re-verification required: no health values in logs/crash/URLs
  (unchanged code paths, but the DB opener was touched).
