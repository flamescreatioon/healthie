/// Healthie — a personal health tracker and longitudinal analytics app.
///
/// The app boots straight into the local-first experience: the Drift database
/// is the source of truth, the network is never on the critical path of a
/// user-visible write, and nothing the user records ever leaves the device
/// without their explicit consent.
///
/// The database file is SQLCipher-encrypted at rest. The key lives in the
/// platform keystore (Android Keystore / iOS Keychain) and is read before
/// `runApp`, so the Riverpod graph receives an already-open database.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/database/app_database.dart';
import 'core/database/encrypted_database.dart';
import 'core/error/app_failure.dart';
import 'core/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local notifications before running the app.
  // This must happen before any reminders can be scheduled.
  unawaited(NotificationService.instance.initialize());

  // Open the encrypted database before the widget tree exists, so every
  // provider downstream can stay synchronous. On failure the app cannot show
  // health data, so it shows an error screen instead of running unlocked.
  AppDatabase? database;
  StorageFailure? openError;
  try {
    database = await openEncryptedDatabase();
  } on StorageFailure catch (error) {
    openError = error;
  }

  runApp(
    ProviderScope(
      overrides: [
        if (database != null) databaseProvider.overrideWithValue(database),
      ],
      child: database != null
          ? const HealthieApp()
          : DatabaseErrorApp(error: openError),
    ),
  );
}

/// Shown when the encrypted database cannot be opened (e.g. the platform
/// keystore is unavailable). Explains the situation without leaking details.
class DatabaseErrorApp extends StatelessWidget {
  const DatabaseErrorApp({required this.error, super.key});

  final StorageFailure? error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Could not unlock your health data',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your encrypted data is safe, but the device keystore is '
                  'unavailable right now. Restart the app and try again.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
