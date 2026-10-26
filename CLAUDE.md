# Healthie

A Flutter mobile app for personal health tracking. Android is the primary
platform: it reads from Android Health Connect, accepts manual entry, and syncs
to a cloud backend. iOS ships manual entry only — no Apple HealthKit access was
requested.

This project has **no code yet**. It is greenfield.

## Skills

Twelve project skills live in `.claude/skills/`. Each is a self-contained guide
written for another agent working in this codebase. **Read the relevant skill
before doing the corresponding work** — they contain the decisions, version
pins, and platform gotchas that are expensive to rediscover.

| Skill | Use it for |
|---|---|
| `flutter-project-setup` | Toolchain, dependencies, Gradle, codegen, linting |
| `flutter-architecture` | Feature-first layering, Riverpod, repositories, routing |
| `health-domain-model` | Metric catalog, units, schema, local-day rules, ADRs |
| `health-connect-android` | Health Connect permissions, reading, manifest, availability |
| `health-manual-entry` | Entry forms, validation, unit switching, edit/delete |
| `health-data-visualization` | Charts, dashboard tiles, sparklines, goals |
| `health-cloud-sync` | Supabase auth, RLS, offline-first sync, conflicts |
| `flutter-testing` | Unit, widget, repository, migration, integration tests |
| `flutter-debugging` | Build errors, layout overflow, jank, release-only bugs |
| `flutter-release-android` | Signing, app bundles, ProGuard, CI, Play submission |
| `health-privacy-compliance` | Permissions, privacy policy, deletion, export, Play health declaration |
| `flutter-design-system` | Theme, typography, spacing, components, dark mode, a11y |

Two global skills also apply and should be read in addition:

- **`dataviz`** — chart palette, axes, legends, accessibility. Read before
  writing any chart code.
- **`frontend-design`** — general visual-design guidance.

## Ground Rules

- **Read the skill before the work.** Each skill names the specific package
  versions and platform behaviours that apply.
- **The `health` package is at API v13** (`Health()` + `configure()`), not the
  older `HealthFactory` API that most online guides show. See
  `health-connect-android`.
- **`sqlite3_flutter_libs` is EOL.** Use `sqlite3` 3.x via drift.
- **Health Connect needs `minSdk 28`** and `MainActivity` extending
  `FlutterFragmentActivity`.
- **The local Drift database is the source of truth.** The network is never on
  the critical path of a user-visible write.
- **Health data is sensitive.** Never log health values, never put them in
  URLs, never send them to analytics.
- **Healthie is a tracker, not a medical device.** No diagnosis, no treatment
  advice.
- **Write tests alongside features**, not after. See `flutter-testing`.
- `flutter analyze` must be clean and `flutter test` must pass before any
  change is considered done.

## Working Order

For a new feature, in order:

1. `flutter-project-setup` — if it needs a new package.
2. `health-domain-model` — define the metric and its units.
3. `flutter-architecture` — domain model → repository → DAO → providers → UI.
4. The feature-specific skill (`health-manual-entry`, `health-data-visualization`,
   `health-cloud-sync`, `health-connect-android`).
5. `flutter-testing`.
6. `flutter-design-system` — when building new UI.
7. `health-privacy-compliance` — before shipping anything that changes what
   data leaves the device.
