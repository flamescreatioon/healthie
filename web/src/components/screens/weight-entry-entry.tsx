'use client';

/**
 * Body-Weight Manual Entry Screen (`docs/web/05-manual-entry.md` &
 * `lib/features/weight/presentation/weight_entry_screen.dart`).
 *
 * - Stores canonically in `kg`; unit toggle (`kg` / `lb`) converts the current
 *   value in place (`convert(value, from, to)`) without reinterpreting the number.
 * - Accepts locale decimal-comma input (`"72,4"`).
 * - Double-submit guard (`submittingRef`) creates one record.
 * - Editing preserves `recordedAt` unless the user explicitly changed the time.
 */

import React, { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useQueryClient } from '@tanstack/react-query';
import { ArrowLeft, CheckCircle2, Minus, Plus, Scale } from 'lucide-react';
import {
  convert,
  formatValue,
  type Measurement,
  MetricCatalog,
  parseNumeric,
  roundTo,
  toCanonical,
  toLocalDayString,
  validateCanonicalMeasurement,
  WEIGHT_TIMES_OF_DAY,
  type WeightTimeOfDayWire,
} from '@/domain';
import { useAppContext, useRepositories } from '@/components/providers/app-providers';
import {
  AppCard,
  SegmentedControl,
  SelectableChip,
} from '@/components/ui/primitives';

function toLocalDateTimeInputValue(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  const hh = String(date.getHours()).padStart(2, '0');
  const mm = String(date.getMinutes()).padStart(2, '0');
  return `${y}-${m}-${d}T${hh}:${mm}`;
}

export function WeightEntryView({
  editId,
  onSaved,
}: {
  editId?: string | null;
  onSaved?: (saved: Measurement) => void;
}) {
  const router = useRouter();
  const queryClient = useQueryClient();
  const { measurements: repo, clock } = useRepositories();
  const { syncEnabled, triggerSync } = useAppContext();

  const [existing, setExisting] = useState<Measurement | null>(null);
  const [displayUnit, setDisplayUnit] = useState<'kg' | 'lb'>('kg');
  const [weightRaw, setWeightRaw] = useState('');
  const [bodyFatRaw, setBodyFatRaw] = useState('');
  const [waistRaw, setWaistRaw] = useState('');
  const [timeOfDay, setTimeOfDay] =
    useState<WeightTimeOfDayWire>('morning_fasting');
  const [notes, setNotes] = useState('');
  const [dateTimeLocal, setDateTimeLocal] = useState(() =>
    toLocalDateTimeInputValue(clock.now()),
  );
  const [timeModifiedByUser, setTimeModifiedByUser] = useState(false);

  const [errors, setErrors] = useState<{
    weight?: string;
    bodyFat?: string;
    waist?: string;
    form?: string;
  }>({});
  const [isSaving, setIsSaving] = useState(false);
  const submittingRef = useRef(false);
  const weightInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    let active = true;
    (async () => {
      if (editId) {
        const found = await repo.getById(editId);
        if (!active || !found) return;
        setExisting(found);
        setDisplayUnit('kg');
        setWeightRaw(formatValue(found.value, 1));
        setBodyFatRaw(
          found.secondaryValue !== null && found.secondaryValue !== undefined
            ? formatValue(found.secondaryValue, 1)
            : '',
        );
        setWaistRaw(
          found.tertiaryValue !== null && found.tertiaryValue !== undefined
            ? formatValue(found.tertiaryValue, 1)
            : '',
        );
        setTimeOfDay(found.context.weightTimeOfDay ?? 'morning_fasting');
        setNotes(found.context.notes ?? '');
        setDateTimeLocal(toLocalDateTimeInputValue(new Date(found.recordedAt)));
      }
    })();
    return () => {
      active = false;
    };
  }, [editId, repo]);

  // Unit toggle converts the current value in place (`docs/web/05-manual-entry.md`)
  const handleUnitChange = (nextUnit: 'kg' | 'lb') => {
    if (nextUnit === displayUnit) return;
    const parsed = parseNumeric(weightRaw);
    if (parsed !== null) {
      const converted = convert(parsed, displayUnit, nextUnit);
      setWeightRaw(formatValue(converted, 1));
    }
    setDisplayUnit(nextUnit);
  };

  const adjustWeight = (delta: number) => {
    const fallback = displayUnit === 'kg' ? 70 : 154.3;
    const current = parseNumeric(weightRaw) ?? fallback;
    const next = Math.max(1, roundTo(current + delta, 1));
    setWeightRaw(formatValue(next, 1));
  };

  const getCanonicalKg = (): number | null => {
    const parsed = parseNumeric(weightRaw);
    if (parsed === null) return null;
    return toCanonical(parsed, displayUnit);
  };

  const runValidation = () => {
    const canonicalKg = getCanonicalKg();
    const parsedBf =
      bodyFatRaw.trim() === '' ? null : (parseNumeric(bodyFatRaw) ?? Number.NaN);
    const parsedWaist =
      waistRaw.trim() === '' ? null : (parseNumeric(waistRaw) ?? Number.NaN);

    const check = validateCanonicalMeasurement({
      metricType: 'weight',
      value: canonicalKg,
      secondaryValue: parsedBf,
      tertiaryValue: parsedWaist,
    });

    const nextErrors = {
      weight: check.errors.value,
      bodyFat: check.errors.secondaryValue,
      waist: check.errors.tertiaryValue,
    };
    setErrors(nextErrors);
    return { valid: check.valid, nextErrors, canonicalKg, parsedBf, parsedWaist };
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (submittingRef.current) return;

    const { valid, nextErrors, canonicalKg, parsedBf, parsedWaist } =
      runValidation();
    if (!valid || canonicalKg === null) {
      if (nextErrors.weight) {
        weightInputRef.current?.focus();
      }
      return;
    }

    submittingRef.current = true;
    setIsSaving(true);

    try {
      const now = clock.now();
      const nowIso = now.toISOString();
      const recordedDate =
        existing && !timeModifiedByUser
          ? new Date(existing.recordedAt)
          : new Date(dateTimeLocal);
      const safeRecorded = Number.isNaN(recordedDate.getTime())
        ? now
        : recordedDate;

      const record: Measurement = {
        id: existing?.id ?? crypto.randomUUID(),
        metricType: 'weight',
        value: roundTo(canonicalKg, 2),
        unit: 'kg',
        secondaryValue:
          parsedBf !== null && Number.isFinite(parsedBf)
            ? roundTo(parsedBf, 1)
            : null,
        secondaryUnit:
          parsedBf !== null && Number.isFinite(parsedBf) ? '%' : null,
        tertiaryValue:
          parsedWaist !== null && Number.isFinite(parsedWaist)
            ? roundTo(parsedWaist, 1)
            : null,
        tertiaryUnit:
          parsedWaist !== null && Number.isFinite(parsedWaist) ? 'cm' : null,
        recordedAt: safeRecorded.toISOString(),
        localDay: toLocalDayString(safeRecorded),
        createdAt: existing?.createdAt ?? nowIso,
        updatedAt: nowIso,
        source: existing?.source ?? 'manual',
        isSynced: false,
        deletedAt: null,
        context: {
          weightTimeOfDay: timeOfDay,
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
        router.push('/');
      }
    } catch {
      setErrors((prev) => ({
        ...prev,
        form: "Couldn't save your entry. Your data is still here — try again.",
      }));
    } finally {
      submittingRef.current = false;
      setIsSaving(false);
    }
  };

  const spec = MetricCatalog.weight;

  return (
    <form onSubmit={handleSubmit} noValidate className="space-y-5">
      <div className="flex items-center justify-between">
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
          <div>
            <h1 className="type-headline m-0">
              {existing ? 'Edit Body Weight' : 'Log Body Weight'}
            </h1>
            <p
              className="m-0 text-xs"
              style={{ color: 'var(--color-on-surface-variant)' }}
            >
              Stored canonically in kg • Converts in place
            </p>
          </div>
        </div>
      </div>

      <AppCard className="space-y-5">
        <div className="flex items-center justify-between gap-4">
          <span className="type-title flex items-center gap-2">
            <Scale
              size={18}
              style={{ color: 'var(--metric-weight)' }}
              aria-hidden="true"
            />
            <span>Weight Reading</span>
          </span>
          <div className="w-40">
            <SegmentedControl
              options={['kg', 'lb'] as const}
              selected={displayUnit}
              onChange={handleUnitChange}
              ariaLabel="Weight unit"
            />
          </div>
        </div>

        <div
          style={{
            backgroundColor: 'var(--color-surface-low)',
            borderRadius: 'var(--radius-control)',
          }}
          className="p-5 text-center"
        >
          <label
            htmlFor="weight-value-input"
            className="type-micro block"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            Weight ({displayUnit})
          </label>
          <div className="mt-3 flex items-center justify-center gap-4">
            <button
              type="button"
              aria-label="Decrease weight"
              onClick={() => adjustWeight(-0.1)}
              style={{
                backgroundColor: 'var(--color-surface-lowest)',
                border: '1px solid var(--color-outline-variant)',
              }}
              className="touch-target inline-flex cursor-pointer items-center justify-center rounded-full"
            >
              <Minus size={18} />
            </button>
            <div className="flex items-baseline gap-2">
              <input
                ref={weightInputRef}
                id="weight-value-input"
                type="text"
                inputMode="decimal"
                placeholder={displayUnit === 'kg' ? '72.4' : '159.6'}
                value={weightRaw}
                onChange={(e) => setWeightRaw(e.target.value)}
                onBlur={() => {
                  if (weightRaw.trim()) runValidation();
                }}
                aria-invalid={Boolean(errors.weight)}
                aria-describedby={
                  errors.weight ? 'weight-value-error' : 'weight-value-range'
                }
                className="type-display w-36 bg-transparent text-center tabular-nums focus:outline-none"
                style={{ color: 'var(--color-on-surface)' }}
              />
              <span
                className="type-title"
                style={{ color: 'var(--color-on-surface-variant)' }}
              >
                {displayUnit}
              </span>
            </div>
            <button
              type="button"
              aria-label="Increase weight"
              onClick={() => adjustWeight(0.1)}
              style={{
                backgroundColor: 'var(--color-surface-lowest)',
                border: '1px solid var(--color-outline-variant)',
              }}
              className="touch-target inline-flex cursor-pointer items-center justify-center rounded-full"
            >
              <Plus size={18} />
            </button>
          </div>
          <div
            id="weight-value-range"
            className="mt-2 text-xs"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            Plausible range: {spec.min}–{spec.max} kg
          </div>
          {errors.weight && (
            <p
              id="weight-value-error"
              role="alert"
              className="m-0 mt-2 text-xs font-semibold"
              style={{ color: 'var(--color-error)' }}
            >
              {errors.weight}
            </p>
          )}
        </div>

        {/* Optional Body Composition */}
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label
              htmlFor="weight-bodyfat-input"
              className="type-label block mb-1.5"
              style={{ color: 'var(--color-on-surface-variant)' }}
            >
              Body Fat (%, optional)
            </label>
            <input
              id="weight-bodyfat-input"
              type="text"
              inputMode="decimal"
              placeholder="18.5"
              value={bodyFatRaw}
              onChange={(e) => setBodyFatRaw(e.target.value)}
              aria-invalid={Boolean(errors.bodyFat)}
              style={{
                backgroundColor: 'var(--color-surface-low)',
                border: '1px solid var(--color-outline-variant)',
                borderRadius: 'var(--radius-control)',
                color: 'var(--color-on-surface)',
              }}
              className="touch-target w-full px-3.5 py-2 text-sm tabular-nums"
            />
            {errors.bodyFat && (
              <p
                role="alert"
                className="m-0 mt-1 text-xs font-semibold"
                style={{ color: 'var(--color-error)' }}
              >
                {errors.bodyFat}
              </p>
            )}
          </div>
          <div>
            <label
              htmlFor="weight-waist-input"
              className="type-label block mb-1.5"
              style={{ color: 'var(--color-on-surface-variant)' }}
            >
              Waist Circumference (cm, optional)
            </label>
            <input
              id="weight-waist-input"
              type="text"
              inputMode="decimal"
              placeholder="82.0"
              value={waistRaw}
              onChange={(e) => setWaistRaw(e.target.value)}
              aria-invalid={Boolean(errors.waist)}
              style={{
                backgroundColor: 'var(--color-surface-low)',
                border: '1px solid var(--color-outline-variant)',
                borderRadius: 'var(--radius-control)',
                color: 'var(--color-on-surface)',
              }}
              className="touch-target w-full px-3.5 py-2 text-sm tabular-nums"
            />
            {errors.waist && (
              <p
                role="alert"
                className="m-0 mt-1 text-xs font-semibold"
                style={{ color: 'var(--color-error)' }}
              >
                {errors.waist}
              </p>
            )}
          </div>
        </div>
      </AppCard>

      {/* Context Card */}
      <AppCard className="space-y-4">
        <h2 className="type-title m-0">Log Conditions</h2>

        <div>
          <label
            htmlFor="weight-recorded-at"
            className="type-label block mb-1.5"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            Date &amp; Time
          </label>
          <input
            id="weight-recorded-at"
            type="datetime-local"
            value={dateTimeLocal}
            onChange={(e) => {
              setDateTimeLocal(e.target.value);
              setTimeModifiedByUser(true);
            }}
            style={{
              backgroundColor: 'var(--color-surface-low)',
              border: '1px solid var(--color-outline-variant)',
              borderRadius: 'var(--radius-control)',
              color: 'var(--color-on-surface)',
            }}
            className="touch-target w-full px-3.5 py-2 text-sm tabular-nums"
          />
        </div>

        <div>
          <span
            className="type-label block mb-1.5"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            Time of Day (optional)
          </span>
          <div className="flex flex-wrap gap-2">
            {WEIGHT_TIMES_OF_DAY.map((slot) => (
              <SelectableChip
                key={slot.wireName}
                label={slot.label}
                selected={timeOfDay === slot.wireName}
                onClick={() => setTimeOfDay(slot.wireName)}
              />
            ))}
          </div>
        </div>

        <div>
          <label
            htmlFor="weight-notes-input"
            className="type-label block mb-1.5"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            Notes (optional)
          </label>
          <input
            id="weight-notes-input"
            type="text"
            placeholder="E.g., Morning fasting weigh-in…"
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

      {errors.form && (
        <div
          role="alert"
          style={{
            backgroundColor: 'var(--color-error-container)',
            color: 'var(--color-on-error-container)',
            borderRadius: 'var(--radius-control)',
          }}
          className="p-3 text-xs font-semibold"
        >
          {errors.form}
        </div>
      )}

      <div className="flex items-center justify-end gap-3 pt-2">
        <button
          type="submit"
          disabled={isSaving}
          style={{
            backgroundColor: 'var(--color-primary)',
            color: 'var(--color-on-primary)',
            borderRadius: 'var(--radius-control)',
          }}
          className="touch-target flex w-full sm:w-auto cursor-pointer items-center justify-center gap-2 px-6 py-3 text-sm font-semibold disabled:opacity-50"
        >
          <CheckCircle2 size={18} aria-hidden="true" />
          <span>
            {isSaving
              ? 'Saving…'
              : existing
                ? 'Update weight reading'
                : 'Save weight reading'}
          </span>
        </button>
      </div>
    </form>
  );
}
