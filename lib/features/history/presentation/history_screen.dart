/// The history screen: a searchable, filterable audit trail of every record.
///
/// Deletion is soft and undoable. A mis-tap on a year of history is
/// otherwise unrecoverable.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/date_range.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/formatters/value_formatter.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_top_bar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/selectors.dart';
import '../../../shared/widgets/states.dart';
import '../../metrics/domain/blood_pressure_guideline.dart';
import '../../metrics/domain/measurement.dart';
import '../../metrics/domain/metric_type.dart';
import '../../metrics/presentation/providers/measurement_providers.dart';

/// The metric filters offered by the history screen.
enum HistoryFilter {
  all('All'),
  bloodPressure('Blood Pressure'),
  weight('Weight'),
  heartRate('Heart Rate'),
  glucose('Glucose');

  const HistoryFilter(this.label);

  final String label;

  bool matches(Measurement measurement) => switch (this) {
        HistoryFilter.all => true,
        HistoryFilter.bloodPressure =>
          measurement.metricType == MetricType.bloodPressure,
        HistoryFilter.weight => measurement.metricType == MetricType.weight,
        HistoryFilter.heartRate =>
          measurement.metricType == MetricType.heartRate,
        HistoryFilter.glucose =>
          measurement.metricType == MetricType.bloodGlucose,
      };
}

/// The complete history of recorded measurements.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  HistoryFilter _filter = HistoryFilter.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = DateRange.endingOn(DateTime.now(), 3650);
    final measurements = ref.watch(
      allMeasurementsProvider(range),
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopBar(
              title: 'Historical Records',
              icon: Icons.monitor_heart_rounded,
            ),
            Expanded(
              child: measurements.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: LoadingState(height: 300, lines: 4),
                ),
                error: (error, stack) => ErrorState(
                  message: "We couldn't load your history.",
                  onRetry: () => ref.invalidate(allMeasurementsProvider(range)),
                ),
                data: (data) => _HistoryBody(
                  measurements: data,
                  filter: _filter,
                  query: _query,
                  searchController: _searchController,
                  onQueryChanged: (value) => setState(() => _query = value),
                  onFilterChanged: (value) => setState(() => _filter = value),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add a record',
        onPressed: () => context.push('/entry/blood-pressure'),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _HistoryBody extends ConsumerWidget {
  const _HistoryBody({
    required this.measurements,
    required this.filter,
    required this.query,
    required this.searchController,
    required this.onQueryChanged,
    required this.onFilterChanged,
  });

  final List<Measurement> measurements;
  final HistoryFilter filter;
  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<HistoryFilter> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filtered = _applyFilters(measurements);
    final groups = _groupByDay(filtered);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Row(
          children: [
            Text(
              'Health History',
              style: AppTypography.headlineSmall
                  .copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(width: 8),
            StatusPill(
              label: '${filtered.length} logs',
              tone: StatusTone.neutral,
              dense: true,
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _showExportSheet(context, filtered),
              icon: const Icon(Icons.ios_share_rounded, size: 16),
              label: const Text('Export'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('history-search-field'),
          controller: searchController,
          onChanged: onQueryChanged,
          style: AppTypography.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Search records, notes, tags…',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      searchController.clear();
                      onQueryChanged('');
                    },
                  ),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final option in HistoryFilter.values) ...[
                SelectableChip(
                  label: option.label,
                  selected: option == filter,
                  onChanged: (_) => onFilterChanged(option),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: measurements.isEmpty
                  ? 'No records yet'
                  : 'No matching records',
              message: measurements.isEmpty
                  ? 'Log your first blood pressure reading or weigh-in to '
                      'start building your history.'
                  : 'Try a different search term or filter.',
              actionLabel: measurements.isEmpty ? 'Log a reading' : null,
              onAction: measurements.isEmpty
                  ? () => context.push('/entry/blood-pressure')
                  : null,
            ),
          )
        else
          for (final group in groups) ...[
            _DayHeading(day: group.day, count: group.entries.length),
            const SizedBox(height: 8),
            for (final measurement in group.entries) ...[
              _MeasurementCard(measurement: measurement),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
          ],
        if (filtered.isNotEmpty) ...[
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Showing ${filtered.length} records across '
                  '${groups.length} days',
                  style: AppTypography.labelMedium
                      .copyWith(color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  'Records are stored on this device and are never transmitted '
                  'without your consent.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<Measurement> _applyFilters(List<Measurement> source) {
    final lowered = query.trim().toLowerCase();
    return source.where((measurement) {
      if (!filter.matches(measurement)) return false;
      if (lowered.isEmpty) return true;
      final notes = measurement.context.notes?.toLowerCase() ?? '';
      final device = measurement.context.device?.toLowerCase() ?? '';
      final values = [
        measurement.value.toString(),
        measurement.secondaryValue?.toString() ?? '',
        measurement.metricType.wireName,
        notes,
        device,
      ].join(' ');
      return values.contains(lowered);
    }).toList();
  }

  List<_DayGroup> _groupByDay(List<Measurement> source) {
    final map = <DateTime, List<Measurement>>{};
    for (final measurement in source) {
      map.putIfAbsent(startOfLocalDay(measurement.recordedAt), () => [])
          .add(measurement);
    }
    final days = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return days.map((day) => _DayGroup(day: day, entries: map[day]!)).toList();
  }

  void _showExportSheet(BuildContext context, List<Measurement> records) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Export ${records.length} records',
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Exports are generated on this device. Nothing is uploaded '
                'unless you share the file yourself.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('CSV'),
                subtitle: const Text('One row per reading, with context'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showCsvPreview(context, records);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('PDF summary'),
                subtitle: const Text('A report to discuss with a clinician'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showComingSoon(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCsvPreview(BuildContext context, List<Measurement> records) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('CSV preview'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(_buildCsv(records)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF export is planned but not implemented yet.'),
      ),
    );
  }

  static String _buildCsv(List<Measurement> records) {
    final buffer = StringBuffer()
      ..writeln(
        'id,metric_type,value,unit,secondary_value,tertiary_value,recorded_at,'
        'notes',
      );
    for (final record in records) {
      buffer.writeln([
        record.id,
        record.metricType.wireName,
        record.value,
        record.unit.symbol,
        record.secondaryValue ?? '',
        record.tertiaryValue ?? '',
        record.recordedAt.toUtc().toIso8601String(),
        _escape(record.context.notes ?? ''),
      ].join(','));
    }
    return buffer.toString();
  }

  static String _escape(String value) => '"${value.replaceAll('"', '""')}"';
}

class _DayGroup {
  const _DayGroup({required this.day, required this.entries});

  final DateTime day;
  final List<Measurement> entries;
}

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.day, required this.count});

  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${relativeDayLabel(day, now: DateTime.now())} — '
            '${mediumDateLabel(day)}',
            style: AppTypography.headlineSmall
                .copyWith(color: theme.colorScheme.onSurface),
          ),
        ),
        Text(
          '$count ${count == 1 ? 'ENTRY' : 'ENTRIES'}',
          style: AppTypography.labelMicro.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _MeasurementCard extends ConsumerWidget {
  const _MeasurementCard({required this.measurement});

  final Measurement measurement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    final (IconData icon, Color color, String label) = switch (measurement.metricType) {
      MetricType.bloodPressure => (
          Icons.monitor_heart_rounded,
          colors.metricBloodPressure,
          'Blood Pressure'
        ),
      MetricType.weight => (
          Icons.monitor_weight_rounded,
          colors.metricWeight,
          'Body Weight'
        ),
      MetricType.heartRate => (
          Icons.favorite_rounded,
          colors.metricHeartRate,
          'Heart Rate'
        ),
      MetricType.spo2 => (
          Icons.air_rounded,
          colors.metricOxygen,
          'Blood Oxygen'
        ),
      MetricType.bodyTemperature => (
          Icons.thermostat_rounded,
          colors.metricTemperature,
          'Body Temperature'
        ),
      MetricType.bloodGlucose => (
          Icons.water_drop_rounded,
          colors.metricGlucose,
          'Blood Glucose'
        ),
    };

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MetricBadge(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label.toUpperCase(),
                        style: AppTypography.labelMicro.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    if (measurement.metricType == MetricType.bloodPressure)
                      _CategoryPill(measurement: measurement),
                    if (measurement.metricType == MetricType.weight)
                      _DeltaPill(measurement: measurement),
                  ],
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _valueLabel(measurement),
                        style: AppTypography.displayNumeric
                            .copyWith(color: theme.colorScheme.onSurface),
                      ),
                      TextSpan(
                        text: ' ${_unitLabel(measurement)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _metaLabel(measurement),
                  style: AppTypography.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (measurement.context.notes != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 14,
                          color: theme.colorScheme.tertiary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '“${measurement.context.notes}”',
                            style: AppTypography.bodySmall
                                .copyWith(color: theme.colorScheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Record options',
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onSelected: (value) => _onAction(context, ref, value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  static String _valueLabel(Measurement measurement) {
    if (measurement.metricType == MetricType.bloodPressure) {
      return formatBloodPressure(
        measurement.value,
        measurement.secondaryValue,
      );
    }
    if (measurement.metricType == MetricType.weight) {
      return formatValue(measurement.value, precision: 1);
    }
    return formatValue(measurement.value);
  }

  static String _unitLabel(Measurement measurement) {
    if (measurement.metricType == MetricType.bloodPressure) return 'mmHg';
    return measurement.unit.symbol;
  }

  static String _metaLabel(Measurement measurement) {
    final parts = <String>[
      timestampLabel(measurement.recordedAt, now: DateTime.now()),
    ];
    final context = measurement.context;
    if (measurement.pulse != null) {
      parts.add('${formatValue(measurement.pulse!)} bpm');
    }
    if (context.posture != null) parts.add(context.posture!.label);
    if (context.arm != null) parts.add(context.arm!.label);
    if (context.weightTimeOfDay != null) {
      parts.add(context.weightTimeOfDay!.label);
    }
    if (context.device != null) parts.add(context.device!);
    return parts.join(' • ');
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    switch (action) {
      case 'edit':
        final route = measurement.metricType == MetricType.weight
            ? '/entry/weight'
            : '/entry/blood-pressure';
        await context.push(route, extra: measurement);
      case 'delete':
        await _confirmDelete(context, ref);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this record?'),
        content: const Text(
          'The record is removed from your history. You can undo this for a '
          'few seconds afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final deletedAt = DateTime.now().toUtc();
    await ref
        .read(measurementRepositoryProvider)
        .softDelete(measurement.id, deletedAt: deletedAt);

    messenger.showSnackBar(
      SnackBar(
        content: const Text('Record deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => ref
              .read(measurementRepositoryProvider)
              .restore(measurement.id, updatedAt: DateTime.now().toUtc()),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.measurement});

  final Measurement measurement;

  @override
  Widget build(BuildContext context) {
    final diastolic = measurement.secondaryValue;
    if (diastolic == null) return const SizedBox.shrink();
    final category = classifyBloodPressure(
      systolic: measurement.value.round(),
      diastolic: diastolic.round(),
    );
    final (String label, StatusTone tone) = switch (category) {
      BpCategory.normal => ('Optimal', StatusTone.positive),
      BpCategory.elevated => ('Elevated', StatusTone.warning),
      BpCategory.stage1Hypertension => ('Stage 1', StatusTone.warning),
      BpCategory.stage2Hypertension => ('Stage 2', StatusTone.critical),
      BpCategory.hypertensiveCrisis => ('Seek care', StatusTone.critical),
    };
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: StatusPill(label: label, tone: tone, dense: true),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.measurement});

  final Measurement measurement;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: StatusPill(
        label: '${formatSigned(measurement.value, precision: 1)} kg',
        tone: StatusTone.neutral,
        icon: Icons.trending_down_rounded,
        dense: true,
      ),
    );
  }
}
