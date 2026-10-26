---
name: flutter-testing
description: Writes and runs tests for the Healthie Flutter app — unit tests for domain logic and unit conversion, widget tests for screens and forms, repository tests against an in-memory Drift database, Riverpod provider overrides, mocktail fakes, and on-device integration tests. This skill should be used whenever work adds logic that should be verified, when a bug is being reproduced as a failing test, when test infrastructure or fakes are needed, or when a change needs test coverage before it is considered done. Use it when implementing any feature, not only when the user explicitly asks for tests.
---

# Testing Healthie

A health app stores people's medical history. Bugs here are not cosmetic — a
dropped record, a mis-grouped day, or a silently rejected value destroys
trust in the whole app. Tests are how that is prevented.

## Pyramid

| Level | What | Speed | Share |
|---|---|---|---|
| **Unit** | Domain logic, unit conversion, validation, conflict rules, date grouping | ms | ~70% |
| **Widget** | Screens, forms, empty/loading/error states, provider wiring | ~100ms | ~25% |
| **Integration** | Real device flows: launch, log a value, grant permission | minutes | ~5% |

Push logic down. If a rule can be tested without a widget, it must be — a unit
test is faster and pinpoints the failure.

## The Rules That Matter Most

**Test the boundaries, not the happy path.** The happy path is what manual QA
already covers. The valuable tests are: DST boundaries, leap days, unit
conversion round-trips, empty datasets, single-element datasets, permission
denied, network failure, and a value exactly on a validation limit.

**Every test has one reason to fail.** A test asserting five things reports one
failure and hides four. Split them.

**Test names describe behaviour, not implementation.** `converts 78.4 kg to
172.7 lb` beats `test unit conversion 1`.

**No sleeps.** Use `pumpAndSettle()` for animations and `await` on real futures.
A test with `Future.delayed` is slow and flaky.

**No network, no real clock, no real device** in unit and widget tests.

## Domain Tests

Pure functions and rules are the easiest and highest-value tests.

```dart
group('Unit', () {
  test('converts kilograms to pounds', () {
    expect(Unit.kilogram.toCanonical(78.4, from: Unit.kilogram, to: Unit.pound),
        closeTo(172.7513, 0.0001));
  });

  test('round-trips through canonical units without drift', () {
    final canonical = Unit.kilogram.toCanonical(78.4,
        from: Unit.kilogram, to: Unit.canonicalWeight);
    final back = Unit.canonicalWeight.fromCanonical(canonical, to: Unit.pound);
    expect(back, closeTo(78.4, 0.0001));
  });

  test('rejects a weight outside the plausible range', () {
    expect(() => validateWeight(500), throwsA(isA<ValidationFailure>()));
  });
});
```

Test the **range boundaries explicitly**:

```dart
test('accepts the lower bound of weight', () { ... });   // 20 kg exactly
test('rejects just below the lower bound', () { ... });   // 19.9 kg
```

## Date and Timezone Tests

These catch the bugs that are invisible in manual testing. **Use a fixed
timezone** in every date test:

```dart
test('groups a 23:30 measurement into the local day', () {
  final at = DateTime(2026, 3, 10, 23, 30);
  expect(at.toLocalDay(), DateTime(2026, 3, 10));
});
```

Test the specific known-hard cases:

- A DST spring-forward day (a local day that is 23 hours long).
- A DST fall-back day (25 hours).
- A measurement at exactly midnight.
- A measurement at 23:59:59.
- A timezone change (the user flies from Berlin to New York).
- A leap day.

If the code uses `DateTime.now()`, inject a clock. **Never call `now()` inside a
model or a pure function** — it makes the function untestable and hides bugs.

## Repository Tests with Drift

Test repositories against a real in-memory database. It is faster and more
faithful than mocking Drift.

```dart
late AppDatabase db;
late LogRepositoryImpl repository;

setUp(() {
  db = AppDatabase.forTesting(NativeDatabase.memory());
  repository = LogRepositoryImpl(LogDao(db), SyncOutbox(db));
});

tearDown(() => db.close());
```

```dart
test('saves a measurement and emits it on the stream', () async {
  final emitted = <List<WeightEntry>>[];
  final sub = repository.watchWeight(range: _range).listen(emitted.add);

  await repository.saveWeight(_weight(value: 78.4));

  await pumpEventQueue();
  expect(emitted.last.single.valueKg, 78.4);
  await sub.cancel();
});
```

**Test the outbox too.** A repository test that does not assert an outbox row was
enqueued is missing the half of the contract that matters for sync:

```dart
expect(await db.outbox.countPending(), 1);
```

**Test migrations.** Drift's `stepByStep` helper migrates a snapshot schema
forward version by version:

```dart
test('migrates from schema v1 to current', () {
  await verifier.migrateAndValidate(db, from: 1, to: currentSchemaVersion);
});
```

Keep a schema snapshot per version. A migration that is never exercised against
real data is a migration that will fail in production, on a user's years of
history.

## Widget Tests

Use `ProviderScope` with overrides to inject fakes:

```dart
testWidgets('shows an empty state when there are no entries', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        logRepositoryProvider.overrideWithValue(FakeLogRepository(entries: [])),
      ],
      child: const MaterialApp(home: MetricsScreen()),
    ),
  );

  await tester.pumpAndSettle();

  expect(find.text('No entries yet'), findsOneWidget);
});
```

For every screen, test:

1. **Loading state** — a spinner, not a blank frame.
2. **Empty state** — explanatory text and a way to act.
3. **Populated state** — the real content renders.
4. **Error state** — a message and a retry.
5. **Interaction** — tapping the primary action calls the repository.

Use `find.text`, `find.byType`, and `find.byKey`. **Prefer `Key`s over
`find.text` for elements whose label might change** — a text-based finder
breaks the test every time a label is edited, which trains people to ignore
test failures.

## Mocktail Fakes

`mocktail` 1.0.5 — no codegen.

```dart
class MockMetricRepository extends Mock implements MetricRepository {}

class FakeHealthDataSource implements HealthDataSource {
  FakeHealthDataSource({this.points = const []});
  List<HealthDataPoint> points;
  bool grantPermissions = true;

  @override
  Future<bool> requestAuthorization(List<HealthDataType> types) async =>
      grantPermissions;

  @override
  Future<List<HealthDataPoint>> read(
    DateTimeRange range,
    List<HealthDataType> types,
  ) async => points;
}
```

Prefer a hand-written **fake** over a mock when the interface has a handful of
methods — fakes are easier to read and to keep correct. Use mocks for
interaction assertions ("was `save` called once with X?").

With `mocktail`, stub any member you stub; otherwise it throws. Register
fallbacks for common types:

```dart
setUpAll(() {
  registerFallbackValue(DateTimeRange(
    start: DateTime(2026, 1, 1),
    end: DateTime(2026, 1, 2),
  ));
});
```

## Integration Tests

`integration_test` for on-device flows. Keep them few and stable:

- The app launches and shows the dashboard.
- A value can be logged and appears in the list.
- The app survives a restart with the logged value intact.
- Health Connect permission denial degrades to manual entry without a crash.

Run on a real device or an emulator with a Google APIs image. **CI emulators
without Google APIs have no Health Connect**, so those flows must degrade
gracefully — which is worth testing anyway.

```bash
flutter test integration_test/ -d <device-id>
```

## What Must Be Tested in This App

Prioritise these — they are where real harm lives:

- [ ] Unit conversions, both directions, at boundary values.
- [ ] Local-day grouping across DST and across timezone changes.
- [ ] Validation ranges at their exact bounds.
- [ ] Tombstone-wins conflict resolution.
- [ ] Outbox compaction keeps a delete from being resurrected.
- [ ] Every database migration, from every prior version.
- [ ] Health Connect permission denied → manual entry still works.
- [ ] Health Connect unavailable → app still works.
- [ ] A write with no network → succeeds locally, queues, and later syncs.
- [ ] Deleting a record soft-deletes and can be undone.
- [ ] No secret or token is written to logs.

## Golden Tests

Use sparingly. Goldens break on every font-rendering or platform change, and a
team that learns to regenerate goldens without looking stops noticing real
visual regressions. Reserve them for a small number of genuinely stable
components, and review every diff.

## Commands

```bash
flutter test                       # all unit and widget tests
flutter test --coverage            # with coverage
flutter test test/features/metrics/
flutter test --plain-name "converts"
flutter test integration_test/ -d <device-id>
```

## Definition of Done

A change is done when:

1. New logic has unit tests at its boundaries.
2. New UI has widget tests for loading, empty, populated, and error states.
3. Repository changes assert the outbox behaviour.
4. Schema changes have a migration and a migration test.
5. `flutter test` passes and `flutter analyze` is clean.
