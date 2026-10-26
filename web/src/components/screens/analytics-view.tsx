'use client';

/**
 * Biometric Analytics Screen (`docs/web/06-visualization.md` &
 * `lib/features/analytics/presentation/analytics_screen.dart`).
 *
 * - Segmented view selector: Blood Pressure | Weight
 * - Range selector: 7 Days | 30 Days | 90 Days
 * - Contiguous daily time series with `null` on missing days so charts render
 *   genuine gaps instead of interpolating or zero-filling.
 * - Denominators always shown alongside percentages.
 */

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import { Lightbulb, Moon, Sun } from 'lucide-react';
import {
  type AnalysisRangeDays,
  bloodPressureInsights,
  changeBetween,
  computeGoalProgress,
  convert,
  dateRangeEndingOn,
  formatBloodPressure,
  formatSigned,
  formatValue,
  getPulse,
  previousDateRange,
  shortDateLabel,
  summariseBloodPressure,
  summariseWeight,
  weightInsights,
} from '@/domain';
import { useRepositories } from '@/components/providers/app-providers';
import {
  AppCard,
  EmptyState,
  ErrorState,
  LoadingState,
  RangeSelector,
  SectionHeader,
  SegmentedControl,
  StatTile,
} from '@/components/ui/primitives';
import {
  DistributionBar,
  GoalMeter,
  TrendChart,
} from '@/components/charts/charts';

type AnalyticsTab = 'blood_pressure' | 'weight';

export function AnalyticsView() {
  const router = useRouter();
  const { measurements: repo, profile: profileRepo, clock } = useRepositories();
  const now = clock.now();

  const [tab, setTab] = useState<AnalyticsTab>('blood_pressure');
  const [rangeDays, setRangeDays] = useState<AnalysisRangeDays>(30);

  const period = dateRangeEndingOn(now, rangeDays);
  const prevPeriod = previousDateRange(period);

  const {
    data: currentMeasurements,
    isLoading,
    isError,
    refetch,
  } = useQuery({
    queryKey: ['measurements', 'analytics', rangeDays],
    queryFn: () => repo.list({ range: period }),
  });

  const { data: prevMeasurements = [] } = useQuery({
    queryKey: ['measurements', 'analytics-prev', rangeDays],
    queryFn: () => repo.list({ range: prevPeriod }),
  });

  const { data: profile } = useQuery({
    queryKey: ['profile'],
    queryFn: () => profileRepo.getProfile(),
  });

  const { data: goals = [] } = useQuery({
    queryKey: ['goals'],
    queryFn: () => profileRepo.listGoals(),
  });

  if (isLoading) {
    return <LoadingState lines={5} label="Loading biometric analytics…" />;
  }

  if (isError || !currentMeasurements) {
    return (
      <ErrorState
        message="We couldn't load your analytics."
        onRetry={() => void refetch()}
      />
    );
  }

  const bpSummary = summariseBloodPressure({
    period,
    measurements: currentMeasurements,
  });
  const prevBpSummary = summariseBloodPressure({
    period: prevPeriod,
    measurements: prevMeasurements,
  });
  const bpInsightsList = bloodPressureInsights({
    current: bpSummary,
    previous: prevBpSummary,
  });

  const weightSummary = summariseWeight({
    period,
    measurements: currentMeasurements,
    previousPeriodMeasurements: prevMeasurements,
  });
  const prevWeightSummary = summariseWeight({
    period: prevPeriod,
    measurements: prevMeasurements,
  });
  const weightInsightsList = weightInsights({
    current: weightSummary,
    previous: prevWeightSummary,
  });

  const sysChange = changeBetween(
    prevBpSummary.systolic?.mean,
    bpSummary.systolic?.mean,
  );
  const diaChange = changeBetween(
    prevBpSummary.diastolic?.mean,
    bpSummary.diastolic?.mean,
  );

  const massUnit = profile?.preferredMassUnit ?? 'kg';
  const weightGoal = goals.find((g) => g.metricType === 'weight' && g.active);
  const goalProgress =
    weightGoal && weightSummary.latest && weightSummary.startingWeight
      ? computeGoalProgress({
          target: weightGoal.targetValue,
          current: weightSummary.latest.value,
          start: weightGoal.startValue ?? weightSummary.startingWeight,
        })
      : null;

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h1 className="type-headline m-0">Biometric Analytics</h1>
          <p
            className="m-0 text-xs"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            Long-term trends and guideline distribution computed locally.
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <SegmentedControl
          options={['blood_pressure', 'weight'] as const}
          selected={tab}
          onChange={setTab}
          ariaLabel="Analytics metric selector"
          labelBuilder={(opt) =>
            opt === 'blood_pressure' ? 'Blood Pressure' : 'Weight'
          }
        />
        <RangeSelector selected={rangeDays} onChange={setRangeDays} />
      </div>

      {tab === 'blood_pressure' ? (
        bpSummary.readingCount === 0 ? (
          <EmptyState
            title="No blood pressure readings"
            message="Log a blood pressure reading to see trends, the guideline distribution, and diurnal comparisons."
            actionLabel="Log blood pressure"
            onAction={() => router.push('/entry/blood-pressure')}
          />
        ) : (
          <div className="space-y-5">
            {/* 4 KPI Stat Tiles */}
            <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
              <StatTile
                label="Avg Systolic"
                value={
                  bpSummary.systolic
                    ? formatValue(bpSummary.systolic.mean, 0)
                    : '—'
                }
                unit="mmHg"
                accent="var(--metric-bp)"
                comparison={
                  sysChange
                    ? `${formatSigned(sysChange.absolute, 0)} mmHg vs prior`
                    : null
                }
              />
              <StatTile
                label="Avg Diastolic"
                value={
                  bpSummary.diastolic
                    ? formatValue(bpSummary.diastolic.mean, 0)
                    : '—'
                }
                unit="mmHg"
                accent="var(--color-secondary)"
                comparison={
                  diaChange
                    ? `${formatSigned(diaChange.absolute, 0)} mmHg vs prior`
                    : null
                }
              />
              <StatTile
                label="Latest"
                value={
                  bpSummary.latest
                    ? formatBloodPressure(
                        bpSummary.latest.value,
                        bpSummary.latest.secondaryValue,
                      )
                    : '—'
                }
                unit="mmHg"
                accent="var(--metric-bp)"
                comparison={
                  bpSummary.latest && getPulse(bpSummary.latest) !== null
                    ? `${formatValue(getPulse(bpSummary.latest)!, 0)} bpm resting`
                    : null
                }
              />
              <StatTile
                label="Total Volume"
                value={String(bpSummary.readingCount)}
                unit="logs"
                accent="var(--color-primary)"
                comparison={`${Math.round(bpSummary.completeness * 100)}% of days logged (${bpSummary.loggedDays}/${bpSummary.totalDays})`}
              />
            </div>

            {/* Trend Chart Card */}
            <AppCard className="space-y-3">
              <SectionHeader
                title="Mean Daily Fluctuations"
                subtitle={`Daily means over ${rangeDays} days (missing days shown as gaps, 120/80 mmHg reference)`}
              />
              <TrendChart
                title="Blood pressure daily trend"
                unit="mmHg"
                primaryLabel="Systolic"
                primaryColor="var(--metric-bp)"
                secondaryLabel="Diastolic"
                secondaryColor="var(--color-secondary)"
                precision={0}
                referenceLines={[
                  { value: 120, label: '120 systolic' },
                  { value: 80, label: '80 diastolic' },
                ]}
                data={bpSummary.contiguousSeries.map((pt) => ({
                  dateLabel: shortDateLabel(pt.day),
                  localDay: pt.localDay,
                  primary: pt.systolic,
                  secondary: pt.diastolic,
                }))}
                summaryText={`Blood pressure over the last ${rangeDays} days: ${bpSummary.readingCount} readings across ${bpSummary.loggedDays} logged days. Mean systolic ${bpSummary.systolic ? formatValue(bpSummary.systolic.mean, 0) : 'N/A'} mmHg, mean diastolic ${bpSummary.diastolic ? formatValue(bpSummary.diastolic.mean, 0) : 'N/A'} mmHg.`}
              />
            </AppCard>

            {/* Guideline Distribution Card */}
            <AppCard className="space-y-3">
              <SectionHeader
                title={`${bpSummary.guideline.name} Guideline Distribution`}
                subtitle={`Based on ${bpSummary.readingCount} readings in this ${rangeDays}-day window`}
              />
              <DistributionBar
                total={bpSummary.readingCount}
                segments={[
                  {
                    label: 'Normal',
                    count: bpSummary.distribution.normal,
                    color: 'var(--color-positive)',
                  },
                  {
                    label: 'Elevated',
                    count: bpSummary.distribution.elevated,
                    color: 'var(--color-warning)',
                  },
                  {
                    label: 'Stage 1',
                    count: bpSummary.distribution.stage_1_hypertension,
                    color: 'var(--color-critical)',
                  },
                  {
                    label: 'Stage 2',
                    count: bpSummary.distribution.stage_2_hypertension,
                    color: '#991b1b',
                  },
                  {
                    label: 'Crisis',
                    count: bpSummary.distribution.hypertensive_crisis,
                    color: '#450a0a',
                  },
                ]}
              />
            </AppCard>

            {/* Circadian Morning vs Evening Card */}
            <AppCard className="space-y-3">
              <SectionHeader
                title="Diurnal Comparison (Morning vs Evening)"
                subtitle="Morning (06:00–11:59) compared with Evening (18:00–23:59) local time"
              />
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                <div
                  style={{
                    backgroundColor: 'var(--color-surface-low)',
                    borderRadius: 'var(--radius-control)',
                  }}
                  className="p-3.5"
                >
                  <div className="flex items-center gap-2 text-xs font-semibold">
                    <Sun size={15} style={{ color: 'var(--color-tertiary)' }} />
                    <span>Morning (n = {bpSummary.morning.sampleCount})</span>
                  </div>
                  <div className="mt-1.5 type-title tabular-nums">
                    {bpSummary.morning.hasData && bpSummary.morning.systolic
                      ? `${formatBloodPressure(bpSummary.morning.systolic, bpSummary.morning.diastolic)} mmHg`
                      : 'No morning readings'}
                  </div>
                </div>
                <div
                  style={{
                    backgroundColor: 'var(--color-surface-low)',
                    borderRadius: 'var(--radius-control)',
                  }}
                  className="p-3.5"
                >
                  <div className="flex items-center gap-2 text-xs font-semibold">
                    <Moon size={15} style={{ color: 'var(--color-primary)' }} />
                    <span>Evening (n = {bpSummary.evening.sampleCount})</span>
                  </div>
                  <div className="mt-1.5 type-title tabular-nums">
                    {bpSummary.evening.hasData && bpSummary.evening.systolic
                      ? `${formatBloodPressure(bpSummary.evening.systolic, bpSummary.evening.diastolic)} mmHg`
                      : 'No evening readings'}
                  </div>
                </div>
              </div>
            </AppCard>

            {/* Deterministic Insights */}
            <AppCard className="space-y-3">
              <SectionHeader title="Observations from Your Data" />
              <div className="space-y-3">
                {bpInsightsList.map((ins) => (
                  <div
                    key={ins.id}
                    style={{
                      backgroundColor: 'var(--color-surface-low)',
                      borderRadius: 'var(--radius-control)',
                    }}
                    className="flex items-start gap-3 p-3.5 text-xs"
                  >
                    <Lightbulb
                      size={16}
                      style={{ color: 'var(--color-primary)' }}
                      className="mt-0.5 shrink-0"
                    />
                    <div className="space-y-1">
                      <div className="font-bold">{ins.title}</div>
                      <p className="m-0">{ins.body}</p>
                      {ins.limitation && (
                        <p
                          className="m-0 text-[11px] italic"
                          style={{ color: 'var(--color-on-surface-variant)' }}
                        >
                          {ins.limitation}
                        </p>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </AppCard>
          </div>
        )
      ) : !weightSummary.stats || weightSummary.stats.count === 0 ? (
        <EmptyState
          title="No weigh-ins yet"
          message="Log your weight to see daily trends, moving averages, and period comparisons."
          actionLabel="Log weight"
          onAction={() => router.push('/entry/weight')}
        />
      ) : (
        <div className="space-y-5">
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-3">
            <StatTile
              label="Current Weight"
              value={
                weightSummary.latest
                  ? formatValue(
                      convert(weightSummary.latest.value, 'kg', massUnit),
                      1,
                    )
                  : '—'
              }
              unit={massUnit}
              accent="var(--metric-weight)"
              comparison={
                weightSummary.changeFromPrevious
                  ? `${formatSigned(
                      convert(
                        weightSummary.changeFromPrevious.absolute,
                        'kg',
                        massUnit,
                      ),
                      1,
                    )} ${massUnit} vs prior period`
                  : null
              }
            />
            <StatTile
              label="Starting Baseline"
              value={
                weightSummary.startingWeight !== null
                  ? formatValue(
                      convert(weightSummary.startingWeight, 'kg', massUnit),
                      1,
                    )
                  : '—'
              }
              unit={massUnit}
              accent="var(--color-secondary)"
              comparison="First reading in this period"
            />
            <StatTile
              label="Consistency"
              value={`${weightSummary.loggedDays}/${weightSummary.totalDays}`}
              unit="days"
              accent="var(--color-primary)"
              comparison={`${Math.round(weightSummary.completeness * 100)}% of days logged`}
            />
          </div>

          {goalProgress && weightGoal && (
            <AppCard>
              <GoalMeter
                label="Weight Goal Progress"
                currentLabel={`${formatValue(convert(goalProgress.current, 'kg', massUnit), 1)} ${massUnit}`}
                targetLabel={`${formatValue(convert(goalProgress.target, 'kg', massUnit), 1)} ${massUnit}`}
                percentAchieved={goalProgress.percentAchieved}
              />
            </AppCard>
          )}

          <AppCard className="space-y-3">
            <SectionHeader
              title="Daily Weigh-ins & 7-Day Moving Average"
              subtitle={`Displayed in ${massUnit} (missing days rendered as gaps)`}
            />
            <TrendChart
              title="Weight trend"
              unit={massUnit}
              primaryLabel="Daily weight"
              primaryColor="var(--metric-weight)"
              secondaryLabel="Moving average"
              secondaryColor="var(--color-secondary)"
              precision={1}
              data={weightSummary.contiguousSeries.map((pt) => ({
                dateLabel: shortDateLabel(pt.day),
                localDay: pt.localDay,
                primary:
                  pt.weight !== null
                    ? convert(pt.weight, 'kg', massUnit)
                    : null,
                secondary:
                  pt.smoothing !== null
                    ? convert(pt.smoothing, 'kg', massUnit)
                    : null,
              }))}
              summaryText={`Weight over the last ${rangeDays} days: ${weightSummary.stats.count} weigh-ins across ${weightSummary.loggedDays} days. Mean weight ${formatValue(convert(weightSummary.stats.mean, 'kg', massUnit), 1)} ${massUnit}.`}
            />
          </AppCard>

          <AppCard className="space-y-3">
            <SectionHeader title="Observations from Your Data" />
            <div className="space-y-3">
              {weightInsightsList.map((ins) => (
                <div
                  key={ins.id}
                  style={{
                    backgroundColor: 'var(--color-surface-low)',
                    borderRadius: 'var(--radius-control)',
                  }}
                  className="flex items-start gap-3 p-3.5 text-xs"
                >
                  <Lightbulb
                    size={16}
                    style={{ color: 'var(--color-primary)' }}
                    className="mt-0.5 shrink-0"
                  />
                  <div className="space-y-1">
                    <div className="font-bold">{ins.title}</div>
                    <p className="m-0">{ins.body}</p>
                    {ins.limitation && (
                      <p
                        className="m-0 text-[11px] italic"
                        style={{ color: 'var(--color-on-surface-variant)' }}
                      >
                        {ins.limitation}
                      </p>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </AppCard>
        </div>
      )}
    </div>
  );
}
