# Analytics

Every number the app shows is a calculation over stored measurements. Nothing
is estimated, interpolated, or filled in. This document states how each
calculation is made, so a number on screen can always be reproduced by hand.

**The rule that governs everything below:** an observation must be
*reproducible from the underlying records*. If it cannot be, it is not shown.

---

## 1. Periods

A period is a half-open range of local days, `[start, end)`.

| Selector | Length |
|---|---|
| 7 days | 7 local days ending today |
| 30 days | 30 local days ending today |
| 90 days | 90 local days ending today |
| 6 months | 182 local days ending today |
| 1 year | 365 local days ending today |
| All | Every recorded measurement |

The **previous period** is the immediately preceding range of the same length.
It is used for every comparison.

---

## 2. Descriptive statistics

Computed over a list of values (`DescriptiveStats.from`).

| Statistic | Method |
|---|---|
| Count | Number of observations |
| Mean | Arithmetic mean |
| Median | 50th percentile; the mean of the two middle values for an even count |
| Minimum / Maximum | Extremes |
| Standard deviation | **Sample** standard deviation, denominator `n - 1`. `null` when `n < 2` — a standard deviation over one point is not meaningful |

An empty dataset returns `null`, not a zero. No data on day one is a normal
state, not an error.

### Two different averages, always named

For blood pressure the app computes **both** and never mixes them:

- **Period statistics** — over *all individual readings* in the period. This
  is what the "Avg Systolic" tile shows.
- **Daily means** — the mean of each day's readings. This is what the chart
  plots.

They differ whenever a day has more than one reading. The chart is labelled
"Mean Daily Fluctuations"; the tile is labelled "Avg Systolic".

---

## 3. Aggregating by day

Readings are grouped by their **local day** (`startOfLocalDay`), not by UTC.
Multiple readings on the same day are averaged into one daily mean.

Days with no readings are **absent from the series, not zero-filled**. A
missing day means "I did not log", not "I logged zero". The chart draws one
contiguous segment per run of days with data, so the gap is visible.

---

## 4. Moving averages

A centred moving average over a window of days.

| Series | Window |
|---|---|
| Weight | 7 days |
| Blood pressure | 30 days |

Positions without a complete window are `null`, not an invented value. A
chart whose average starts on day one is showing something that was never
measured.

---

## 5. Blood pressure classification

Screening categories from the **AHA/ACC 2017** guideline for high blood
pressure in adults. The guideline's name and version travel with every
result, so a future guideline update does not require rewriting the engine.

Applied in order — the order matters:

| Order | Category | Rule |
|---|---|---|
| 1 | Hypertensive crisis | systolic **above 180** and/or diastolic **above 120** |
| 2 | Stage 2 hypertension | systolic **at least 140** or diastolic **at least 90** |
| 3 | Stage 1 hypertension | systolic 130–139 **or** diastolic 80–89 |
| 4 | Elevated | systolic 120–129 **and** diastolic **below 80** |
| 5 | Normal | systolic below 120 **and** diastolic below 80 |

Because "or" governs the elevated stages, the order is load-bearing:

- **120/80 is Stage 1**, not Normal and not Elevated. A diastolic of 80 is
  not "below 80".
- **125/85 is Stage 1**, not Elevated.
- **118/85 is Stage 1**, not Normal.

Exactly 180/120 is Stage 2, not a crisis: the crisis threshold is *above*
180 and *above* 120.

### Distribution

The guideline distribution shows how many readings fell into each category,
with the percentage computed against **all readings in the period**. Both the
count and the share are shown, because a percentage without its denominator
is not information.

A caveat is always displayed: a small number of readings does not represent
the user's overall clinical condition.

---

## 6. Safety assessment

Evaluated **per reading**, independently of any average or trend. A reading
is never softened because the user's 30-day average looks fine.

| Level | Trigger | Guidance |
|---|---|---|
| None | Everything else | The standing safeguard note |
| Caution | systolic ≥ 140 or diastolic ≥ 90 | Rest five minutes, sit supported, arm at heart level, measure again |
| Urgent | systolic > 180 or diastolic > 120 | Repeat after at least a minute; if it stays high, contact a clinician promptly; if there are chest pain, breathlessness, weakness, numbness, vision changes, or difficulty speaking, seek emergency care immediately |

Either value may be absent while the user is still typing. A dangerous
systolic raises the alert on its own, without waiting for the diastolic.

---

## 7. Trend detection

Health data is not evenly sampled: someone weighs in most mornings for a
fortnight and then not at all for a week. A least-squares slope over raw
timestamps treats that gap as "no change" and biases the result.

Healthie uses the **Theil–Sen estimator**: the median of the slopes of every
pair of observations. It is robust to outliers and to uneven spacing.

| Observations | Result |
|---|---|
| 0 or 1 | `insufficientData`, with an explanation |
| 2 | `insufficientData` — "two points cannot establish a reliable trend". The raw slope is reported with that caveat. |
| 3 or more | A direction is reported |

A direction is only reported when the **total change across the span**
exceeds a metric-specific threshold, because statistical variation is not a
meaningful change:

| Metric | Threshold |
|---|---|
| Systolic / diastolic pressure | 5 mmHg |
| Weight | 0.5 kg |

The result carries the number of observations, the span in days, the slope
per day, and the total change. It never labels a change as good or bad — a
mathematical trend is not a clinical conclusion.

---

## 8. Circadian comparison

| Window | Local time |
|---|---|
| Morning | 06:00 – 11:59 |
| Evening | 18:00 – 23:59 |

The app reports the mean systolic and diastolic for each window **and the
number of readings behind it**, because morning and evening recording
frequencies differ and a comparison without sample sizes is misleading.

The difference is stated as a fact ("your evening readings average 5 mmHg
lower systolic than your morning readings"), with no claim about cause.

---

## 9. Weight analytics

| Figure | Method |
|---|---|
| Current weight | The most recent weigh-in in the period |
| Starting baseline | The **first** weigh-in in the period |
| Baseline level | The mean over all weigh-ins in the period |
| Change vs previous | Mean of this period minus mean of the previous period |
| Percentage change | The relative change; **omitted** when the baseline is zero |
| Weekly pace | The period change scaled to seven days |
| Body fat | The latest body-fat reading, and its change against the previous period |

### Goal progress

```
progress = (current − start) / (target − start)
```

The result is clamped to 0–1. Overshooting a target never renders as an
over-full bar; the app reports the target as reached and the remaining
distance as zero.

A goal is never prescriptive. The app does not recommend a weight, does not
suggest a rate of change, and does not describe a change as good or bad.

**No forecasting.** The app does not predict a future weight, because a
precise prediction presented as a fact is not one.

---

## 10. Data completeness

```
completeness = days with at least one reading / days in the period
```

Shown as a percentage next to the count. It is reported separately from the
statistics, because a mean over four readings from four days in a month means
something different from a mean over four readings from one day.

---

## 11. Insights

Insights are generated by deterministic rules over the stored records. There
is no model, no inference, and no natural language generation. Every insight
carries:

- the metric it is about,
- the period it compares against,
- the actual calculated values,
- the number of observations where relevant,
- an explanation,
- and any limitation that matters.

The rules that produce them:

| Rule | Example |
|---|---|
| Comparison | "Your average systolic pressure was 10 mmHg higher than in the previous 30-day period." |
| Consistency | "You recorded blood pressure on 12 of the last 30 days (40%)." |
| Change | "Across 12 days of readings the estimated change is −3.2 mmHg (−0.27 mmHg per day)." |
| Sparsity | "Only 2 readings over 9 days. Two points cannot establish a reliable trend." |
| Outlier | "Your latest systolic reading of 170 mmHg is 50 mmHg away from the median of the last 5 readings." |

The limitation text is not decoration. A comparison always says that an
average is a description of the recorded data and not a diagnosis. A body-fat
comparison always says that readings are comparable within a method rather
than across methods.

---

## 12. Charts

| Rule | Reason |
|---|---|
| Gaps are drawn as gaps | A missing day is not a zero |
| Tooltips carry the value, unit, and date | A tooltip with a bare number is useless |
| Series colours are fixed per metric | The user learns the mapping once |
| Grid lines are faint | The data is the subject |
| The chart background matches the card | No default grey fill |
| Axis labels state the granularity | "Oct 15", not a timestamp |
| The tile's value and comparison carry the chart's information | A non-visual equivalent for every chart |

Charts never encode value by hue alone — colour distinguishes series, and
magnitude is the y position. Every clinical status is paired with a text
label and an icon, never colour by itself.
