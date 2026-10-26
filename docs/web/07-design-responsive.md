# Phase 6 — Design Parity + Responsive + Install UX (Next.js PWA)

Source specs: `flutter-design-system` + `frontend-design`. Implementation: CSS variables + Tailwind (or equivalent) carrying the same tokens.

## Goal

The installed Next.js PWA looks like the same product as the Flutter app: same tokens, same components, same calm glanceable feel — responsive from phone to desktop, installable everywhere it matters.

## Steps

1. Port the design tokens 1:1 into CSS variables: seed-derived light + dark colour schemes, per-metric accents (with dark-mode-legible variants), type scale (display 34 / headline 24 / title 18 / body 15 / label 12, tabular figures for numbers), spacing scale 4/8/12/16/24/32/48, card radius 16, one elevation level. No hard-coded colours outside the tokens. `theme_color` + splash backgrounds come from these tokens.
2. Rebuild the shared components with the same names and behaviour: `AppCard`, `StatTile`, `SectionHeader`, `RangeSelector`, `EmptyState`, `ErrorState`, `LoadingState`, `MetricBadge`. New screens assemble from these; no new card styles.
3. Responsive spec: 2-column phone grid → multi-column desktop grid with a max-width container; persistent primary log action (FAB-equivalent on narrow widths, header/sidebar action on desktop). Screen padding 16, card gaps 16, card padding 16, sheet padding 24 + safe area. Standalone-display (installed) layout must account for the missing browser chrome.
4. PWA install UX: `beforeinstallprompt` handling with a calm inline install affordance (no pop-up spam, no dark patterns), install guidance for iOS Safari (manual Add-to-Home-Screen), installed-first-run state, and an update-available prompt wired to the versioned service worker. Document the iOS PWA limits that affect the app (push, Background Sync availability) wherever the UI depends on them.
5. Motion restrained (150–250ms ease-out, `prefers-reduced-motion` honoured). No bounce, scale-up, or confetti.
6. Accessibility: targets ≥ 48px, contrast 4.5:1 body / 3:1 large in both themes, meaning never by colour alone, 200% text scale without overflow, visible keyboard focus, state changes announced via live regions.

## Exit criteria

- [ ] No hard-coded colours outside the theme tokens.
- [ ] Metric colours match the tokens on every screen.
- [ ] Dark mode renders correctly, including charts and gridlines.
- [ ] 200% text scale does not overflow.
- [ ] Every screen has loading, empty, and error states.
- [ ] Reduced motion honoured.
- [ ] Install prompt + update prompt flows verified on Chromium and documented for Safari.
