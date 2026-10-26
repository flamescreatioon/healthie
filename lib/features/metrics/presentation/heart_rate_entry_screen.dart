/// Heart rate entry screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/units/unit.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/id_generator.dart';
import '../../../features/metrics/domain/measurement.dart';
import '../../../features/metrics/domain/metric_type.dart';
import '../../../features/metrics/domain/reading_context.dart';
import '../../../shared/form/entry_widgets.dart';
import '../../../shared/formatters/value_formatter.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_top_bar.dart';

class HeartRateEntryScreen extends ConsumerStatefulWidget {
  const HeartRateEntryScreen({super.key, this.existing});
  final Measurement? existing;

  @override
  ConsumerState<HeartRateEntryScreen> createState() => _HeartRateEntryScreenState();
}

class _HeartRateEntryScreenState extends ConsumerState<HeartRateEntryScreen> {
  final _bpmController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _timestamp = DateTime.now();
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _bpmController.text = formatValue(e.value);
      _notesController.text = e.context.notes ?? '';
      _timestamp = e.recordedAt.toLocal();
    }
    _bpmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _bpmController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool _validate() {
    final parsed = parseNumeric(_bpmController.text);
    final spec = MetricCatalog.heartRate;
    setState(() {
      if (parsed == null) {
        _error = 'Please enter your heart rate';
      } else if (parsed < spec.min || parsed > spec.max) {
        _error = 'Enter a value between ${spec.min.round()} and ${spec.max.round()} bpm';
      } else {
        _error = null;
      }
    });
    return _error == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    final repository = ref.read(measurementRepositoryProvider);
    final clock = ref.read(clockProvider);
    final now = clock.now();
    final existing = widget.existing;
    final parsed = parseNumeric(_bpmController.text)!;

    final measurement = Measurement(
      id: existing?.id ?? newId(),
      metricType: MetricType.heartRate,
      value: parsed,
      unit: Unit.beatsPerMinute,
      recordedAt: _timestamp.toUtc(),
      localDay: startOfLocalDay(_timestamp),
      createdAt: existing?.createdAt ?? now.toUtc(),
      updatedAt: now.toUtc(),
      source: existing?.source ?? MeasurementSource.manual,
      isSynced: false,
      context: MeasurementContext(
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );

    setState(() => _isSaving = true);
    try {
      await repository.save(measurement);
    } on Object {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save your entry.")),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppTopBar(
        title: 'Log heart rate',
        icon: Icons.favorite_rounded,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _bpmController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Heart rate',
                      suffixText: 'bpm',
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(_isSaving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
