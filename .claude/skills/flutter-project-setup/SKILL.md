---
name: flutter-project-setup
description: Maintains the Healthie Flutter project's toolchain, pubspec dependency set, Android Gradle configuration, and build_runner code-generation pipeline. This skill should be used whenever work involves adding, upgrading, or removing a package; changing Android build configuration (minSdk, compileSdk, targetSdk, Gradle, Kotlin, AGP); configuring or repairing code generation (freezed, json_serializable, drift, riverpod_generator); adjusting analysis_options and lint rules; or scaffolding a new platform target. It should also be used whenever dependency resolution fails, when generated .g.dart / .freezed.dart / .drift.dart files are missing or stale, or when a build breaks on a dependency upgrade. Use it before any feature work that adds a package.
---

# Healthie Flutter Project Setup

Healthie is a Flutter mobile app for personal health tracking. Android is the primary
platform: it reads from Android Health Connect, accepts manual entry, and syncs to a
cloud backend. iOS is a supported target but ships **manual entry only** — the user
chose not to request Apple HealthKit access, so no HealthKit entitlement is wired up.

Everything in this skill is verified against pub.dev on 2026-10-22. Versions move
frequently; when a version is called out as "verified", re-check pub.dev before
assuming it is still current.

## Toolchain Baseline

The dependency set below imposes these floors:

| Requirement | Floor | Why |
|---|---|---|
| Dart SDK | `^3.13.0` | `freezed` 4.0.3 |
| Flutter SDK | `>=3.47.0` | `google_fonts` 9.0.0 |

Always confirm the installed toolchain before changing anything:

```
flutter --version
dart --version
```

If the installed SDK is below a floor, upgrading Flutter is a prerequisite — do not
downgrade a package to work around a stale SDK. Note that `flutter upgrade` moves
between channels, not versions; use `flutter upgrade --force` carefully and confirm
the target version first.

## Verified Dependency Set

All versions verified on pub.dev 2026-10-22. Pin these in `pubspec.yaml` with
caret constraints, and let `pub outdated` drive upgrades rather than ad-hoc edits.

### Core

| Package | Version | Notes |
|---|---|---|
| `flutter_riverpod` | 3.4.3 | Riverpod 3.x is stable. `riverpod_annotation` 4.0.7, `riverpod_generator` 4.0.9 |
| `go_router` | 18.1.1 | Requires Dart `^3.12.0`, Flutter `>=3.44.0` |
| `freezed` / `freezed_annotation` | 4.0.3 / 3.1.0 | Immutable models with `copyWith`, `==` |
| `json_serializable` | 6.15.2 | Pairs with `build_runner` 2.17.1 |
| `build_runner` | 2.17.1 | Dev dependency |

### Storage

| Package | Version | Notes |
|---|---|---|
| `drift` | 2.35.2 | Reactive SQLite ORM |
| `drift_dev` | 2.35.1 | Generator; stays in lockstep with `drift` |
| `drift_flutter` | 0.3.1 | Cross-platform drift helpers |
| `sqlite3` | 3.7.1 | **Do not add `sqlite3_flutter_libs`** — it is EOL |

`sqlite3_flutter_libs` reached `0.6.0+eol` with the description "Not used anymore,
update to version 3.x of package:sqlite3 instead". The `sqlite3` 3.x line ships the
native library through the native-assets toolchain (`code_assets`,
`native_toolchain_c`, `hooks`), so no separate plugin dependency is required. Adding
`sqlite3_flutter_libs` to a new project is a mistake — flag it if found.

### Health Connect

| Package | Version | Notes |
|---|---|---|
| `health` | 13.3.2 | CARP's package: HealthKit (iOS) **and** Health Connect (Android) |

Two other Health Connect packages exist and are both **dead** — do not use them:
`health_connect` (0.0.0, Jan 2023) and `flutter_health_connect` (1.2.3, Mar 2023).

### Charts, formatting, assets

| Package | Version | Notes |
|---|---|---|
| `fl_chart` | 1.2.0 | Line/Bar/Pie/Scatter/Radar |
| `flutter_svg` | 2.3.0 | Now on the `vector_graphics` family |
| `google_fonts` | 9.0.0 | Requires Flutter `>=3.47.0` |
| `intl` | 0.20.3 | Date/number formatting |
| `path_provider` | 2.1.6 | App directories for the SQLite file |

### Backend & background

| Package | Version | Notes |
|---|---|---|
| `supabase_flutter` | 2.18.3 | Auth + Postgres |
| `supabase` | 2.16.5 | Pinned transitively |
| `connectivity_plus` | 7.3.2 | Network state |
| `workmanager` | 0.10.10 | Android background tasks |

### Dev

| Package | Version | Notes |
|---|---|---|
| `flutter_lints` | 6.0.0 | Recommended lint set, Dart `^3.8.0` |
| `mocktail` | 1.0.5 | Mocking, no codegen |
| `integration_test` | 1.0.2+3 | SDK-bundled; listed as discontinued on pub.dev but still the supported way to run on-device tests |

## Android Configuration

Health Connect requires **minSdk 28** (Android 9 Pie) and the stable
`androidx.health.connect:connect-client:1.1.0` library.

In `android/app/build.gradle.kts`:

```kotlin
android {
    defaultConfig {
        minSdk = 28
        targetSdk = 35
        compileSdk = 35
    }
}
```

Use the versions the current Flutter template ships with for AGP, Gradle, and Kotlin.
Do not downgrade them — Flutter's Gradle plugin has tight coupling to AGP and Kotlin
versions. When a Gradle error mentions AGP/Kotlin compatibility, fix the AGP/Kotlin
version rather than the plugin.

## Code Generation

Four generators run under one `build_runner` invocation:

- `freezed` — immutable model classes
- `json_serializable` — `fromJson`/`toJson`
- `drift_dev` — database schema and query helpers
- `riverpod_generator` — only if using `@riverpod` annotations

Run generation after any change to an annotated class:

```
dart run build_runner build --delete-conflicting-outputs
```

`--delete-conflicting-outputs` is mandatory in this project: stale generated files
from a renamed or deleted class otherwise linger and produce phantom errors.

Regenerate **before** reading compiler errors. Most "cannot resolve X" errors after
an annotation change are stale codegen, not real type errors. Generated files
(`*.g.dart`, `*.freezed.dart`, `*.drift.dart`) are build artifacts — never hand-edit
them, and never fix a type error by weakening the source model to satisfy the
generator.

## Linting and Analysis

`analysis_options.yaml` should include `package:flutter_lints/flutter.yaml` plus the
project's own rules. Keep the analyzer strict: `flutter analyze` must return zero
issues before any commit. Treat analyzer output as a build failure, not a suggestion.

Do not add blanket `// ignore:` comments. If a lint is genuinely wrong for a case,
disable it narrowly with a reason at the narrowest scope that works.

## Dependency Discipline

- Run `flutter pub add <pkg>` rather than hand-editing `pubspec.yaml` — it resolves
  compatible versions and updates the lockfile.
- Never edit `pubspec.lock` by hand.
- Before adding a package, check pub.dev for its maintenance status and last publish
  date. A package with no release in 12+ months is a liability in a health app that
  must keep working against OS API changes.
- Prefer the smallest dependency that solves the problem. This project already
  covers state, routing, persistence, networking, charts, and health data.

## Project Layout

Healthie uses a feature-first layout, not a layer-first one. See
`flutter-architecture` for the full structure and the rules that go with it.

```
lib/
  app/            # bootstrap, routing, theme wiring
  core/           # cross-cutting: database, auth, sync, errors, constants
  features/
    <feature>/
      data/       # drift tables, DAO, repository impl
      domain/     # models, repository interfaces, use cases
      presentation/ # widgets, screens, providers
  shared/         # reusable widgets, formatters, form components
```

## Verification Checklist

Before declaring setup work done:

1. `flutter pub get` completes with no resolution conflicts.
2. `dart run build_runner build --delete-conflicting-outputs` completes clean.
3. `flutter analyze` reports zero issues.
4. `flutter test` passes.
5. `flutter build apk --debug` succeeds.
6. `pubspec.yaml` contains no EOL packages (`sqlite3_flutter_libs` in particular).

## Reference Files

- `references/dependency-matrix.md` — full package table with publish dates and
  maintainer status, plus known-deprecated alternatives to avoid.
- `references/android-build.md` — Gradle/AGP/Kotlin setup, manifest merge rules,
  ProGuard configuration for release builds, and the Health Connect manifest block.
