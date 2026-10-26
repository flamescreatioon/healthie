'use client';

/**
 * Historical Records Screen (`lib/features/history/presentation/history_screen.dart`
 * & `docs/web/08-privacy-compliance.md`).
 *
 * - Searchable, filterable audit trail grouped by local calendar day.
 * - Edit links use record IDs only (`/entry/blood-pressure?edit=<id>`), never
 *   health values in URLs.
 * - Deletion is soft (`deletedAt` tombstone) with an immediate Undo toast.
 * - Offline client-side CSV & JSON export with schema version.
 */

import React, { useState } from 'react';
import Link from 'next/link';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import {
  Download,
  Edit3,
  Search,
  ShieldCheck,
  Trash2,
  X,
} from 'lucide-react';
import {
  ALL_METRIC_SPECS,
  BP_CATEGORIES,
  classifyBloodPressure,
  dateRangeEndingOn,
  formatBloodPressure,
  formatValue,
  getPulse,
  type Measurement,
  mediumDateLabel,
  parseLocalDay,
  relativeDayLabel,
  timestampLabel,
} from '@/domain';
import { buildCsvExport, buildJsonExport } from '@/data/export';
import { useAppContext, useRepositories } from '@/components/providers/app-providers';
import {
  AppCard,
  EmptyState,
  ErrorState,
  LoadingState,
  MetricBadge,
  SelectableChip,
  StatusPill,
} from '@/components/ui/primitives';

type HistoryFilterOption =
  | 'all'
  | 'blood_pressure'
  | 'weight'
  | 'heart_rate'
  | 'blood_glucose';

const FILTER_OPTIONS: readonly { id: HistoryFilterOption; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'blood_pressure', label: 'Blood Pressure' },
  { id: 'weight', label: 'Weight' },
  { id: 'heart_rate', label: 'Heart Rate' },
  { id: 'blood_glucose', label: 'Glucose' },
] as const;

function editHrefFor(m: Measurement): string {
  if (m.metricType === 'blood_pressure') {
    return `/entry/blood-pressure?edit=${encodeURIComponent(m.id)}`;
  }
  if (m.metricType === 'weight') {
    return `/entry/weight?edit=${encodeURIComponent(m.id)}`;
  }
  return `/metric/${m.metricType}?record=${encodeURIComponent(m.id)}`;
}

export function HistoryView() {
  const queryClient = useQueryClient();
  const { measurements: repo, profile: profileRepo, clock } = useRepositories();
  const { showUndoToast, syncEnabled, triggerSync } = useAppContext();
  const now = clock.now();

  const [filter, setFilter] = useState<HistoryFilterOption>('all');
  const [query, setQuery] = useState('');
  const [exportPreview, setExportPreview] = useState<{
    format: 'csv' | 'json';
    content: string;
  } | null>(null);

  const {
    data: measurements,
    isLoading,
    isError,
    refetch,
  } = useQuery({
    queryKey: ['measurements', 'history'],
    queryFn: () => repo.list({ range: dateRangeEndingOn(now, 3650) }),
  });

  if (isLoading) {
    return <LoadingState lines={5} label="Loading your health history…" />;
  }

  if (isError || !measurements) {
    return (
      <ErrorState
        message="We couldn't load your history."
        onRetry={() => void refetch()}
      />
    );
  }

  const lowered = query.trim().toLowerCase();
  const filtered = measurements.filter((m) => {
    if (filter !== 'all' && m.metricType !== filter) return false;
    if (!lowered) return true;
    const haystack = [
      String(m.value),
      m.secondaryValue !== null && m.secondaryValue !== undefined
        ? String(m.secondaryValue)
        : '',
      m.metricType,
      m.context.notes ?? '',
      m.context.posture ?? '',
      m.context.arm ?? '',
      ...(m.context.circumstances ?? []),
    ]
      .join(' ')
      .toLowerCase();
    return haystack.includes(lowered);
  });

  // Group by stored `localDay` (`YYYY-MM-DD`) descending
  const groupsMap = new Map<string, Measurement[]>();
  for (const m of filtered) {
    const list = groupsMap.get(m.localDay) ?? [];
    list.push(m);
    groupsMap.set(m.localDay, list);
  }
  const dayGroups = [...groupsMap.entries()].sort(([a], [b]) =>
    b.localeCompare(a),
  );

  const handleSoftDelete = async (m: Measurement) => {
    const deletedAtIso = clock.now().toISOString();
    await repo.softDelete(m.id, deletedAtIso);
    await queryClient.invalidateQueries();
    if (syncEnabled) {
      void triggerSync();
    }
    showUndoToast({
      id: m.id,
      message: 'Record deleted',
      onUndo: async () => {
        await repo.restore(m.id, clock.now().toISOString());
        await queryClient.invalidateQueries();
        if (syncEnabled) {
          void triggerSync();
        }
      },
    });
  };

  const handleExport = async (format: 'csv' | 'json') => {
    if (format === 'csv') {
      const content = buildCsvExport(filtered);
      setExportPreview({ format: 'csv', content });
      triggerFileDownload(content, 'healthie-measurements.csv', 'text/csv');
    } else {
      const profile = await profileRepo.getProfile();
      const goals = await profileRepo.listGoals();
      const content = buildJsonExport({
        measurements: filtered,
        profile,
        goals,
        exportedAtIso: clock.now().toISOString(),
      });
      setExportPreview({ format: 'json', content });
      triggerFileDownload(
        content,
        'healthie-export.json',
        'application/json',
      );
    }
  };

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2.5">
          <h1 className="type-headline m-0">Health History</h1>
          <StatusPill label={`${filtered.length} logs`} tone="neutral" dense />
        </div>
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => void handleExport('csv')}
            style={{
              border: '1px solid var(--color-outline-variant)',
              color: 'var(--color-primary)',
              borderRadius: 'var(--radius-control)',
            }}
            className="inline-flex cursor-pointer items-center gap-1.5 px-3 py-2 text-xs font-semibold"
          >
            <Download size={14} aria-hidden="true" />
            <span>Export CSV</span>
          </button>
          <button
            type="button"
            onClick={() => void handleExport('json')}
            style={{
              border: '1px solid var(--color-outline-variant)',
              color: 'var(--color-primary)',
              borderRadius: 'var(--radius-control)',
            }}
            className="inline-flex cursor-pointer items-center gap-1.5 px-3 py-2 text-xs font-semibold"
          >
            <Download size={14} aria-hidden="true" />
            <span>Export JSON</span>
          </button>
        </div>
      </div>

      {/* Search & Filter Controls */}
      <div className="space-y-3">
        <div className="relative">
          <Search
            size={18}
            style={{ color: 'var(--color-on-surface-variant)' }}
            className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2"
          />
          <input
            type="search"
            aria-label="Search records, notes, tags"
            placeholder="Search records, notes, tags…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            style={{
              backgroundColor: 'var(--color-surface-lowest)',
              border: '1px solid var(--color-outline-variant)',
              borderRadius: 'var(--radius-control)',
              color: 'var(--color-on-surface)',
            }}
            className="touch-target w-full pl-10 pr-10 py-2.5 text-sm"
          />
          {query && (
            <button
              type="button"
              aria-label="Clear search"
              onClick={() => setQuery('')}
              className="absolute right-3 top-1/2 -translate-y-1/2 cursor-pointer p-1"
            >
              <X size={16} />
            </button>
          )}
        </div>

        <div className="flex flex-wrap gap-2">
          {FILTER_OPTIONS.map((opt) => (
            <SelectableChip
              key={opt.id}
              label={opt.label}
              selected={filter === opt.id}
              onClick={() => setFilter(opt.id)}
            />
          ))}
        </div>
      </div>

      {exportPreview && (
        <AppCard className="space-y-2">
          <div className="flex items-center justify-between">
            <span className="type-title text-sm">
              Offline {exportPreview.format.toUpperCase()} Export Preview
            </span>
            <button
              type="button"
              aria-label="Close export preview"
              onClick={() => setExportPreview(null)}
              className="cursor-pointer p-1"
            >
              <X size={16} />
            </button>
          </div>
          <pre
            style={{
              backgroundColor: 'var(--color-surface-low)',
              borderRadius: 'var(--radius-control)',
            }}
            className="max-h-48 overflow-auto p-3 text-xs tabular-nums"
          >
            {exportPreview.content}
          </pre>
        </AppCard>
      )}

      {filtered.length === 0 ? (
        <EmptyState
          title={
            measurements.length === 0
              ? 'No records yet'
              : 'No matching records'
          }
          message={
            measurements.length === 0
              ? 'Log your first blood pressure reading or weigh-in to start building your history.'
              : 'Try a different search term or filter.'
          }
          actionLabel={measurements.length === 0 ? 'Log a reading' : undefined}
          onAction={
            measurements.length === 0
              ? () => {
                  window.location.href = '/entry/blood-pressure';
                }
              : undefined
          }
        />
      ) : (
        <div className="space-y-6">
          {dayGroups.map(([localDayKey, entries]) => {
            const dayDate = parseLocalDay(localDayKey);
            return (
              <section key={localDayKey} className="space-y-2.5">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2.5">
                    <span
                      style={{
                        width: 10,
                        height: 10,
                        borderRadius: '9999px',
                        backgroundColor: 'var(--color-primary)',
                      }}
                      aria-hidden="true"
                    />
                    <h2 className="type-title m-0 text-base">
                      {relativeDayLabel(dayDate, now)} —{' '}
                      {mediumDateLabel(dayDate)}
                    </h2>
                  </div>
                  <span
                    className="type-micro"
                    style={{ color: 'var(--color-on-surface-variant)' }}
                  >
                    {entries.length} {entries.length === 1 ? 'ENTRY' : 'ENTRIES'}
                  </span>
                </div>

                <div className="space-y-2.5">
                  {entries.map((m) => {
                    const spec = ALL_METRIC_SPECS.find(
                      (s) => s.wireName === m.metricType,
                    );
                    const bpCategory =
                      m.metricType === 'blood_pressure' &&
                      m.secondaryValue !== null &&
                      m.secondaryValue !== undefined
                        ? classifyBloodPressure({
                            systolic: Math.round(m.value),
                            diastolic: Math.round(m.secondaryValue),
                          })
                        : null;

                    return (
                      <AppCard
                        key={m.id}
                        className="flex items-start justify-between gap-3"
                      >
                        <div className="flex items-start gap-3">
                          <MetricBadge metric={m.metricType} />
                          <div>
                            <div className="flex flex-wrap items-center gap-2">
                              <span
                                className="type-micro"
                                style={{
                                  color: 'var(--color-on-surface-variant)',
                                }}
                              >
                                {spec?.displayName ?? m.metricType}
                              </span>
                              {bpCategory && (
                                <StatusPill
                                  label={BP_CATEGORIES[bpCategory].shortLabel}
                                  tone={
                                    bpCategory === 'normal'
                                      ? 'positive'
                                      : bpCategory === 'elevated' ||
                                          bpCategory === 'stage_1_hypertension'
                                        ? 'warning'
                                        : 'critical'
                                  }
                                  dense
                                />
                              )}
                            </div>

                            <div className="mt-1 flex items-baseline gap-1.5">
                              <span className="type-display text-2xl tabular-nums">
                                {m.metricType === 'blood_pressure'
                                  ? formatBloodPressure(
                                      m.value,
                                      m.secondaryValue,
                                    )
                                  : formatValue(m.value, spec?.precision ?? 0)}
                              </span>
                              <span
                                className="text-xs font-medium"
                                style={{
                                  color: 'var(--color-on-surface-variant)',
                                }}
                              >
                                {m.unit}
                              </span>
                            </div>

                            <div
                              className="mt-1 text-xs"
                              style={{
                                color: 'var(--color-on-surface-variant)',
                              }}
                            >
                              {[
                                timestampLabel(new Date(m.recordedAt), now),
                                getPulse(m) !== null
                                  ? `${formatValue(getPulse(m)!, 0)} bpm`
                                  : null,
                                m.context.posture,
                                m.context.arm ? `${m.context.arm} arm` : null,
                                m.context.weightTimeOfDay,
                              ]
                                .filter(Boolean)
                                .join(' • ')}
                            </div>

                            {m.context.notes && (
                              <div
                                style={{
                                  backgroundColor:
                                    'var(--color-tertiary-container)',
                                  color: 'var(--color-on-tertiary-container)',
                                }}
                                className="mt-2 inline-block rounded-lg px-2.5 py-1 text-xs"
                              >
                                “{m.context.notes}”
                              </div>
                            )}
                          </div>
                        </div>

                        <div className="flex items-center gap-1">
                          <Link
                            href={editHrefFor(m)}
                            aria-label={`Edit ${spec?.displayName ?? m.metricType} record`}
                            style={{ color: 'var(--color-on-surface-variant)' }}
                            className="touch-target inline-flex items-center justify-center rounded-lg p-2"
                          >
                            <Edit3 size={17} />
                          </Link>
                          <button
                            type="button"
                            onClick={() => void handleSoftDelete(m)}
                            aria-label={`Delete ${spec?.displayName ?? m.metricType} record`}
                            style={{ color: 'var(--color-error)' }}
                            className="touch-target inline-flex cursor-pointer items-center justify-center rounded-lg p-2"
                          >
                            <Trash2 size={17} />
                          </button>
                        </div>
                      </AppCard>
                    );
                  })}
                </div>
              </section>
            );
          })}

          <div
            style={{ color: 'var(--color-on-surface-variant)' }}
            className="flex flex-col items-center gap-1 pt-4 text-center text-xs"
          >
            <ShieldCheck
              size={18}
              style={{ color: 'var(--color-primary)' }}
              aria-hidden="true"
            />
            <span className="font-semibold">
              Showing {filtered.length} records across {dayGroups.length} days
            </span>
            <span>
              Records are stored in this browser&apos;s IndexedDB and are never
              transmitted without your explicit sync consent.
            </span>
          </div>
        </div>
      )}
    </div>
  );
}

function triggerFileDownload(
  content: string,
  filename: string,
  mimeType: string,
): void {
  if (typeof window === 'undefined' || typeof URL.createObjectURL !== 'function') {
    return;
  }
  try {
    const blob = new Blob([content], { type: mimeType });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
  } catch {
    // Ignored in test environment
  }
}
