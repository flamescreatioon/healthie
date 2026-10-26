---
name: health-data-visualization
description: Builds Healthie's data visualizations and dashboards — daily and weekly trend charts, stat tiles, sparklines, goal and comparison displays, and the charts on the metric detail screens — using fl_chart. This skill should be used whenever work involves plotting health data, building the dashboard, adding a chart, choosing chart colours or axes, displaying a summary statistic, or deciding how to visualise a metric over time. Use it before writing any chart code.
---

# Health Data Visualization

Health data is time series. The visualisation job is to let someone glance at a
chart and see whether things are trending up, down, or sideways — and then dig
into the underlying records.

**Read the `dataviz` skill first.** It is a global skill covering palette, axis
rules, legend handling, and accessibility for charts. Apply it here rather than
re-deriving chart aesthetics; this skill covers the health-specific decisions on
top of it.

## The fl_chart API

Use `fl_chart` 1.2.0. The 1.x line differs from the widely-documented 0.8x API:

- `LineTouchData` replaces `LineTouchData`'s older `touchCallback` style; tooltips
  come from `LineTouchTooltipData`.
- `FlTitlesData` / `AxisTitles` / `SideTitles` replace the older `TitlesData`
  structure.
- `getTitlesWidget` receives `(double value, TitleMeta meta)`.
- `BarAreaData` replaced `belowBarData` colour-only styling.

## Chart Selection

Pick the form that matches the question the user is asking:

| Question | Form |
|---|---|
| "How have I been trending?" | Line chart over time |
| "How much did I do each day this week?" | Bar chart per day |
| "What did today look like?" | Sparkline in a stat tile |
| "Am I on track for my goal?" | Progress meter against a goal |
| "How does today compare to my average?" | Value + comparison text |
| "When did this happen?" | List, not a chart |

**Do not chart a single value.** A pie chart of one metric is a bug. If there is
one data point, show the number.

**Do not chart categories that are naturally ordered.** A bar chart of the last
seven days' step counts is right; a pie chart of "steps vs water vs sleep" is
meaningless because the categories are unrelated.

## Time Axes

Time axes are where health charts usually go wrong.

- **Aggregate to the right granularity.** Daily bars for a week, weekly points for
  a quarter, monthly for a year. Plotting 365 daily points on a phone-sized
  chart produces an unreadable smear.
- **Never plot raw irregular timestamps as a dense line.** If readings are
  sporadic (weight taken twice a week), the chart must show discrete points, not
  a continuous line implying data between them. Use `FlDotData(show: true)` with
  `isCurved: false` for sparse series.
- **Label the axis with the granularity**, not the raw date. "Mar" for a monthly
  axis, "Mon" for a daily one.
- **Respect the user's local day boundaries.** Align buckets to the local day, not
  to UTC midnight — the same rule the storage layer uses. A chart whose bars do
  not line up with the "today" tile below it looks broken.
- **Show gaps as gaps.** Do not interpolate across missing days. A missing day
  means "I didn't log", not "zero".

## Stat Tiles

The dashboard is a grid of stat tiles. A tile shows:

- **The current value** — large, with the unit.
- **A comparison** — the change vs. the previous period ("+0.4 kg", "12% less").
- **A sparkline** — the recent trend, small and muted.
- **A trend direction indicator** — but only when the direction is meaningful.

Rules:

- **Show the comparison, not a verdict.** "−0.4 kg vs. last week" is information.
  "Great job!" is opinion. Let the user draw conclusions.
- **Trend colour must not imply good/bad.** Weight trending down is not
  universally good. Use a neutral accent for the trend, and reserve semantic
  colours for things that genuinely have a direction (a goal exceeded, a value
  outside a normal band).
- **Every tile must handle the empty state.** No data yet is normal on day one,
  not an error. Show the tile with a dash and a prompt to log the first entry.

## Goal Display

Goals are optional and per-metric. A goal display is a **progress meter**, not a
chart: the current value against the target, with the remaining amount stated in
words ("1.2 kg to go").

- Never show a goal the user has not set.
- Handle the case where the metric is already past the target (weight loss goals
  especially) without rendering a nonsensical over-full bar.
- Goals should not be prescriptive about health outcomes. Frame them as the
  user's own target.

## Colour

Apply the `dataviz` skill's palette rules. Health-specific considerations:

- **Series identity is stable.** Steps are always the same colour on every
  screen. Assign each metric type a fixed accent, defined once in a theme
  extension, so the user learns the mapping.
- **Do not encode value by hue alone.** For a line chart, colour distinguishes
  series, not magnitude — magnitude is the y position. Never tint a line
  "red = low, green = high" without a legend, and be careful with red/green
  pairs for colour-vision deficiency.
- **Background grid lines are faint**, or absent for small charts.
- **The chart background matches the card background** — no default grey chart
  fill against a themed card.

## Chart Interaction

- **Tooltips on touch**, with the value, unit, and date. A tooltip showing a bare
  number is useless.
- **Tap a point to open the record.** The chart is a navigation surface.
- **Charts scroll with the page**, not independently, unless the chart is
  deliberately a scrubber.
- **Range selection** (7 / 30 / 90 days / all) as a segmented control above the
  chart, not buried in a menu.

## Empty, Loading, and Error States

Every chart has all three:

- **Empty** — "No entries yet" with a link to log one. Not a blank box.
- **Loading** — a placeholder sized like the chart, so the layout does not jump.
- **Error** — the chart's area shows a message and a retry button.

Never show a chart with no data and no explanation. A blank rectangle in a health
app reads as "your data is broken".

## Accessibility

- Charts must have a non-visual equivalent: the stat tile's value and comparison
  carry the same information as the chart.
- Announce the summary, not the raw data, to screen readers.
- Ensure chart colours meet contrast requirements against their background.
- Support a larger text scale without clipping axis labels — hardcode
  `reservedSize` generously and test at 200% text size.

## Performance

- A chart with more than a few hundred points must be downsampled before
  rendering. Aggregate to the display granularity rather than plotting every
  point.
- Rebuild charts only when their data changes. Wrap in `const` where possible and
  avoid rebuilding a chart on every keystroke elsewhere on the screen.
- Long lists of records belong in a `ListView.builder`, with the chart above them
  computing its aggregate once, not per row.

## Reference Files

- `references/chart-recipes.md` — fl_chart 1.2.0 implementations for a trend
  line, daily bars, a sparkline, and a goal meter.
