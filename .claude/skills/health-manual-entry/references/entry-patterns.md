# Entry Patterns

Reference implementations. Adjust naming; keep the shapes.

## Shared toolkit — `shared/form/`

### NumericField

```dart
class NumericField extends StatefulWidget {
  const NumericField({
    super.key,
    required this.controller,
    required this.label,
    this.unit,
    this.precision = 1,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? unit;
  final int precision;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  State<NumericField> createState() => _NumericFieldState();
}

class _NumericFieldState extends State<NumericField> {
  late final NumberFormat _format;
  late final NumberFormat _parser;

  @override
  void initState() {
    super.initState();
    final locale = Localizations.localeOf(context).toString();
    _format = NumberFormat.decimalPattern(locale);
    _parser = NumberFormat.decimalPattern(locale);
  }

  /// Strips grouping separators and normalises to a canonical decimal point.
  double? parse(String raw) {
    if (raw.trim().isEmpty) return null;
    final cleaned = raw.replaceAll(RegExp(r'[^\d,.\-]'), '');
    final normalised = _localeUsesComma
        ? cleaned.replaceAll('.', '').replaceAll(',', '.')
        : cleaned.replaceAll(',', '');
    return double.tryParse(normalised);
  }

  bool get _localeUsesComma {
    final sep = _format.symbols.DECIMAL_SEP;
    return sep == ',';
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.unit,
        errorText: widget.errorText,
        border: const OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
      validator: (raw) {
        if (raw == null || raw.trim().isEmpty) return 'Required';
        final value = parse(raw);
        if (value == null) return 'Enter a number';
        return null;
      },
    );
  }
}
```

### UnitToggle

```dart
class UnitToggle extends StatelessWidget {
  const UnitToggle({
    super.key,
    required this.units,
    required this.selected,
    required this.onSelected,
    required this.onConvertValue,
  });

  final List<Unit> units;
  final Unit selected;
  final ValueChanged<Unit> onSelected;
  final ValueChanged<Unit> onConvertValue;

  @override
  Widget build(BuildContext context) {
    if (units.length < 2) return const SizedBox.shrink();
    return SegmentedButton<Unit>(
      segments: units
          .map((u) => ButtonSegment(value: u, label: Text(u.symbol)))
          .toList(),
      selected: {selected},
      onSelectionChanged: (s) {
        final next = s.first;
        onConvertValue(next);
        onSelected(next);
      },
    );
  }
}
```

The conversion callback mutates the value controller *before* the unit label
changes, so the number always matches the label.

### DateTimeSelector

```dart
class DateTimeSelector extends StatelessWidget {
  const DateTimeSelector({super.key, required this.value, required this.onChanged});

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: Text(DateFormat.yMMMd().format(value)),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked == null) return;
              onChanged(DateTime(
                picked.year, picked.month, picked.day,
                value.hour, value.minute,
              ));
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.schedule),
            label: Text(DateFormat.Hm().format(value)),
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(value),
              );
              if (picked == null) return;
              onChanged(DateTime(
                value.year, value.month, value.day,
                picked.hour, picked.minute,
              ));
            },
          ),
        ),
      ],
    );
  }
}
```

## Weight entry

```dart
class WeightEntryForm extends ConsumerStatefulWidget {
  const WeightEntryForm({super.key});

  @override
  ConsumerState<WeightEntryForm> createState() => _WeightEntryFormState();
}

class _WeightEntryFormState extends ConsumerState<WeightEntryForm> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Unit _unit = Unit.kilogram;
  DateTime _recordedAt = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _convert(Unit next) {
    final parsed = double.tryParse(_controller.text.replaceAll(',', '.'));
    if (parsed == null) {
      setState(() => _unit = next);
      return;
    }
    final canonical = _unit.toCanonical(parsed, from: _unit, to: Unit.kilogram);
    final display = Unit.kilogram.fromCanonical(canonical, to: next);
    _controller.text = display.toStringAsFixed(1);
    setState(() => _unit = next);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final parsed = double.tryParse(_controller.text.replaceAll(',', '.'));
    if (parsed == null) return;

    setState(() => _saving = true);
    try {
      final canonical = _unit.toCanonical(parsed, from: _unit, to: Unit.kilogram);
      await ref.read(logRepositoryProvider).saveWeight(
            WeightEntry(
              id: const Uuid().v4(),
              valueKg: canonical,
              recordedAt: _recordedAt.toUtc(),
              localDay: _recordedAt.toLocalDay(),
              source: MeasurementSource.manual,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } on AppFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NumericField(
            controller: _controller,
            label: 'Weight',
            unit: _unit.symbol,
            precision: 1,
          ),
          const SizedBox(height: 12),
          UnitToggle(
            units: const [Unit.kilogram, Unit.pound],
            selected: _unit,
            onSelected: (u) => setState(() => _unit = u),
            onConvertValue: _convert,
          ),
          const SizedBox(height: 12),
          DateTimeSelector(
            value: _recordedAt,
            onChanged: (v) => setState(() => _recordedAt = v),
          ),
          const SizedBox(height: 20),
          SaveButton(
            label: 'Save weight',
            isSaving: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
```

## Blood pressure — two related values

Blood pressure is two measurements sharing a `recordedAt`. Model it as two
`Measurement` rows with the same timestamp, or as a dedicated record. Either is
fine; be consistent.

```dart
Row(
  children: [
    Expanded(
      child: NumericField(
        controller: _systolic,
        label: 'Systolic',
        unit: 'mmHg',
        precision: 0,
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: NumericField(
        controller: _diastolic,
        label: 'Diastolic',
        unit: 'mmHg',
        precision: 0,
      ),
    ),
  ],
)
```

Validate the relationship as well as the ranges: systolic must exceed diastolic.
Show that as a form-level error, not two field errors.

## Sleep entry

```dart
// Start and end times, with a duration computed from them.
final duration = end.difference(start);
```

Do not ask the user for a duration *and* start/end times — that is a
contradiction waiting to happen. Derive one from the other and show it read-only.

Optional stage breakdown appears only if the user chooses "add stages"; otherwise
stages stay null, which means "not measured" rather than "zero".

## Meal entry

```dart
enum MealType { breakfast, lunch, dinner, snack }
```

Meal type defaults sensibly from the time of day (before 10:30 → breakfast, before
15:00 → lunch, before 21:00 → dinner, else snack) but is always editable.

Nutrition fields are optional. A user who only logs "coffee and a croissant"
should be able to save without inventing a calorie count. Invented numbers are
worse than missing ones.

## Subjective score

```dart
class ScoreSelector extends StatelessWidget {
  const ScoreSelector({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.scale = 5,
    this.descriptions = const {},
  });

  final String label;
  final int? value;
  final ValueChanged<int> onChanged;
  final int scale;
  final Map<int, String> descriptions;
}
```

Use a labelled row of selectable chips rather than a slider — a slider is hard to
hit precisely and impossible to read aloud. Each option gets a word: mood →
"Poor / Low / Okay / Good / Great". The description must be read by screen
readers.

Pain uses a 0–10 scale where 10 is worst. Keep it visually and semantically
separate from the 1–5 scales — do not put them in the same widget with a
different maximum.

## Deletion with undo

```dart
Future<void> _delete(BuildContext context, WidgetRef ref, String id) async {
  await ref.read(logRepositoryProvider).deleteWeight(id);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Entry deleted'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => ref.read(logRepositoryProvider).restoreWeight(id),
      ),
      duration: const Duration(seconds: 5),
    ),
  );
}
```

The restore path must work after the snackbar's duration expires too — "undo"
should not be a trick that silently fails.
