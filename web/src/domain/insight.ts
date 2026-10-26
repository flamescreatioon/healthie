/**
 * Deterministic insight generation (1:1 port of `lib/features/analytics/domain/insight.dart`).
 *
 * Every insight is a reproducible calculation over stored readings. Nothing
 * invents a measurement, asserts a cause, or claims a diagnosis.
 */

import { bpCategoryShare, type BpPeriodSummary } from './blood-pressure-analytics';
import { dateRangeDayCount } from './date-range';
import { changeBetween } from './statistics';
import type { WeightPeriodSummary } from './weight-analytics';

export type InsightKind =
  | 'comparison'
  | 'consistency'
  | 'change'
  | 'sparsity'
  | 'outlier';

export interface Insight {
  readonly id: string;
  readonly kind: InsightKind;
  readonly title: string;
  readonly body: string;
  readonly sampleCount?: number;
  readonly limitation?: string;
}

export function bloodPressureInsights(params: {
  current: BpPeriodSummary;
  previous?: BpPeriodSummary;
}): Insight[] {
  const { current, previous } = params;
  const insights: Insight[] = [];
  const systolic = current.systolic;
  const diastolic = current.diastolic;

  if (!systolic || systolic.count === 0) {
    insights.push({
      id: 'bp.no-data',
      kind: 'sparsity',
      title: 'No blood pressure readings yet',
      body: 'Record a blood pressure reading to start building your trend. Readings are classified against the AHA/ACC 2017 guideline.',
    });
    return insights;
  }

  if (previous?.systolic) {
    const change = changeBetween(previous.systolic.mean, systolic.mean);
    if (change && Math.abs(change.absolute) >= 1) {
      const higher = change.absolute > 0;
      const prevDays = dateRangeDayCount(previous.period);
      insights.push({
        id: 'bp.systolic-comparison',
        kind: 'comparison',
        title: higher ? 'Systolic pressure is up' : 'Systolic pressure is down',
        body: `Your average systolic pressure was ${Math.abs(change.absolute).toFixed(0)} mmHg ${higher ? 'higher' : 'lower'} than in the previous ${prevDays}-day period (${systolic.mean.toFixed(0)} mmHg versus ${previous.systolic.mean.toFixed(0)} mmHg).`,
        sampleCount: systolic.count,
        limitation:
          'A change in an average is a description of the recorded data. It is not a diagnosis and does not establish a cause.',
      });
    }
  }

  insights.push({
    id: 'bp.consistency',
    kind: 'consistency',
    title: 'Recording consistency',
    body: `You recorded blood pressure on ${current.loggedDays} of the last ${current.totalDays} days (${Math.round(current.completeness * 100)}%).`,
    sampleCount: systolic.count,
    ...(current.loggedDays < Math.floor(current.totalDays / 2)
      ? {
          limitation:
            'Frequent gaps limit how confidently a trend can be described.',
        }
      : {}),
  });

  const trend = current.systolicTrend;
  if (trend.direction === 'insufficient_data') {
    insights.push({
      id: 'bp.trend',
      kind: 'sparsity',
      title: 'Not enough readings for a reliable trend',
      body:
        trend.limitation ??
        'There are not enough measurements to calculate a reliable trend.',
      sampleCount: trend.sampleCount,
    });
  } else {
    const title =
      trend.direction === 'increasing'
        ? 'Systolic pressure is trending up'
        : trend.direction === 'decreasing'
          ? 'Systolic pressure is trending down'
          : 'Systolic pressure is stable';
    insights.push({
      id: 'bp.trend',
      kind: 'change',
      title,
      body: `Across ${trend.sampleCount} days of readings the estimated change is ${trend.totalChange!.toFixed(1)} mmHg (${trend.slopePerDay!.toFixed(2)} mmHg per day).`,
      sampleCount: trend.sampleCount,
      limitation:
        trend.direction === 'stable'
          ? 'The variation stayed within the range considered normal day-to-day fluctuation.'
          : 'A mathematical trend is not a clinical conclusion.',
    });
  }

  if (current.latest && systolic.count >= 4) {
    const deviation = current.latest.value - systolic.median;
    if (Math.abs(deviation) >= 15) {
      insights.push({
        id: 'bp.latest-outlier',
        kind: 'outlier',
        title: 'Latest reading differs from your recent readings',
        body: `Your latest systolic reading of ${current.latest.value.toFixed(0)} mmHg is ${Math.abs(deviation).toFixed(0)} mmHg away from the median of the last ${systolic.count} readings. Consider repeating the measurement using the recommended technique.`,
        sampleCount: systolic.count,
        limitation:
          'A single unusual reading may reflect technique, timing, or everyday circumstances rather than a change in your health.',
      });
    }
  }

  const normalShare = bpCategoryShare(current, 'normal');
  if (current.readingCount >= 5) {
    insights.push({
      id: 'bp.distribution',
      kind: 'comparison',
      title: 'Guideline distribution',
      body: `${Math.round(normalShare * 100)}% of your ${current.readingCount} recorded readings were below 120/80, classified as Normal under the ${current.guideline.name} guideline.`,
      sampleCount: current.readingCount,
      limitation:
        'A small number of readings does not represent your overall clinical condition.',
    });
  }

  if (diastolic && diastolic.count !== systolic.count) {
    insights.push({
      id: 'bp.partial',
      kind: 'sparsity',
      title: 'Some readings have no diastolic value',
      body: 'Averages are computed separately for systolic and diastolic readings, so they may be based on different numbers of measurements.',
    });
  }

  return insights;
}

export function weightInsights(params: {
  current: WeightPeriodSummary;
  previous?: WeightPeriodSummary;
}): Insight[] {
  const { current, previous } = params;
  const insights: Insight[] = [];
  const stats = current.stats;

  if (!stats || stats.count === 0) {
    insights.push({
      id: 'weight.no-data',
      kind: 'sparsity',
      title: 'No weigh-ins yet',
      body: 'Record a weight to start building your trend.',
    });
    return insights;
  }

  if (previous?.stats) {
    const change = changeBetween(previous.stats.mean, stats.mean);
    if (change && Math.abs(change.absolute) >= 0.1) {
      const prevDays = dateRangeDayCount(previous.period);
      insights.push({
        id: 'weight.comparison',
        kind: 'comparison',
        title: change.absolute < 0 ? 'Weight is down' : 'Weight is up',
        body: `Your average weight changed by ${Math.abs(change.absolute).toFixed(1)} kg compared with the previous ${prevDays}-day period (${stats.mean.toFixed(1)} kg versus ${previous.stats.mean.toFixed(1)} kg).`,
        sampleCount: stats.count,
        limitation:
          'Daily weight fluctuates with hydration, sleep, and meal timing. A difference of a few tenths of a kilogram is normal variation.',
      });
    }
  }

  insights.push({
    id: 'weight.consistency',
    kind: 'consistency',
    title: 'Recording consistency',
    body: `You weighed in on ${current.loggedDays} of the last ${current.totalDays} days (${Math.round(current.completeness * 100)}%).`,
    sampleCount: stats.count,
  });

  const trend = current.trend;
  if (trend.direction === 'insufficient_data') {
    insights.push({
      id: 'weight.trend',
      kind: 'sparsity',
      title: 'Not enough weigh-ins for a reliable trend',
      body:
        trend.limitation ??
        'There are not enough measurements to calculate a reliable trend.',
      sampleCount: trend.sampleCount,
    });
  } else {
    const pace = current.weeklyPace;
    const title =
      trend.direction === 'increasing'
        ? 'Weight is trending up'
        : trend.direction === 'decreasing'
          ? 'Weight is trending down'
          : 'Weight is stable';
    insights.push({
      id: 'weight.trend',
      kind: 'change',
      title,
      body:
        pace === null
          ? `Across ${trend.sampleCount} days of readings the estimated change is ${trend.totalChange!.toFixed(1)} kg.`
          : `Across ${trend.sampleCount} days of readings the estimated change is ${trend.totalChange!.toFixed(1)} kg (${pace.toFixed(2)} kg per week).`,
      sampleCount: trend.sampleCount,
      limitation:
        'This describes the recorded data only. It is not advice about what your weight should be.',
    });
  }

  if (current.bodyFatLatest !== null && current.bodyFatChange) {
    insights.push({
      id: 'weight.body-fat',
      kind: 'comparison',
      title: 'Body fat ratio',
      body: `Your latest body-fat reading is ${current.bodyFatLatest.toFixed(1)}%, ${Math.abs(current.bodyFatChange.absolute).toFixed(1)} percentage points ${current.bodyFatChange.absolute < 0 ? 'lower' : 'higher'} than the previous period.`,
      sampleCount: stats.count,
      limitation:
        'Body-fat readings depend on the device and method used, so they are comparable within a method rather than across methods.',
    });
  }

  return insights;
}

export function dashboardInsight(params: {
  current: BpPeriodSummary;
  previous?: BpPeriodSummary;
}): Insight {
  const all = bloodPressureInsights(params);
  const comp = all.find(
    (i) => i.kind === 'comparison' && i.id === 'bp.systolic-comparison',
  );
  if (comp) return comp;
  const cons = all.find((i) => i.kind === 'consistency');
  if (cons) return cons;
  return all[0]!;
}
