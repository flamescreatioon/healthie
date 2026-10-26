'use client';

/**
 * Home Dashboard Screen (`docs/web/06-visualization.md` &
 * `lib/features/dashboard/presentation/home_screen.dart`).
 *
 * - Answers "how am I doing?" from stored local measurements.
 * - Includes loading, empty, and error states.
 * - Shows medical disclaimer where readings appear.
 */

import React from 'react';
import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import {
  Activity,
  Calendar,
  CheckCircle2,
  Circle,
  Flame,
  Lightbulb,
  Plus,
  ShieldCheck,
} from 'lucide-react';
import {
  BP_CATEGORIES,
  classifyBloodPressure,
  computeDescriptiveStats,
  convert,
  dashboardInsight,
  dateRangeEndingOn,
  formatBloodPressure,
  formatSigned,
  formatValue,
  getPulse,
  isSameLocalDay,
  longDayLabel,
  type Measurement,
  previousDateRange,
  startOfLocalDay,
  summariseBloodPressure,
  timestampLabel,
  toLocalDayString,
} from '@/domain';
import { useRepositories } from '@/components/providers/app-providers';
import {
  AppCard,
  EmptyState,
  ErrorState,
  LoadingState,
  MetricBadge,
  StatusPill,
} from '@/components/ui/primitives';
import { Sparkline } from '@/components/charts/charts';

function greetingFor(now: Date, displayName?: string | null): string {
  const h = now.getHours();
  const base =
    h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
  const trimmed = displayName?.trim();
  return trimmed ? `${base}, ${trimmed}` : base;
}

function computeStreak(measurements: readonly Measurement[], now: Date): number {
  const loggedDays = new Set(
    measurements.map((m) => toLocalDayString(new Date(m.recordedAt))),
  );
  let streak = 0;
  let cursor = startOfLocalDay(now);
  if (!loggedDays.has(toLocalDayString(cursor))) {
    cursor = new Date(
      cursor.getFullYear(),
      cursor.getMonth(),
      cursor.getDate() - 1,
    );
  }
  while (loggedDays.has(toLocalDayString(cursor))) {
    streak += 1;
    cursor = new Date(
      cursor.getFullYear(),
      cursor.getMonth(),
      cursor.getDate() - 1,
    );
  }
  return streak;
}

export function DashboardView() {
  const { measurements: measurementRepo, profile: profileRepo, reminders: reminderRepo, clock } =
    useRepositories();
  const now = clock.now();

  const {
    data: measurements,
    isLoading,
    isError,
    refetch,
  } = useQuery({
    queryKey: ['measurements', 'dashboard'],
    queryFn: () =>
      measurementRepo.list({
        range: dateRangeEndingOn(now, 60),
      }),
  });

  const { data: profile } = useQuery({
    queryKey: ['profile'],
    queryFn: () => profileRepo.getProfile(),
  });

  const { data: reminders = [] } = useQuery({
    queryKey: ['reminders'],
    queryFn: () => reminderRepo.listReminders(),
  });

  if (isLoading) {
    return <LoadingState lines={5} label="Loading your health dashboard…" />;
  }

  if (isError || !measurements) {
    return (
      <ErrorState
        message="We couldn't load your readings."
        onRetry={() => void refetch()}
      />
    );
  }

  const bpList = measurements.filter((m) => m.metricType === 'blood_pressure');
  const weightList = measurements.filter((m) => m.metricType === 'weight');
  const hrList = measurements.filter((m) => m.metricType === 'heart_rate');
  const spo2List = measurements.filter((m) => m.metricType === 'spo2');

  const latestBp = bpList[0] ?? null;
  const latestWeight = weightList[0] ?? null;
  const latestHr = hrList[0] ?? null;
  const latestSpo2 = spo2List[0] ?? null;

  const period30 = dateRangeEndingOn(now, 30);
  const prevPeriod30 = previousDateRange(period30);

  const bpSummary = summariseBloodPressure({
    period: period30,
    measurements: bpList.filter(
      (m) => new Date(m.recordedAt).getTime() >= period30.start.getTime(),
    ),
  });
  const prevBpSummary = summariseBloodPressure({
    period: prevPeriod30,
    measurements: bpList.filter((m) => {
      const t = new Date(m.recordedAt).getTime();
      return t >= prevPeriod30.start.getTime() && t < prevPeriod30.end.getTime();
    }),
  });
  const insight = dashboardInsight({
    current: bpSummary,
    previous: prevBpSummary,
  });

  const streak = computeStreak(measurements, now);
  const preferredMassUnit = profile?.preferredMassUnit ?? 'kg';

  const latestBpCategory =
    latestBp && latestBp.secondaryValue !== null && latestBp.secondaryValue !== undefined
      ? classifyBloodPressure({
          systolic: Math.round(latestBp.value),
          diastolic: Math.round(latestBp.secondaryValue),
        })
      : null;

  const recentBp7 = bpSummary.contiguousSeries.slice(-7);
  const systolicSparkline = recentBp7.map((d) => d.systolic);
  const diastolicSparkline = recentBp7.map((d) => d.diastolic);

  const weightValues7 = weightList
    .slice(0, 7)
    .reverse()
    .map((m) => convert(m.value, 'kg', preferredMassUnit));
  const previousWeight = weightList[1] ?? null;
  const weightDelta =
    latestWeight && previousWeight
      ? convert(latestWeight.value - previousWeight.value, 'kg', preferredMassUnit)
      : null;

  const hr7Stats = computeDescriptiveStats(hrList.slice(0, 7).map((m) => m.value));

  const loggedTodayTypes = new Set(
    measurements
      .filter((m) => isSameLocalDay(new Date(m.recordedAt), now))
      .map((m) => m.metricType),
  );

  return (
    <div className="space-y-5">
      {/* Top Greeting Header */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <div
            className="flex items-center gap-1.5 text-xs font-semibold"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            <Calendar
              size={14}
              style={{ color: 'var(--color-tertiary)' }}
              aria-hidden="true"
            />
            <span>{longDayLabel(now)}</span>
          </div>
          <h1 className="type-headline m-0 mt-0.5">
            {greetingFor(now, profile?.displayName)}
          </h1>
        </div>

        {/* Quick Actions */}
        <div className="flex flex-wrap items-center gap-2">
          <Link
            href="/entry/blood-pressure"
            style={{
              backgroundColor: 'var(--color-primary)',
              color: 'var(--color-on-primary)',
              borderRadius: 'var(--radius-pill)',
            }}
            className="inline-flex items-center gap-1.5 px-4 py-2 text-xs font-semibold no-underline"
          >
            <Plus size={15} aria-hidden="true" />
            <span>Log BP</span>
          </Link>
          <Link
            href="/entry/weight"
            style={{
              backgroundColor: 'var(--color-surface-lowest)',
              color: 'var(--color-primary)',
              border: '1px solid var(--color-outline-variant)',
              borderRadius: 'var(--radius-pill)',
            }}
            className="inline-flex items-center gap-1.5 px-4 py-2 text-xs font-semibold no-underline"
          >
            <Plus size={15} aria-hidden="true" />
            <span>Log Weight</span>
          </Link>
          <Link
            href="/track"
            style={{
              backgroundColor: 'var(--color-surface-lowest)',
              color: 'var(--color-primary)',
              border: '1px solid var(--color-outline-variant)',
              borderRadius: 'var(--radius-pill)',
            }}
            className="inline-flex items-center gap-1.5 px-4 py-2 text-xs font-semibold no-underline"
          >
            <Plus size={15} aria-hidden="true" />
            <span>Log Glucose</span>
          </Link>
        </div>
      </div>

      {/* Streak Banner */}
      {streak >= 2 && (
        <div
          style={{
            backgroundColor: 'var(--color-tertiary-container)',
            color: 'var(--color-on-tertiary-container)',
            borderRadius: 'var(--radius-card)',
          }}
          className="flex items-center gap-3 p-3.5 text-xs font-medium"
        >
          <Flame size={18} aria-hidden="true" />
          <span>
            You are on a <strong>{streak}-day streak</strong> of prompt tracking!
          </span>
        </div>
      )}

      {/* Today's Protocol Checklist (when reminders exist) */}
      {reminders.length > 0 && (
        <AppCard className="space-y-3">
          <div className="flex items-center justify-between">
            <span
              className="type-micro"
              style={{ color: 'var(--color-on-surface-variant)' }}
            >
              Today&apos;s Protocol
            </span>
            <span
              className="text-xs font-semibold"
              style={{ color: 'var(--color-secondary)' }}
            >
              {
                reminders.filter((r) => loggedTodayTypes.has(r.metricType))
                  .length
              }{' '}
              of {reminders.length} complete
            </span>
          </div>
          <div className="space-y-2">
            {reminders.slice(0, 4).map((rem) => {
              const done = loggedTodayTypes.has(rem.metricType);
              return (
                <div
                  key={rem.id}
                  className="flex items-center justify-between text-xs"
                >
                  <span className="flex items-center gap-2 font-medium">
                    {done ? (
                      <CheckCircle2
                        size={16}
                        style={{ color: 'var(--color-secondary)' }}
                      />
                    ) : (
                      <Circle
                        size={16}
                        style={{ color: 'var(--color-outline)' }}
                      />
                    )}
                    <span>{rem.title}</span>
                  </span>
                  <span
                    className="tabular-nums"
                    style={{ color: 'var(--color-on-surface-variant)' }}
                  >
                    {String(rem.hour).padStart(2, '0')}:
                    {String(rem.minute).padStart(2, '0')}
                  </span>
                </div>
              );
            })}
          </div>
        </AppCard>
      )}

      {/* Main Grid: Blood Pressure & Weight Cards */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        {/* Blood Pressure Card */}
        {!latestBp ? (
          <EmptyState
            title="Blood Pressure"
            message="No blood pressure readings yet. Log your first reading to start building a trend."
            actionLabel="Log blood pressure"
            onAction={() => {
              window.location.href = '/entry/blood-pressure';
            }}
          />
        ) : (
          <AppCard elevated padding="p-6" className="space-y-4">
            <div className="flex items-start justify-between gap-3">
              <div className="flex items-center gap-3">
                <MetricBadge metric="blood_pressure" size={42} />
                <div>
                  <h2 className="type-title m-0">Blood Pressure</h2>
                  <p
                    className="m-0 text-xs"
                    style={{ color: 'var(--color-on-surface-variant)' }}
                  >
                    {timestampLabel(new Date(latestBp.recordedAt), now)}
                  </p>
                </div>
              </div>
              {latestBpCategory && (
                <StatusPill
                  label={BP_CATEGORIES[latestBpCategory].shortLabel}
                  tone={
                    latestBpCategory === 'normal'
                      ? 'positive'
                      : latestBpCategory === 'elevated' ||
                          latestBpCategory === 'stage_1_hypertension'
                        ? 'warning'
                        : 'critical'
                  }
                />
              )}
            </div>

            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <div className="flex items-baseline gap-2">
                <span className="type-display tabular-nums">
                  {formatBloodPressure(latestBp.value, latestBp.secondaryValue)}
                </span>
                <span
                  className="text-xs font-medium"
                  style={{ color: 'var(--color-on-surface-variant)' }}
                >
                  mmHg
                </span>
              </div>
              {getPulse(latestBp) !== null && (
                <span
                  style={{
                    backgroundColor: 'var(--color-surface-low)',
                    borderRadius: 'var(--radius-control)',
                  }}
                  className="px-2.5 py-1 text-xs font-semibold tabular-nums"
                >
                  ♥ {formatValue(getPulse(latestBp)!, 0)} bpm
                </span>
              )}
            </div>

            <div
              style={{
                backgroundColor: 'var(--color-surface-low)',
                borderRadius: 'var(--radius-control)',
              }}
              className="p-3"
            >
              <div className="flex items-center justify-between text-[11px] font-semibold">
                <span style={{ color: 'var(--color-on-surface-variant)' }}>
                  7-DAY DUAL TREND (SYS / DIA)
                </span>
                <span style={{ color: 'var(--color-secondary)' }}>
                  {bpSummary.loggedDays}d logged
                </span>
              </div>
              <div className="mt-2 grid grid-cols-2 gap-3">
                <Sparkline
                  values={systolicSparkline}
                  color="var(--metric-bp)"
                  ariaLabel="7-day systolic sparkline"
                />
                <Sparkline
                  values={diastolicSparkline}
                  color="var(--color-secondary)"
                  ariaLabel="7-day diastolic sparkline"
                />
              </div>
            </div>

            <div className="flex items-center gap-2 pt-1">
              <Link
                href="/entry/blood-pressure"
                style={{
                  backgroundColor: 'var(--color-primary)',
                  color: 'var(--color-on-primary)',
                  borderRadius: 'var(--radius-control)',
                }}
                className="touch-target flex flex-1 items-center justify-center px-4 py-2.5 text-xs font-semibold no-underline"
              >
                Log blood pressure
              </Link>
              <Link
                href="/analytics"
                style={{
                  border: '1px solid var(--color-outline-variant)',
                  color: 'var(--color-primary)',
                  borderRadius: 'var(--radius-control)',
                }}
                className="touch-target flex items-center justify-center px-4 py-2.5 text-xs font-semibold no-underline"
              >
                Analytics
              </Link>
            </div>
          </AppCard>
        )}

        {/* Weight Card */}
        {!latestWeight ? (
          <EmptyState
            title="Body Weight"
            message="No weigh-ins yet. Record your weight to track daily and weekly trends."
            actionLabel="Log weight"
            onAction={() => {
              window.location.href = '/entry/weight';
            }}
          />
        ) : (
          <AppCard elevated padding="p-6" className="space-y-4">
            <div className="flex items-start justify-between gap-3">
              <div className="flex items-center gap-3">
                <MetricBadge metric="weight" size={42} />
                <div>
                  <h2 className="type-title m-0">Body Weight</h2>
                  <p
                    className="m-0 text-xs"
                    style={{ color: 'var(--color-on-surface-variant)' }}
                  >
                    {timestampLabel(new Date(latestWeight.recordedAt), now)}
                  </p>
                </div>
              </div>
              {weightDelta !== null && (
                <StatusPill
                  label={`${formatSigned(weightDelta, 1)} ${preferredMassUnit} vs last`}
                  tone="neutral"
                  dense
                />
              )}
            </div>

            <div className="flex items-baseline gap-2">
              <span className="type-display tabular-nums">
                {formatValue(
                  convert(latestWeight.value, 'kg', preferredMassUnit),
                  1,
                )}
              </span>
              <span
                className="text-xs font-medium"
                style={{ color: 'var(--color-on-surface-variant)' }}
              >
                {preferredMassUnit}
              </span>
            </div>

            <div
              style={{
                backgroundColor: 'var(--color-surface-low)',
                borderRadius: 'var(--radius-control)',
              }}
              className="p-3"
            >
              <div className="flex items-center justify-between text-[11px] font-semibold">
                <span style={{ color: 'var(--color-on-surface-variant)' }}>
                  RECENT WEIGH-INS
                </span>
                <span style={{ color: 'var(--color-secondary)' }}>
                  {weightList.length} logs
                </span>
              </div>
              <div className="mt-2">
                <Sparkline
                  values={weightValues7}
                  color="var(--metric-weight)"
                  ariaLabel="Recent weight sparkline"
                />
              </div>
            </div>

            <div className="flex items-center gap-2 pt-1">
              <Link
                href="/entry/weight"
                style={{
                  backgroundColor: 'var(--color-primary)',
                  color: 'var(--color-on-primary)',
                  borderRadius: 'var(--radius-control)',
                }}
                className="touch-target flex flex-1 items-center justify-center px-4 py-2.5 text-xs font-semibold no-underline"
              >
                Log weight
              </Link>
              <Link
                href="/analytics"
                style={{
                  border: '1px solid var(--color-outline-variant)',
                  color: 'var(--color-primary)',
                  borderRadius: 'var(--radius-control)',
                }}
                className="touch-target flex items-center justify-center px-4 py-2.5 text-xs font-semibold no-underline"
              >
                Analytics
              </Link>
            </div>
          </AppCard>
        )}
      </div>

      {/* Secondary Compact Stat Cards: Resting HR & SpO2 */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <AppCard className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <MetricBadge metric="heart_rate" />
            <div>
              <div
                className="type-micro"
                style={{ color: 'var(--color-on-surface-variant)' }}
              >
                Resting HR
              </div>
              <div className="mt-0.5 flex items-baseline gap-1.5">
                <span className="type-title tabular-nums">
                  {latestHr ? formatValue(latestHr.value, 0) : '—'}
                </span>
                <span
                  className="text-xs"
                  style={{ color: 'var(--color-on-surface-variant)' }}
                >
                  bpm
                </span>
              </div>
              {hr7Stats && (
                <div
                  className="text-[11px] tabular-nums"
                  style={{ color: 'var(--color-secondary)' }}
                >
                  7d avg: {formatValue(hr7Stats.mean, 0)} bpm
                </div>
              )}
            </div>
          </div>
          <Link
            href="/metric/heart_rate"
            style={{ color: 'var(--color-primary)' }}
            className="text-xs font-semibold no-underline"
          >
            Log →
          </Link>
        </AppCard>

        <AppCard className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <MetricBadge metric="spo2" />
            <div>
              <div
                className="type-micro"
                style={{ color: 'var(--color-on-surface-variant)' }}
              >
                Blood Oxygen
              </div>
              <div className="mt-0.5 flex items-baseline gap-1.5">
                <span className="type-title tabular-nums">
                  {latestSpo2 ? formatValue(latestSpo2.value, 0) : '—'}
                </span>
                <span
                  className="text-xs"
                  style={{ color: 'var(--color-on-surface-variant)' }}
                >
                  % SpO₂
                </span>
              </div>
              {latestSpo2 && (
                <div
                  className="text-[11px]"
                  style={{ color: 'var(--color-on-surface-variant)' }}
                >
                  Measured {timestampLabel(new Date(latestSpo2.recordedAt), now)}
                </div>
              )}
            </div>
          </div>
          <Link
            href="/metric/spo2"
            style={{ color: 'var(--color-primary)' }}
            className="text-xs font-semibold no-underline"
          >
            Log →
          </Link>
        </AppCard>
      </div>

      {/* Deterministic Observation / Insight Card */}
      <AppCard className="flex items-start gap-3">
        <div
          style={{
            backgroundColor: 'var(--color-primary-container)',
            color: 'var(--color-on-primary-container)',
          }}
          className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full"
        >
          <Lightbulb size={18} aria-hidden="true" />
        </div>
        <div className="space-y-1">
          <div className="type-title text-sm">{insight.title}</div>
          <p
            className="m-0 text-xs leading-relaxed"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            {insight.body}
          </p>
          {insight.limitation && (
            <p
              className="m-0 text-[11px] italic"
              style={{ color: 'var(--color-on-surface-variant)' }}
            >
              {insight.limitation}
            </p>
          )}
        </div>
      </AppCard>

      {/* Medical Disclaimer (`docs/web/08-privacy-compliance.md`) */}
      <div
        style={{ color: 'var(--color-on-surface-variant)' }}
        className="flex items-center justify-center gap-2 pt-2 text-center text-xs"
      >
        <ShieldCheck size={15} aria-hidden="true" />
        <span>
          Healthie is a personal health tracker, not a medical device. Readings
          and AHA/ACC 2017 categories are informational and never replace
          professional medical advice.
        </span>
      </div>
    </div>
  );
}
