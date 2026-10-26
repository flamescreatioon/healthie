/// The application widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class HealthieApp extends ConsumerWidget {
  const HealthieApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-schedule reminders on app start (idempotent: same IDs overwrite, so
    // calling repeatedly is safe). Never prompts here: without the OS
    // permission this silently schedules nothing, and the reminders UI
    // explains and asks at the moment the user wants the feature.
    ref.read(reminderNotificationSchedulerProvider).scheduleAll();

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Healthie',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
