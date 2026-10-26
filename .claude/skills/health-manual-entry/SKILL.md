---
name: health-manual-entry
description: Builds and refines Healthie's manual data-entry flows — logging forms for weight, meals, workouts, sleep, vitals, water, and subjective scores; unit switching between metric and imperial; numeric input handling, validation, and error messaging; quick-entry affordances; and editing or deleting existing records. This skill should be used whenever work involves a form, a text field for a health value, a date or time picker, unit conversion in the UI, validation or error messages on entry, or adding support for a new manually entered metric. Use it before building any entry screen.
---

# Manual Entry

Manual entry is Healthie's **primary** input path. The user must be able to log
everything the app tracks without granting a single health permission. If a
feature only works through Health Connect, it is not finished.

## Entry Principles

**Fast for the common case.** Logging weight should take two taps: open, confirm
the last value. Pre-fill from the most recent record of the same metric and let
the user adjust. Offer a "save and add another" path for logging several meals.

**Explicit about time.** Every measurement has a timestamp. Default to "now" but
make it editable — logging a meal from lunch at 9pm is normal.

**Never lose input.** If validation fails, the entered values stay. If a save
fails, the form keeps its contents. A health app that clears a form on error
teaches the user to distrust it.

**Never silently coerce.** If a value is out of range, say so. Do not clamp. Do
not round a value the user typed without telling them.

## Form Structure

Every entry form follows the same anatomy:

1. **Metric selector** — what is being logged.
2. **Value input** — the number, with the unit visible next to the field.
3. **Time input** — when, defaulting to now.
4. **Optional context** — a note, a tag, a meal type. Never more than three
   optional fields; more and people stop filling things in.
5. **Save** — one primary action.

Build a shared `shared/form/` toolkit so every metric's form looks and behaves
the same: consistent field spacing, the same save-button treatment, the same
error styling, the same unit-suffix control.

## Numeric Input

Use a numeric keyboard with a decimal separator:

```dart
TextFormField(
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  inputFormatters: [
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
  ],
  ...
)
```

Issues to handle explicitly:

- **Locale decimal separators.** In much of the world the separator is `,` not
  `.`. Parse with `intl`'s `NumberFormat` rather than `double.parse` on raw
  input. A form that rejects `78,4` is broken for a large part of the world.
- **Trailing separators.** Allow `78.` while typing, normalise on submit.
- **Thousands separators.** Accept `1,200` and `1.200` on input; strip them on
  parse. Do not display them in the input field itself — it fights the cursor.
- **Decimals differ by metric.** Weight wants 1 decimal; heart rate wants 0;
  calories want 0; body fat wants 1. Drive precision from the metric catalog, not
  from a global constant.
- **The unit is part of the input.** If the user has set kg, the field shows `kg`
  next to it. Changing the unit in settings changes what the field means — and
  the value must be converted, not reinterpreted.

## Unit Switching

The unit control sits next to the value field, not buried in settings for this
form. Switching kg → lb **converts the current value in place** — the user is
looking at 78.4 kg, taps lb, and sees 172.7 lb. Leaving the number unchanged
while changing the label is a data-corruption bug.

Store canonically (kg), convert on save. See the `health-domain-model` skill for
the canonical unit per metric.

A shared `UnitToggle` widget should render available units for a metric type,
convert the current value, and notify the parent.

## Validation

Validate at two points:

- **On blur** — show an error without blocking the user mid-typing.
- **On submit** — hard-stop with a clear message and focus the offending field.

Error messages must be specific and actionable:

| Instead of | Write |
|---|---|
| "Invalid value" | "Enter a weight between 20 and 400 kg" |
| "Invalid date" | "That date is in the future" |
| "Error saving" | "Couldn't save your entry. Your data is still here — try again." |

Do not leak internal error strings (`SQLiteException: UNIQUE constraint failed`)
into the UI. Map `AppFailure` types to user-facing copy in the presentation layer.

## Editing and Deleting

- **Editing preserves `recordedAt`.** Changing the time in an edit form changes
  `recordedAt` only if the user explicitly changed the time. Fixing a typo in
  the value must not move the measurement to today.
- **Deletion is soft.** Set `deletedAt` and enqueue a sync operation. Let the user
  undo for a few seconds via a snackbar with an action — a mis-tap delete of a
  year of history is unrecoverable otherwise.
- **Editing a Health Connect-sourced record**: Healthie's own edit wins for the
  record itself, but the Health Connect original still exists in the platform.
  Do not write the edit back to Health Connect.

## Reusable Form Components

Build these once in `shared/form/`:

- `NumericField` — numeric keyboard, locale-aware parsing, precision control.
- `UnitToggle` — segmented control for the metric's entry units.
- `DateTimeSelector` — date + time pickers, with "now" as the default.
- `SaveButton` — consistent primary action with a loading state that disables
  double-submit.
- `EntrySheet` — the standard bottom-sheet scaffold for a log entry, so every
  metric's entry appears from the same place.

## Accessibility

- Every field has a label associated with the input, not just a placeholder.
  Placeholders disappear once the user types.
- The unit is announced with the value ("78.4 kilograms"), not visually only.
- Touch targets are at least 48dp.
- Validation errors are announced to screen readers.
- Score scales (mood, energy, pain) use labelled selectable options, not bare
  numbers — a screen reader user cannot infer what "3" means.

## Verification Checklist

- [ ] Logging works with zero health permissions granted.
- [ ] Values save with the correct canonical unit and display in the user's unit.
- [ ] Switching units mid-form converts the current value.
- [ ] A decimal-comma locale parses correctly.
- [ ] Out-of-range input is rejected with a specific message, and the input is
      preserved.
- [ ] Saving twice does not create two records (disable the button while saving).
- [ ] Editing preserves the original timestamp unless time was changed.
- [ ] Deleting is undoable for a few seconds and syncs as a tombstone.
- [ ] Keyboard types are numeric on value fields.
- [ ] The form survives a failed save without losing input.

## Reference Files

- `references/entry-patterns.md` — complete form implementations for weight,
  blood pressure, sleep, a meal, and a subjective score, plus the shared widget
  toolkit.
