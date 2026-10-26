/// Providers that assemble the home dashboard.
///
/// The dashboard reads one range of measurements and derives everything it
/// shows from that single list, so every card on the screen is consistent
/// with every other card.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/utils/date_range.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../metrics/domain/measurement.dart';

/// How far back the dashboard looks. Ninety days covers the 30-day
/// comparisons the cards show, with room for the previous period.
final dashboardRangeProvider = Provider<DateRange>((ref) {
  final now = ref.watch(clockProvider).now();
  final today = startOfLocalDay(now);
  return DateRange(
    start: today.subtract(const Duration(days: 89)),
    end: today.add(const Duration(days: 1)),
  );
});

/// Every measurement the dashboard needs.
final dashboardMeasurementsProvider = StreamProvider<List<Measurement>>((ref) {
  return ref
      .watch(measurementRepositoryProvider)
      .watchAllMeasurements(range: ref.watch(dashboardRangeProvider));
});
