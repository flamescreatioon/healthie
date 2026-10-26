/// Application routing.
///
/// One `GoRouter` instance, declared once. Tab navigation uses a
/// `StatefulShellRoute` so each tab keeps its own scroll position and
/// back stack; entry sheets are top-level routes pushed over the shell.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/analytics/presentation/analytics_screen.dart';
import '../features/blood_pressure/presentation/blood_pressure_entry_screen.dart';
import '../features/metrics/presentation/heart_rate_entry_screen.dart';
import '../features/dashboard/presentation/home_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/medications/presentation/medication_entry_screen.dart';
import '../features/medications/presentation/medication_log_screen.dart';
import '../features/medications/presentation/medication_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/track/presentation/track_screen.dart';
import '../features/weight/presentation/weight_entry_screen.dart';
import '../shared/widgets/bottom_nav.dart';

/// The route paths, in one place.
abstract final class AppRoutes {
  static const String home = '/home';
  static const String track = '/track';
  static const String analytics = '/analytics';
  static const String history = '/history';
  static const String profile = '/profile';
  static const String entryBloodPressure = '/entry/blood-pressure';
  static const String entryWeight = '/entry/weight';
  static const String entryHeartRate = '/entry/heart-rate';
  static const String medication = '/medication';
  static const String medicationEntry = '/medication/entry';
  static const String medicationLog = '/medication/log/:id';
}

/// The app's router.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.track,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: TrackScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.analytics,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: AnalyticsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HistoryScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ProfileScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.entryBloodPressure,
        builder: (context, state) => const BloodPressureEntryScreen(),
      ),
      GoRoute(
        path: AppRoutes.entryWeight,
        builder: (context, state) => const WeightEntryScreen(),
      ),
      GoRoute(
        path: AppRoutes.entryHeartRate,
        builder: (context, state) => const HeartRateEntryScreen(),
      ),
      GoRoute(
        path: AppRoutes.medication,
        builder: (context, state) => const MedicationScreen(),
      ),
      GoRoute(
        path: AppRoutes.medicationEntry,
        builder: (context, state) => const MedicationEntryScreen(),
      ),
      GoRoute(
        path: AppRoutes.medicationLog,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return MedicationLogScreen(medicationId: id);
        },
      ),
    ],
  );
});

/// The scaffold that hosts the tab navigation.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: HealthieBottomNav(
        currentIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        onQuickLog: () => _showQuickLogSheet(context),
      ),
    );
  }

  void _showQuickLogSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Log a measurement',
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.monitor_heart_rounded),
                title: const Text('Blood pressure'),
                subtitle: const Text('Systolic, diastolic, and pulse'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  GoRouter.of(context).push(AppRoutes.entryBloodPressure);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.monitor_weight_rounded),
                title: const Text('Body weight'),
                subtitle: const Text('Weight, body fat, and waist'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  GoRouter.of(context).push(AppRoutes.entryWeight);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.medication_rounded),
                title: const Text('Medications'),
                subtitle: const Text('Doses, schedules, and adherence'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  GoRouter.of(context).push(AppRoutes.medication);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
