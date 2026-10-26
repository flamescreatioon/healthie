---
name: flutter-design-system
description: Defines and applies Healthie's visual design system — the Material 3 theme and colour scheme, typography, spacing and elevation tokens, the shared component library, dark mode, accessibility, and motion. This skill should be used whenever work builds or styles a screen, adds a component, introduces a colour or text style, implements dark mode, or addresses accessibility, visual consistency, or spacing. Use it before writing UI that introduces a new visual pattern.
---

# Design System

Healthie is a personal app people open daily for a quick look at their own
health. The design should feel calm, legible, and quick — not clinical, not
gym-bro, not a hospital chart.

## Principles

1. **Glanceable.** The dashboard answers "how am I doing?" in one screen. Key
   numbers are large; everything else is secondary.
2. **Calm, not alarming.** Health data is personal and often emotionally
   loaded. Avoid red for anything that is not an actual problem, and avoid
   celebration graphics that make a normal reading feel like an achievement.
3. **Consistent.** One spacing scale, one type scale, one set of card shapes. A
   new screen should be assemblable from existing components.
4. **Honest.** Show the data as measured. Do not smooth, truncate, or dramatise
   it to make a trend look better than it is.
5. **Accessible by default.** Legible at large text sizes, in dark mode, and
   with a screen reader.

## Theme

Material 3, with the colour scheme generated from a seed colour, extended
explicitly for the semantic colours the app needs.

```dart
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.positive,
    required this.negative,
    required this.neutral,
    required this.metricSteps,
    required this.metricHeart,
    required this.metricSleep,
    required this.metricWeight,
    required this.metricNutrition,
  });

  final Color positive;
  final Color negative;
  final Color neutral;
  final Color metricSteps;
  final Color metricHeart;
  final Color metricSleep;
  final Color metricWeight;
  final Color metricNutrition;

  @override
  AppColors copyWith({
    Color? positive,
    Color? negative,
    Color? neutral,
    Color? metricSteps,
    Color? metricHeart,
    Color? metricSleep,
    Color? metricWeight,
    Color? metricNutrition,
  }) =>
      AppColors(
        positive: positive ?? this.positive,
        negative: negative ?? this.negative,
        neutral: neutral ?? this.neutral,
        metricSteps: metricSteps ?? this.metricSteps,
        metricHeart: metricHeart ?? this.metricHeart,
        metricSleep: metricSleep ?? this.metricSleep,
        metricWeight: metricWeight ?? this.metricWeight,
        metricNutrition: metricNutrition ?? this.metricNutrition,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      metricSteps: Color.lerp(metricSteps, other.metricSteps, t)!,
      metricHeart: Color.lerp(metricHeart, other.metricHeart, t)!,
      metricSleep: Color.lerp(metricSleep, other.metricSleep, t)!,
      metricWeight: Color.lerp(metricWeight, other.metricWeight, t)!,
      metricNutrition: Color.lerp(metricNutrition, other.metricNutrition, t)!,
    );
  }
}
```

**Metric colours are fixed.** Steps are always the same colour on every screen.
Assign them once in the theme extension so the user learns the mapping. Use
`Theme.of(context).extension<AppColors>()!` to read them — never a hard-coded
`Color(0xFF...)` in a widget.

### Semantic colours are scarce

Reserve `positive` and `negative` for things that genuinely have a direction
and a judgement: a goal met, a value outside a normal band. **Do not colour a
trend line by whether it went up or down.** Weight trending down is not
universally good; mood trending down is not universally bad. Use the metric's
fixed accent for the trend and let the numbers speak.

## Typography

Use `google_fonts` 9.0.0. One family, a few weights.

| Role | Size | Weight |
|---|---|---|
| Display (a headline stat) | 34 | 600 |
| Headline (screen title) | 24 | 600 |
| Title (card title) | 18 | 600 |
| Body | 15 | 400 |
| Label (axis, caption) | 12 | 500 |

Line height: 1.4 for body, 1.2 for display. **Numbers use tabular figures** so
digits align in a column:

```dart
TextStyle(
  fontFeatures: const [FontFeature.tabularFigures()],
)
```

Tabular figures matter here — a column of changing step counts that jitters
horizontally as digits change is hard to scan.

## Spacing

One scale. Use it everywhere; do not invent 13px.

```
4  8  12  16  24  32  48
```

- Screen horizontal padding: 16.
- Gap between cards: 16.
- Gap between a label and its value: 4–6.
- Card internal padding: 16.
- Bottom sheet padding: 24, plus the safe-area inset.

## Shape and Elevation

- Card radius: 16.
- Small chips and inputs: 12.
- Sheets: 28 on top, 0 on the bottom.
- Use **one** elevation level for cards. Depth comes from the surface colour
  and a subtle border, not from heavy shadows — shadows read as dated.

## Components

Build these once in `shared/widgets/` and reuse them. A new screen should not
introduce a new card style.

- `AppCard` — the standard surface.
- `StatTile` — a labelled value with an optional comparison and sparkline (see
  the `health-data-visualization` skill).
- `SectionHeader` — a title with an optional trailing action.
- `RangeSelector` — the 7/30/90 day segmented control.
- `EmptyState` — an icon, a message, and a primary action.
- `ErrorState` — a message and a retry button.
- `LoadingState` — a placeholder matching the shape of the content, so the
  layout does not jump when data arrives.
- `MetricBadge` — a metric type's icon and fixed accent colour.

## Dark Mode

Support it from the first screen, not as a retrofit.

- Derive the whole scheme from the seed with `ColorScheme.fromSeed`.
- Define `AppColors` for both brightnesses — the fixed metric accents must stay
  legible on dark surfaces, which usually means lighter, less saturated versions.
- **Never hard-code surface colours.** Use `colorScheme.surface`,
  `surfaceContainer`, `surfaceContainerHighest`.
- Charts, grid lines, and sparklines all need dark variants — a chart that
  looks right in light mode can be invisible in dark mode.

## Accessibility

Non-negotiable, and it is a large part of "calm and legible":

- **Touch targets ≥ 48dp**, with adequate spacing.
- **Contrast**: body text ≥ 4.5:1, large text and icons ≥ 3:1. Check the muted
  text colours against their surface in both brightnesses.
- **Do not encode meaning by colour alone.** A downward trend is also an arrow
  and a sign.
- **Labels, not placeholders.** Placeholders vanish when the user types.
- **Screen-reader support for charts**: the stat tile's value and comparison
  carry the same information as the chart (see the
  `health-data-visualization` skill).
- **Respect the user's text scale.** Test at 200%. Fixed heights are the usual
  cause of overflow; prefer flexible layout.
- **Respect reduced motion.** Honour `MediaQuery.disableAnimations` and keep
  transitions short (150–250ms) regardless.
- **Announce state changes**: sync status, permission changes, and save
  confirmations should be announced to screen readers.

## Motion

Restrained. This is a data app, not a game.

- Transitions: 150–250ms, `Curves.easeOut`.
- **No bouncing, no scale-up, no confetti.**
- Animate chart data changes only if it is smooth — otherwise cross-fade.
- Respect `MediaQuery.disableAnimations`.

## Layout Rhythm

- The dashboard is a grid of stat tiles, 2 columns on phones, more on tablets.
- Group by concern: activity, sleep, body, vitals. Not alphabetically.
- The primary action (log a value) is always reachable — a persistent FAB on the
  dashboard, or a bottom-bar action.
- Empty space is fine. A dense dashboard is harder to scan, and health data
  deserves room to breathe.

## Pre-Ship Checklist

- [ ] No hard-coded colours outside the theme.
- [ ] Metric colours match the theme extension on every screen.
- [ ] Dark mode renders correctly, including charts and grid lines.
- [ ] Text at 200% scale does not overflow.
- [ ] Touch targets are ≥ 48dp.
- [ ] Contrast passes in both brightnesses.
- [ ] Every screen has a loading, empty, and error state.
- [ ] Reduced motion is honoured.
