# Healthie

**Your health. Your data. Your insights.**

A personal health tracker and longitudinal analytics app for Android and iOS.
Healthie records blood pressure, body weight, and other vitals, and turns the
stored readings into charts, statistics, trends, and explainable observations.

It is a **tracker, not a medical device**. It screens readings against a named
clinical guideline; it does not diagnose, and it does not replace professional
medical advice.

---

## Status

This repository contains a working, tested Flutter application. The table
below is the honest state of each area — read it before assuming a feature
exists.

| Area | State |
|---|---|
| Local-first persistence (Drift), soft deletes, outbox | **Done** |
| Design system, light + dark themes, Inter typography | **Done** |
| Navigation shell, five tabs, quick-log sheet | **Done** |
| Blood-pressure entry, AHA/ACC 2017 classification, safety guard | **Done** |
| Body-weight entry, kg/lb toggle, body composition | **Done** |
| History: search, filter, grouped timeline, edit, delete + undo | **Done** |
| Analytics engine: statistics, Theil–Sen trends, moving averages, insights | **Done** |
| Blood-pressure analytics: charts, guideline distribution, circadian | **Done** |
| Weight analytics: charts, period performance, goal progress | **Done** |
| Profile: name, units, clinician targets, reminders | **Done** |
| CSV export | **Preview only** — the CSV is rendered in a dialog, not written to a file |
| PDF export | **Not implemented** — the button explains this |
| Local notifications for reminders | **Not implemented** — schedules are stored and displayed, but nothing is scheduled with the OS |
| Android Health Connect import | **Not implemented** — see [Future work](#future-work) |
| Cloud sync / backend | **Not implemented** — the outbox is built and ready; see [API contract](docs/api-contract.md) |
| Release signing, app icons, splash | **Not implemented** — a debug APK builds |

---

## Getting started

### Requirements

| Tool | Version |
|---|---|
| Flutter SDK | 3.47.7 (Dart 3.13.5) |
| Android Studio / Android SDK | API 35 toolchain |
| Xcode | For iOS builds |

> The project pins Dart `^3.13.5`, which is the floor set by `freezed` 4.x.
> On an older Flutter, run `flutter upgrade` — do not downgrade the packages
> to work around a stale SDK.

### Run it

```bash
flutter pub get
dart run build_runner build          # drift + freezed code generation
flutter run
```

### Verify it

```bash
flutter analyze                      # must report no issues
flutter test                         # must pass
dart run tool/check_layering.dart    # must report no violations
flutter build apk --debug            # produces build/app/outputs/flutter-apk/app-debug.apk
```

`build_runner` must be re-run after any change to a `@freezed` or Drift
annotated class. Generated files (`*.g.dart`, `*.freezed.dart`) are build
artifacts: never edit them by hand.

---

## How it works

### Offline-first

The local Drift database is the source of truth. A reading is written to the
database and to the sync outbox **in the same transaction**, so the write is
durable and the UI reflects it immediately. The network is never on the
critical path of a user-visible write — logging your blood pressure on a
train with no signal is instant.

Deletes are soft. The row is tombstoned, so a deletion can sync and can be
undone from the snackbar for a few seconds afterwards.

### Layers

```
presentation  ->  domain  <-  data
```

- **presentation** — widgets, screens, Riverpod providers. Knows domain
  interfaces only.
- **domain** — models, repository interfaces, the analytics engine, the
  guideline. Pure: no Drift, no Supabase, no Riverpod.
- **data** — Drift tables, DAOs, repository implementations.
- **`lib/app/providers.dart`** — the composition root. The only place that
  wires concrete implementations to abstractions.

`tool/check_layering.dart` enforces this. It fails the build on a violation.

### Where things live

```
lib/
  app/            bootstrap, routing, theme, composition root
  core/           database, sync outbox, units, date helpers, errors
  features/
    analytics/    statistics, trends, insights, charts
    blood_pressure/  entry screen
    dashboard/    home screen
    history/      audit trail
    metrics/      the measurement model, storage, and providers
    profile/      profile and goals
    reminders/    reminder schedules
    track/        metric hub
    weight/       entry screen
  shared/         reusable widgets, form toolkit, formatters
tool/             the layering check
docs/             architecture, analytics, privacy, API contract, ADRs
```

---

## Documentation

| Document | What it covers |
|---|---|
| [Architecture](docs/architecture.md) | Layers, data flow, the storage schema, sync design |
| [Analytics](docs/analytics.md) | Every calculation, its method, and its denominator |
| [Privacy and security](docs/privacy-and-security.md) | What leaves the device, and what does not |
| [API contract](docs/api-contract.md) | The REST contract the backend will implement |
| [Future work](docs/future-enhancements.md) | Prioritised next steps |
| [Decisions](docs/adr/) | Architecture decision records |

---

## Privacy

- All health data is stored on the device in a local SQLite database.
- Nothing is transmitted anywhere. There is no analytics SDK, no advertising
  SDK, and no crash reporting.
- The app makes no network requests at all in its current state.
- Inter is bundled with the app rather than downloaded at runtime, so even
  the typeface does not require a network call.

---

## Licence

Private project. All rights reserved.
