# Healthie Dependency Matrix

Verified against pub.dev on **2026-10-22**. Re-verify before relying on any specific
version — this table is a starting point, not a live feed.

## Recommended

| Package | Latest stable | Published | SDK floor | Status | Verdict |
|---|---|---|---|---|---|
| `flutter_riverpod` | 3.4.3 | 2026-09-03 | Dart `^3.12.0` | Active (Riverpod org) | Use. Riverpod 3 stable. |
| `riverpod_annotation` | 4.0.7 | 2026-09-03 | Dart `^3.12.0` | Active | Use with the generator. |
| `riverpod_generator` | 4.0.9 | 2026-09-03 | Dart `^3.12.0` | Active | Use. |
| `go_router` | 18.1.1 | 2026-10-20 | Dart `^3.12.0`, Flutter `>=3.44.0` | Active (flutter/packages) | Use. |
| `freezed` | 4.0.3 | 2026-10-17 | Dart `^3.13.0` | Active | Use. Pins `freezed_annotation` 3.1.0. |
| `freezed_annotation` | 3.1.0 | 2026-10-17 | Dart `^3.13.0` | Active | Use. |
| `json_serializable` | 6.15.2 | 2026-10-20 | Dart `^3.12.0` | Active | Use. |
| `json_annotation` | `^4.12.0` | — | — | Active | Transitive. |
| `build_runner` | 2.17.1 | 2026-10-14 | Dart `^3.11.0` | Active | Use. |
| `drift` | 2.35.2 | 2026-10-07 | Dart `>=3.10.0` | Active (simolus3) | Use. Reactive queries. |
| `drift_dev` | 2.35.1 | 2026-09-30 | Dart `>=3.10.0` | Active | Use. Lockstep with `drift` (`>=2.30.0 <2.36.0`). |
| `drift_flutter` | 0.3.1 | 2026-07-11 | Dart `>=3.10.0` | Active | Use. Cross-platform drift setup. |
| `sqlite3` | 3.7.1 | 2026-10-13 | Dart `>=3.10.0` | Active | Use. Ships the native library via native assets. |
| `health` | 13.3.2 | 2026-08-14 | Dart `>=3.8.0`, Flutter `>=3.6.0` | Active (carp-dk) | **Use for Health Connect.** Wraps HealthKit + Health Connect. |
| `fl_chart` | 1.2.0 | 2026-03-13 | Dart `>=3.6.2`, Flutter `>=3.27.4` | Active | Use. |
| `flutter_svg` | 2.3.0 | 2026-05-08 | Dart `^3.9.0`, Flutter `>=3.35.0` | Active | Use. |
| `google_fonts` | 9.0.0 | 2026-09-28 | Dart `^3.13.0`, Flutter `>=3.47.0` | Active | Use — note the Flutter `>=3.47.0` floor. |
| `intl` | 0.20.3 | 2026-06-25 | Dart `^3.9.0` | Active | Use. |
| `path_provider` | 2.1.6 | 2026-06-15 | Dart `^3.10.0`, Flutter `>=3.38.0` | Active | Use. |
| `supabase_flutter` | 2.18.3 | 2026-10-12 | Dart `>=3.9.0`, Flutter `>=3.35.0` | Active | Use. |
| `supabase` | 2.16.5 | 2026-10-12 | Dart `>=3.9.0` | Active | Pinned transitively by `supabase_flutter`. |
| `connectivity_plus` | 7.3.2 | 2026-10-01 | Dart `^3.2.0`, Flutter `>=3.7.0` | Active | Use. |
| `workmanager` | 0.10.10 | 2026-09-07 | Dart `>=3.5.0`, Flutter `>=3.38.0` | Active (fluttercommunity) | Use for periodic background sync. |
| `flutter_lints` | 6.0.0 | 2025-05-27 | Dart `^3.8.0` | Active | Use. |
| `mocktail` | 1.0.5 | 2026-04-10 | Dart `>=2.12.0 <4.0.0` | Active | Use. No codegen needed. |

## Do Not Use

| Package | Latest | Why it is excluded |
|---|---|---|
| `sqlite3_flutter_libs` | `0.6.0+eol` | **End-of-life.** Its own description: "Not used anymore, update to version 3.x of package:sqlite3 instead." The native plugin declarations were removed. Use `sqlite3` 3.x instead. |
| `health_connect` | 0.0.0 (2023-01-10) | Abandoned. Dart SDK constraint `>=2.18.2 <3.0.0` excludes Dart 3 entirely. |
| `flutter_health_connect` | 1.2.3 (2023-03-08) | Abandoned. Dart SDK constraint `>=2.17.0 <3.0.0`. Example-plugin quality (`com.example.health_connect`). |
| `healthkit` | — | Not used: the user chose manual entry + Health Connect, not Apple HealthKit. Do not add it. |

## Known Cautions

- **`isar`** — historically popular, but its maintenance status has been inconsistent
  and it does not support the latest Dart SDK constraints. Use `drift`.
- **`hive`** / **`hive_ce`** — usable but untyped. `drift` gives real queries and
  migrations, which a health time-series schema needs.
- **`freezed` 4.x requires Dart `^3.13.0`** — this is the highest floor in the
  dependency set and sets the project baseline.
- **`google_fonts` 9.0.0 requires Flutter `>=3.47.0`** — if the installed Flutter is
  older, either upgrade Flutter or pin `google_fonts` to 8.x deliberately, and
  document the pin.
- **`drift_dev` must stay in lockstep with `drift`** — its constraint is
  `drift >=2.30.0 <2.36.0`. Upgrading one without the other forces a downgrade.
