# Phase 5 — Dashboard & Visualization (Next.js PWA)

Source specs: `dataviz` first, then `health-data-visualization`. Chart library: `recharts` (Next.js equivalent of mobile's `fl_chart`).

## Goal

Same charts and tiles as mobile, same look and same rules, adapted to wider screens and the installed PWA.

## Steps

1. Keep the same chart forms: line for trends, bars for daily weeks, sparklines in tiles, progress meter for user-set goals only. No single-value charts; no pie-of-unrelated-categories.
2. Time-axis rules (identical to mobile): aggregate to display granularity, discrete dots for sparse series (no continuous line implying data between readings), local-day bucketing matching storage, gaps shown as gaps (never interpolated to zero), axis labels at the granularity.
3. Tooltips carry value + unit + date. Click a point to open the record. Range selection (7/30/90) as a segmented control above the chart.
4. Stat tiles: current value + comparison ("−0.4 kg vs last week") + muted sparkline. Comparison, not verdict. No goal shown unless the user set one.
5. Colour: stable per-metric accent from the shared theme tokens on every screen; trend in a neutral accent; semantic colours only for genuine direction (goal met, out-of-band value). Follow the global `dataviz` palette/contrast rules.
6. Every chart gets loading / empty / error states. Empty links to log the first entry. Stat tile value + comparison duplicates chart info for screen readers; canvas/SVG charts get text summaries and keyboard-reachable data points where feasible.

## Exit criteria

- [ ] Trend, bar, sparkline, and goal-meter forms match the mobile spec.
- [ ] Chart bars align with the "today" tile across DST boundaries.
- [ ] Missing days render as gaps, not zeros.
- [ ] Dark-mode charts legible, gridlines visible.
- [ ] Screen-reader summary carries the chart's information.
