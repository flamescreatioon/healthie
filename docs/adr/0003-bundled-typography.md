# ADR 0003 — Bundled Inter typography instead of runtime font download

## Status

Accepted

## Context

The design system specifies Inter for legibility and tabular figures. The
`google_fonts` package downloads font files at runtime over the network.

Healthie is offline-first by design. A runtime font download means:

- the first launch without a network shows a fallback font,
- a third-party network dependency in a health app that promises privacy and
  offline behaviour,
- a flash of unstyled text on every cold start.

## Decision

**Bundle Inter** as a font asset (`assets/fonts/Inter-*.ttf`, weights
400/500/600/700) and declare it in `pubspec.yaml` under `flutter.fonts`.
Do not add `google_fonts`.

### Trade-off

- The app ships ~1.3 MB of font files. That is an acceptable, one-time cost
  for guaranteed offline rendering and no third-party network call.

## Consequences

- `google_fonts` is not a dependency (removed from `pubspec.yaml`).
- Theme text styles use `fontFamily: 'Inter'` and `FontFeature.tabularFigures()`
  so columns of digits do not jitter horizontally as values change.
