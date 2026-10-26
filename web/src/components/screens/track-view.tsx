'use client';

/**
 * Track Metric Hub Screen (`lib/features/track/presentation/track_screen.dart`).
 *
 * Shows all 6 catalog metrics, their latest reading, and one-tap logging links.
 */

import React from 'react';
import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { Plus } from 'lucide-react';
import {
  ALL_METRIC_SPECS,
  dateRangeEndingOn,
  formatBloodPressure,
  formatValue,
  type Measurement,
  type MetricWireName,
  timestampLabel,
} from '@/domain';
import { useRepositories } from '@/components/providers/app-providers';
import {
  AppCard,
  EmptyState,
  ErrorState,
  LoadingState,
  MetricBadge,
  SectionHeader,
} from '@/components/ui/primitives';

function entryHrefFor(wireName: MetricWireName): string {
  if (wireName === 'blood_pressure') return '/entry/blood-pressure';
  if (wireName === 'weight') return '/entry/weight';
  return `/metric/${wireName}`;
}

function formatLatest(m: Measurement): string {
  if (m.metricType === 'blood_pressure') {
    return `${formatBloodPressure(m.value, m.secondaryValue)} mmHg`;
  }
  const spec = ALL_METRIC_SPECS.find((s) => s.wireName === m.metricType);
  return `${formatValue(m.value, spec?.precision ?? 0)} ${m.unit}`;
}

export function TrackView() {
  const { measurements: repo, clock } = useRepositories();
  const now = clock.now();

  const {
    data: measurements,
    isLoading,
    isError,
    refetch,
  } = useQuery({
    queryKey: ['measurements', 'track'],
    queryFn: () => repo.list({ range: dateRangeEndingOn(now, 90) }),
  });

  if (isLoading) {
    return <LoadingState lines={4} label="Loading metrics…" />;
  }

  if (isError || !measurements) {
    return (
      <ErrorState
        message="We couldn't load your measurements."
        onRetry={() => void refetch()}
      />
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="type-headline m-0">Record a measurement</h1>
        <p
          className="m-0 mt-1 text-xs"
          style={{ color: 'var(--color-on-surface-variant)' }}
        >
          Everything here can be recorded offline without granting a single
          device permission.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        {ALL_METRIC_SPECS.map((spec) => {
          const latest =
            measurements.find((m) => m.metricType === spec.wireName) ?? null;
          return (
            <AppCard
              key={spec.wireName}
              className="flex items-start gap-3.5 justify-between"
            >
              <div className="flex items-start gap-3.5">
                <MetricBadge metric={spec.wireName} size={44} />
                <div className="space-y-1">
                  <div className="flex items-center gap-2">
                    <h2 className="type-title m-0">{spec.displayName}</h2>
                    {latest && (
                      <span
                        className="text-xs font-bold tabular-nums"
                        style={{ color: 'var(--color-primary)' }}
                      >
                        {formatLatest(latest)}
                      </span>
                    )}
                  </div>
                  <p
                    className="m-0 text-xs"
                    style={{ color: 'var(--color-on-surface-variant)' }}
                  >
                    {spec.description}
                  </p>
                  <div className="pt-2">
                    <Link
                      href={entryHrefFor(spec.wireName)}
                      style={{
                        backgroundColor: 'var(--color-primary)',
                        color: 'var(--color-on-primary)',
                        borderRadius: 'var(--radius-control)',
                      }}
                      className="inline-flex items-center gap-1.5 px-4 py-2 text-xs font-semibold no-underline"
                    >
                      <Plus size={15} aria-hidden="true" />
                      <span>Log</span>
                    </Link>
                  </div>
                </div>
              </div>
            </AppCard>
          );
        })}
      </div>

      <div className="space-y-3">
        <SectionHeader title="Latest readings" />
        {measurements.length === 0 ? (
          <EmptyState
            title="Nothing recorded yet"
            message="Your most recent readings will appear here once you record them."
          />
        ) : (
          <AppCard className="divide-y divide-[var(--color-outline-variant)]">
            {measurements.slice(0, 12).map((m) => {
              const spec = ALL_METRIC_SPECS.find(
                (s) => s.wireName === m.metricType,
              );
              return (
                <div
                  key={m.id}
                  className="flex items-center justify-between py-2.5 text-sm first:pt-0 last:pb-0"
                >
                  <div className="flex items-center gap-2.5">
                    <span className="font-semibold">
                      {spec?.displayName ?? m.metricType}
                    </span>
                    <span
                      className="text-xs font-bold tabular-nums"
                      style={{ color: 'var(--color-on-surface-variant)' }}
                    >
                      {formatLatest(m)}
                    </span>
                  </div>
                  <span
                    className="text-xs tabular-nums"
                    style={{ color: 'var(--color-on-surface-variant)' }}
                  >
                    {timestampLabel(new Date(m.recordedAt), now)}
                  </span>
                </div>
              );
            })}
          </AppCard>
        )}
      </div>
    </div>
  );
}
