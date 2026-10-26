---
name: health-connect-android
description: Integrates Android Health Connect into Healthie using the `health` package — permission flow, availability handling, reading steps/heart rate/sleep/workouts, mapping records into the domain model, background sync, and manifest configuration. This skill should be used whenever work involves Health Connect, reading wearable or step data, requesting health permissions, the permissions rationale screen, importing data from the Health Connect app, or adding a new Health Connect data type. Use it before writing any code that calls the `health` package, and whenever a Health Connect call fails or returns nothing.
---

# Android Health Connect Integration

Healthie reads steps, heart rate, sleep, and workouts from Health Connect as a
**second data source** alongside manual entry. It never writes Healthie's own
records back into Health Connect.

## Package and API Version — Read This First

Use **`health` 13.3.2** (`carp-dk/carp-health-flutter`). Its API was rewritten in
the 13.x line. Most tutorials, Stack Overflow answers, and blog posts on the
internet describe the **older v10 API and are wrong for this version.**

| Older v10 API (do not use) | Current v13 API |
|---|---|
| `HealthFactory(useHealthConnectIfAvailable: true)` | `Health()` then `await health.configure()` |
| `health.requestPermissions(List<HealthPermission>)` | `await health.requestAuthorization(types, permissions: [...])` |
| `health.getGrantedPermissions()` | `await health.hasPermissions(...)` / `revokePermissions(...)` |
| `HealthPermission.READ_STEPS` | `HealthDataAccess.READ` / `HealthDataAccess.READ_WRITE` |
| `health.write(HealthDataPoint(...))` | `await health.writeHealthData(value, type, start, end, ...)` |
| `HealthDataType.STEPS_COUNTER` | `HealthDataType.STEPS` |

When in doubt, read the installed package source rather than trusting recall:

```
<pub-cache>/hosted/pub.dev/health-13.3.2/lib/
```

The API reference is at `https://pub.dev/documentation/health/latest/`.

## Core Usage

```dart
final health = Health();
await health.configure();
```

`configure()` must complete before any other call. Do it once at app start, in
`main()` before `runApp`, and inject the ready instance via a Riverpod provider.
Calling `configure()` per-use is wasteful and, on some versions, racy.

### Permission flow

```dart
const types = [
  HealthDataType.STEPS,
  HealthDataType.HEART_RATE,
  HealthDataType.SLEEP_SESSION,
  HealthDataType.WORKOUT,
];

final granted = await health.requestAuthorization(
  types,
  permissions: const [HealthDataAccess.READ],
);
```

- `HealthDataAccess.READ` is sufficient. Healthie does **not** write to Health
  Connect, so do not request `READ_WRITE` — requesting write access for data the
  app never writes is a Play policy problem, not just a permissions nuisance.
- Only request the types the app actually displays. Each extra type is a Play
  Store permissions-justification item.
- `hasPermissions(...)` returns the currently granted types — call it at start-up
  to restore the permission state rather than assuming.
- The rationale screen (see `references/android-setup.md`) is required by Health
  Connect: the system launches it when a user denies a permission, and it must
  explain why the data was wanted.

### Reading data

```dart
final points = await health.getHealthDataFromTypes(
  startTime: start,
  endTime: end,
  types: const [HealthDataType.STEPS, HealthDataType.HEART_RATE],
);
```

The parameters are `startTime`, `endTime`, `types`, and an optional
`recordingMethodsToFilter`.

For step totals specifically:

```dart
final steps = await health.getTotalStepsInInterval(dayStart, dayEnd);
```

**Use `getTotalStepsInInterval` for daily step totals**, not a hand-rolled sum of
`STEPS` points. Health Connect returns step counts as *incremental* samples with
overlapping windows; summing them double-counts. The dedicated call handles the
aggregation correctly.

Filter by recording method when it matters:

```dart
recordingMethodsToFilter: const [RecordingMethod.manual, RecordingMethod.unknown],
```

`RecordingMethod` values: `automatic`, `manual`, `active`, `unknown`. iOS
supports only `automatic` and `manual`; Android supports all four.

### Reading sleep and workouts

Sleep and workouts arrive as **session** records, not scalars:

- `HealthDataType.SLEEP_SESSION` — a sleep period with optional stage breakdown.
- `HealthDataType.SLEEP_DEEP`, `SLEEP_REM`, `SLEEP_LIGHT`, `SLEEP_ASLEEP`,
  `SLEEP_AWAKE`, `SLEEP_IN_BED` — per-stage durations.
- `HealthDataType.WORKOUT` — an activity session. `WORKOUT_ROUTE` carries the GPS
  track (needs extra permissions and `ACCESS_FINE_LOCATION`; skip it unless the
  app shows a map).

Map a `SLEEP_SESSION` to a Healthie `SleepSession`. Derive `sleep_duration` as a
separate derived measurement. **Do not fabricate stage values** when the source
omits them — leave them null.

Map a `WORKOUT` to a Healthie `Workout` (see the metric catalog for the field
mapping). Keep the original Health Connect activity-type string in
`sourceMetadata` so nothing is lost in translation.

### Writing (not used in Healthie)

The API is `await health.writeHealthData(value, type, start, end, recordingMethod: ...)`.
Healthie does not call this — writing a manual entry back into Health Connect
would duplicate data in the user's own Health app and violates Play policy.

## Mapping Health Connect → Domain

The mapping belongs in the **data layer** (`features/health_connect/data/`), never
in a widget. The repository returns domain objects indistinguishable from manual
entries, so the rest of the app never learns where a record came from — that is
the whole point of the repository boundary.

Rules for the mapping:

1. **Convert units on the way in.** Health Connect reports distance in metres,
   energy in kilocalories, duration in seconds. Healthie stores the same
   canonical units, so most conversions are identity — but verify per type.
2. **Use the record's own timestamp as `recordedAt`.** Health Connect records are
   in the past; using the import time would wreck every trend.
3. **Set `source` to `healthConnect`.** Never `manual`.
4. **Compute `localDay` from `recordedAt`**, using the device timezone.
5. **Deduplicate on import.** Re-importing the same Health Connect window must not
   create duplicate records. Use the Health Connect record's own identifier where
   available, stored in `sourceMetadata`, and check for it before inserting.
6. **Never overwrite a manual record with a Health Connect one** for the same
   moment. Healthie's own records are authoritative.

## Availability and Failure States

Health Connect availability is not a binary yes/no. Handle each state explicitly,
as a first-class UI state rather than an error:

| State | Cause | What to show |
|---|---|---|
| Available and authorized | Normal | Read data |
| Available, not authorized | User has not granted | Permission prompt with rationale |
| Available, denied permanently | User denied twice / "don't ask again" | Link to system Health Connect settings |
| Not installed (Android 13 and below) | Separate app not installed | Install prompt |
| Not available on device | Device unsupported | Manual entry only, no error |
| Permission revoked externally | User changed it in system settings | Re-prompt on next entry point |

Health Connect ships **inside Android 14+** and as a **separate app** on Android 13
and below. The plugin's `configure()` performs the provider check; on Android 13
and below the user may need to install it from Play.

Never let an unavailable Health Connect surface as a crash or a blank screen.
Manual entry is always available — that is the app's primary input path and it
must work with zero health permissions granted.

## Background Import

Optional, and worth doing only after the foreground flow is solid.

- Health Connect background read requires the separate permission
  `android.permission.health.READ_HEALTH_DATA_IN_BACKGROUND`, which must be
  granted while the app is in the foreground at least once.
- `await health.isHealthDataInBackgroundAvailable()` reports whether it is usable.
- Schedule the periodic job with `workmanager` (0.10.10). The callback runs in a
  background isolate: it cannot touch the app's Riverpod container, and it must
  open its own database connection rather than reuse the app's.
- Keep the background job's work small. Read only the recent window (the last day
  or two), write to the local DB, and let the normal sync path upload it.
- `workmanager` requires the app's `MainActivity` to be declared in the manifest
  in the way the plugin's own docs specify.

## Testing Health Connect

Health Connect cannot be exercised in a unit test. Structure the code so the
Health Connect client sits behind an interface:

```dart
abstract interface class HealthDataSource {
  Future<bool> requestAuthorization(List<HealthDataType> types);
  Future<List<HealthDataPoint>> read(DateTimeRange range, List<HealthDataType> types);
}
```

Then:

- **Unit tests** use a fake implementation. No plugin mocking required.
- **Instrumented tests** on a device or emulator with Health Connect installed
  can exercise the real plugin, but they are slow and flaky in CI — keep them to
  a small smoke suite.
- **Never assert on Health Connect's exact data.** The platform's behaviour
  differs across OEM skins. Assert on the *mapping* from Health Connect records
  to domain objects using synthetic `HealthDataPoint`s.

## Manifest and Platform Setup

See `references/android-setup.md` for the exact `AndroidManifest.xml` block, the
rationale activity, the `FlutterFragmentActivity` requirement, and the extra
permissions for background read and history.

## Reference Files

- `references/android-setup.md` — manifest XML, activity configuration, extra
  permissions, and the `gradle.properties` values the plugin needs.
