---
name: flutter-debugging
description: Diagnoses failures in the Healthie Flutter app — build and Gradle errors, layout overflow, crashes and exceptions, async and state errors, blank or frozen screens, slow or janky performance, database and migration failures, Health Connect calls that return nothing, and bugs that only appear in release builds. This skill should be used whenever something is broken, throwing, crashing, rendering wrong, running slowly, or behaving differently in a release build, and whenever a bug report needs to be reproduced and isolated. Use it instead of guessing at fixes.
---

# Debugging Healthie

## The Method

Debugging is **elimination, not guessing**. A patch that fixes the symptom
without identifying the cause is a delay, not a fix.

1. **Reproduce it reliably.** If it cannot be reproduced, it cannot be verified
   fixed. Note the exact steps, the device, the OS version, and whether it
   happens in debug or release.
2. **Read the actual error.** The full stack trace and the first frame in *your*
   code — not the last frame in a framework file. Most Flutter errors point at a
   widget that *built* correctly but received bad data from a parent.
3. **Localise it.** Narrow to a layer: UI, state, repository, database, or
   platform plugin. Bisect by replacing the suspect piece with a stub.
4. **Form one hypothesis. Predict what you expect to see. Test it.** A change
   that does not test the hypothesis teaches you nothing.
5. **Fix the cause, then add a test that fails without the fix.**

Never stack speculative fixes. If two changes are applied and the symptom
disappears, you do not know which one mattered, and you have left a latent bug
and possibly a new one.

## First Moves

```bash
flutter analyze                 # static errors the compiler cannot see
flutter run -d <device>         # with a debugger attached
flutter logs                    # device logs
flutter run --profile           # performance-mode build, with realistic rendering
flutter test                    # does it fail in a test?
```

`flutter analyze` first, every time. Many "runtime mysteries" are static errors
in widgets that are never built in the current route.

For a Flutter framework-level problem, set `flutter run` with `--verbose` and
read the first error, not the last.

## Common Failures

### RenderFlex overflowed by N pixels

A `Row` or `Column` has more content than the space it was given.

**Fix the layout, not the font size.** Shrinking text to hide an overflow makes
the UI worse at every other text scale.

Common causes and real fixes:

- **Unbounded text in a `Row`.** Wrap the flexible part in `Expanded` or
  `Flexible`.
- **A `ListView` inside a `Column`** without `shrinkWrap: true` and a bounded
  height — or better, use `Expanded` so it takes the remaining space.
- **Fixed-height containers** holding variable content. Let them size naturally
  or use `IntrinsicHeight` where a fixed height is genuinely needed.
- **Long user text** (a meal name, a note). Use `TextOverflow.ellipsis`, or
  `maxLines` with a fade — and test with a long string.

Reproduce at a large text scale: `flutter run` then change the device font size
to maximum, or set `MediaQuery.textScaler` in a test.

### "setState() called after dispose()"

An async gap outlives the widget. The pattern to use:

```dart
if (!mounted) return;
// ... then setState
```

Better: use `mounted` checks in `ConsumerState`, or move the async work into a
Riverpod provider where the widget's lifetime does not matter.

### "setState() or markNeedsBuild() called during build"

Something notifies a listener during the build phase. Move the notification to
after the frame (`WidgetsBinding.instance.addPostFrameCallback`) or into a
provider so it happens outside the build.

### A blank or frozen screen

Work down the tree:

1. Is the route even reached? Add a print in `build`.
2. Is the provider producing a value, or stuck in `AsyncLoading`?
3. Is the stream emitting? Check the repository, then the DAO, then the query.
4. Is the widget rendering but invisible (a zero-size box, an off-screen
   position, a transparent colour)?

A `StreamProvider` that never emits leaves the UI in `AsyncLoading` forever.
Confirm the underlying Drift query is a `watch()` and not a one-shot `get()`.

### The database errors or the data disappears

- **`SqliteException: no such table`** — the migration did not run, or
  `onCreate` did not create the table. Check `schemaVersion` and `onUpgrade`.
- **`DatabaseException: column X does not exist`** — the generated code is
  stale. Run `dart run build_runner build --delete-conflicting-outputs`.
- **The app opens a different file in debug and release.** The database path
  comes from `path_provider`; if the path logic differs, the app silently reads
  an empty database. Log the absolute path in both builds and compare.
- **`SQLITE_BUSY`** — two connections to the same file. In debug, Drift's
  `NativeDatabase` on a background isolate can conflict with the main connection.
  Use a single connection in development.

### Health Connect returns nothing

Work through this list in order — it is nearly always one of the first three:

1. **Is Health Connect available on this device?** Android 13 and below need the
   separate app installed. The `<queries>` block must be present or package
   visibility hides it.
2. **Is the permission granted?** Call `hasPermissions(...)` and log the result.
   A permission denied silently produces an empty result, not an error.
3. **Is the time range wrong?** Health Connect returns points in the *device's*
   timezone. A range built from UTC midnight can exclude everything.
4. **Is the recording method filtered out?** `recordingMethodsToFilter` that
   excludes the method the data was recorded with yields nothing.
5. **Is the data type right?** `STEPS` vs `STEPS_COUNTER`; the enum names
   changed in the `health` package's 13.x rewrite.

### It only crashes in release

The usual causes, in order of likelihood:

- **R8/ProGuard stripped a class.** Add a `-keep` rule. Check
  `android/app/proguard-rules.pro` and rebuild.
- **A tree-shaken icon or asset** missing at release.
- **Missing ProGuard rules for a plugin** — the `health` plugin and Flutter's
  embedding both need keep rules.
- **`assert()` stripped.** Release builds drop asserts, so a bug that only
  appeared inside an assert now appears as a real crash.
- **Obfuscation.** Build with `--split-debug-info` so the stack trace can be
  de-obfuscated. A release stack trace with obfuscated names is nearly
  useless — configure symbol upload at build time.

### It is slow or janky

Profile before optimising.

```bash
flutter run --profile
```

Open DevTools → Performance, and record the interaction that stutters. Look for:

- **Long builds.** A `build()` that does real work will drop frames. Move it to
  an isolate (`compute()`) or to a background query.
- **Unnecessary rebuilds.** A `watch` on a provider that changes often rebuilds
  its consumers. Narrow the watched value.
- **`ListView` with all children built.** Use `ListView.builder`.
- **Chart data re-aggregated on every frame.** Aggregate once and cache.
- **Synchronous SQLite on the UI isolate.** Drift queries should be reactive
  and asynchronous; a `get()` that runs on the main isolate will stutter.
- **Images not cached.** Use `cacheWidth` when displaying large images.

Check for memory growth: a `StreamProvider` that is never disposed keeps its
database subscription alive. Use `autoDispose` for screen-scoped providers.

## Isolation Techniques

- **Replace with a stub.** Swap the repository for a fake returning one known
  value. If the bug disappears, the bug is upstream.
- **Bisect the route.** Comment out half the widget tree. The error usually
  becomes obvious.
- **Bisect the data.** Print the actual values flowing through the suspect
  point. Health-data bugs are frequently a unit or a timezone, and the numbers
  make that visible immediately.
- **Check the boundary.** Where does the value change? Log the value on both
  sides of each conversion, each mapping, and each query.

## Logging Discipline

- Use `dart:developer`'s `log()` rather than `print` in library code — it
  respects log levels and is strippable in release.
- **Never log health values or credentials in production.** Debug logging of
  body measurements is a privacy leak in a shipped app. Gate verbose logging
  behind `kDebugMode` and check the redaction before shipping.
- Prefer structured context: include the metric type and the record id, not the
  raw values.

## Health-Specific Bugs to Recognise

| Symptom | Likely cause |
|---|---|
| Steps for "today" are half of yesterday's | UTC vs local day boundary |
| A weight appears on the wrong date after travel | Recomputing local day instead of storing it |
| Sleep is 0 hours but the user logged 7 | Stage data missing and coerced to 0 instead of null |
| A record reappears after being deleted | Tombstone lost to an outbox compaction |
| Two devices show different values, permanently | Conflict tiebreak not deterministic |
| Values double after a unit switch | Value reinterpreted instead of converted |
| Health Connect data is empty on a fresh device | Permission denied, silently swallowed |
| The app is empty after a reinstall | Database path differs between builds |

## Definition of Done

A bug is fixed when:

1. It is reproduced by a failing test.
2. The cause is identified and explained, not just the symptom suppressed.
3. The fix addresses the cause.
4. The test passes with the fix and fails without it.
5. `flutter analyze` is clean and the full suite passes.
