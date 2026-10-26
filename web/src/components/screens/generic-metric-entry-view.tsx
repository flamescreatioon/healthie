'use client';

/**
 * Shared Catalog Metric Entry Screen (`heart_rate`, `spo2`, `body_temperature`,
 * `blood_glucose`) with unit toggle conversion and catalog validation
 * (`docs/web/05-manual-entry.md`).
 */

import React, { useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useQueryClient } from '@tanstack/react-query';
import { ArrowLeft, CheckCircle2 } from 'lucide-react';
import {
  convert,
  formatValue,
  type Measurement,
  MetricCatalog,
  type MetricWireName,
  parseNumeric,
  READING_CIRCUMSTANCES,
  type ReadingCircumstanceWire,
  roundTo,
  toCanonical,
  toLocalDayString,
  type UnitSymbol,
  validateCanonicalMeasurement,
} from '@/domain';
import { useAppContext, useRepositories } from '@/components/providers/app-providers';
import {
  AppCard,
  MetricBadge,
  SegmentedControl,
  SelectableChip,
} from '@/components/ui/primitives';

export function GenericMetricEntryView({
  metricType,
  onSaved,
}: {
  metricType: MetricWireName;
  onSaved?: (saved: Measurement) => void;
}) {
  const router = useRouter();
  const queryClient = useQueryClient();
  const { measurements: repo, clock } = useRepositories();
  const { syncEnabled, triggerSync } = useAppContext();

  const spec = MetricCatalog[metricType];
  const entryUnitSymbols = spec.entryUnits.map((u) => u.symbol);

  const [displayUnit, setDisplayUnit] = useState<UnitSymbol>(
    spec.canonicalUnit.symbol,
  );
  const [valueRaw, setValueRaw] = useState('');
  const [circumstances, setCircumstances] = useState<ReadingCircumstanceWire[]>(
    [],
  );
  const [notes, setNotes] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const submittingRef = useRef(false);

  const handleUnitToggle = (nextUnit: UnitSymbol) => {
    if (nextUnit === displayUnit) return;
    const parsed = parseNumeric(valueRaw);
    if (parsed !== null) {
      const converted = convert(parsed, displayUnit, nextUnit);
      setValueRaw(formatValue(converted, spec.precision));
    }
    setDisplayUnit(nextUnit);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (submittingRef.current) return;

    const parsed = parseNumeric(valueRaw);
    const canonicalValue =
      parsed === null ? null : toCanonical(parsed, displayUnit);
    const check = validateCanonicalMeasurement({
      metricType,
      value: canonicalValue,
    });

    if (!check.valid || canonicalValue === null) {
      setError(check.errors.value ?? 'Enter a valid reading');
      return;
    }

    submittingRef.current = true;
    setIsSaving(true);
    try {
      const now = clock.now();
      const nowIso = now.toISOString();
      const record: Measurement = {
        id: crypto.randomUUID(),
        metricType,
        value: roundTo(canonicalValue, spec.precision),
        unit: spec.canonicalUnit.symbol,
        recordedAt: nowIso,
        localDay: toLocalDayString(now),
        createdAt: nowIso,
        updatedAt: nowIso,
        source: 'manual',
        isSynced: false,
        deletedAt: null,
        context: {
          ...(circumstances.length > 0 ? { circumstances } : {}),
          ...(notes.trim() ? { notes: notes.trim() } : {}),
        },
      };

      await repo.save(record);
      await queryClient.invalidateQueries();
      if (syncEnabled) {
        void triggerSync();
      }
      if (onSaved) {
        onSaved(record);
      } else {
        router.push('/track');
      }
    } finally {
      submittingRef.current = false;
      setIsSaving(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} noValidate className="space-y-5">
      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={() => router.back()}
          aria-label="Back"
          style={{
            backgroundColor: 'var(--color-surface-low)',
            color: 'var(--color-on-surface)',
          }}
          className="touch-target inline-flex cursor-pointer items-center justify-center rounded-xl p-2"
        >
          <ArrowLeft size={20} />
        </button>
        <MetricBadge metric={metricType} />
        <div>
          <h1 className="type-headline m-0">Log {spec.displayName}</h1>
          <p
            className="m-0 text-xs"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            {spec.description}
          </p>
        </div>
      </div>

      <AppCard className="space-y-4">
        {entryUnitSymbols.length > 1 && (
          <div className="w-48">
            <SegmentedControl
              options={entryUnitSymbols}
              selected={displayUnit}
              onChange={handleUnitToggle}
              ariaLabel={`${spec.displayName} unit`}
            />
          </div>
        )}

        <div>
          <label
            htmlFor="generic-metric-value"
            className="type-label block mb-1.5"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            {spec.displayName} ({displayUnit})
          </label>
          <div className="flex items-baseline gap-3">
            <input
              id="generic-metric-value"
              type="text"
              inputMode="decimal"
              value={valueRaw}
              onChange={(e) => {
                setValueRaw(e.target.value);
                setError(null);
              }}
              aria-invalid={Boolean(error)}
              aria-describedby={error ? 'generic-metric-error' : undefined}
              style={{
                backgroundColor: 'var(--color-surface-low)',
                border: '1px solid var(--color-outline-variant)',
                borderRadius: 'var(--radius-control)',
                color: 'var(--color-on-surface)',
              }}
              className="type-display w-48 px-4 py-2 tabular-nums"
            />
            <span
              className="type-title"
              style={{ color: 'var(--color-on-surface-variant)' }}
            >
              {displayUnit}
            </span>
          </div>
          <p
            className="m-0 mt-1.5 text-xs"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            Plausible range: {spec.min}–{spec.max} {spec.canonicalUnit.symbol}
          </p>
          {error && (
            <p
              id="generic-metric-error"
              role="alert"
              className="m-0 mt-1.5 text-xs font-semibold"
              style={{ color: 'var(--color-error)' }}
            >
              {error}
            </p>
          )}
        </div>

        <div>
          <span
            className="type-label block mb-1.5"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            Context (optional)
          </span>
          <div className="flex flex-wrap gap-2">
            {READING_CIRCUMSTANCES.map((c) => (
              <SelectableChip
                key={c.wireName}
                label={c.label}
                selected={circumstances.includes(c.wireName)}
                onClick={() =>
                  setCircumstances((prev) =>
                    prev.includes(c.wireName)
                      ? prev.filter((item) => item !== c.wireName)
                      : [...prev, c.wireName],
                  )
                }
              />
            ))}
          </div>
        </div>

        <div>
          <label
            htmlFor="generic-metric-notes"
            className="type-label block mb-1.5"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            Notes (optional)
          </label>
          <input
            id="generic-metric-notes"
            type="text"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            style={{
              backgroundColor: 'var(--color-surface-low)',
              border: '1px solid var(--color-outline-variant)',
              borderRadius: 'var(--radius-control)',
              color: 'var(--color-on-surface)',
            }}
            className="touch-target w-full px-3.5 py-2 text-sm"
          />
        </div>
      </AppCard>

      <div className="flex justify-end">
        <button
          type="submit"
          disabled={isSaving}
          style={{
            backgroundColor: 'var(--color-primary)',
            color: 'var(--color-on-primary)',
            borderRadius: 'var(--radius-control)',
          }}
          className="touch-target flex items-center gap-2 px-6 py-3 text-sm font-semibold cursor-pointer"
        >
          <CheckCircle2 size={18} aria-hidden="true" />
          <span>{isSaving ? 'Saving…' : `Save ${spec.displayName}`}</span>
        </button>
      </div>
    </form>
  );
}
