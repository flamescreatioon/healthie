'use client';

/**
 * Blood-Pressure Manual Entry Screen (`docs/web/05-manual-entry.md` &
 * `lib/features/blood_pressure/presentation/blood_pressure_entry_screen.dart`).
 *
 * - Real `<label>`s (`htmlFor`), unit announced with value, validation errors
 *   in `aria-describedby` + `role="alert"`.
 * - Double-submit guard (`submittingRef`) guarantees rapid clicks create one record.
 * - Editing preserves `recordedAt` unless the user explicitly changes the time.
 * - Live AHA/ACC 2017 classification and per-reading safety guidance.
 */

import React, { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useQueryClient } from '@tanstack/react-query';
import {
  Activity,
  AlertTriangle,
  ArrowLeft,
  CheckCircle2,
  Heart,
  Minus,
  Plus,
  ShieldAlert,
} from 'lucide-react';
import {
  assessBloodPressureSafety,
  BODY_POSTURES,
  type BodyPostureWire,
  BP_CATEGORIES,
  classifyBloodPressure,
  formatValue,
  MEASUREMENT_ARMS,
  type MeasurementArmWire,
  type Measurement,
  MetricCatalog,
  parseNumeric,
  READING_CIRCUMSTANCES,
  type ReadingCircumstanceWire,
  toLocalDayString,
  validateCanonicalMeasurement,
} from '@/domain';
import { useAppContext, useRepositories } from '@/components/providers/app-providers';
import {
  AppCard,
  SelectableChip,
  StatusPill,
} from '@/components/ui/primitives';

function toLocalDateTimeInputValue(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  const hh = String(date.getHours()).padStart(2, '0');
  const mm = String(date.getMinutes()).padStart(2, '0');
  return `${y}-${m}-${d}T${hh}:${mm}`;
}

export function BloodPressureEntryView({
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
  const [systolicRaw, setSystolicRaw] = useState('');
  const [diastolicRaw, setDiastolicRaw] = useState('');
  const [pulseRaw, setPulseRaw] = useState('');
  const [posture, setPosture] = useState<BodyPostureWire>('sitting');
  const [arm, setArm] = useState<MeasurementArmWire>('left');
  const [circumstances, setCircumstances] = useState<ReadingCircumstanceWire[]>([
    'resting',
  ]);
  const [notes, setNotes] = useState('');
  const [dateTimeLocal, setDateTimeLocal] = useState(() =>
    toLocalDateTimeInputValue(clock.now()),
  );
  const [timeModifiedByUser, setTimeModifiedByUser] = useState(false);

  const [errors, setErrors] = useState<{
    systolic?: string;
    diastolic?: string;
    pulse?: string;
    form?: string;
  }>({});
  const [isSaving, setIsSaving] = useState(false);
  const submittingRef = useRef(false);
  const systolicInputRef = useRef<HTMLInputElement>(null);
  const diastolicInputRef = useRef<HTMLInputElement>(null);

  // Load existing record when editing, or prefill from latest BP reading
  useEffect(() => {
    let active = true;
    (async () => {
      if (editId) {
        const found = await repo.getById(editId);
        if (!active || !found) return;
        setExisting(found);
        setSystolicRaw(formatValue(found.value, 0));
        setDiastolicRaw(
          found.secondaryValue !== null && found.secondaryValue !== undefined
            ? formatValue(found.secondaryValue, 0)
            : '',
        );
        setPulseRaw(
          found.tertiaryValue !== null && found.tertiaryValue !== undefined
            ? formatValue(found.tertiaryValue, 0)
            : '',
        );
        setPosture(found.context.posture ?? 'sitting');
        setArm(found.context.arm ?? 'left');
        setCircumstances(
          found.context.circumstances ? [...found.context.circumstances] : [],
        );
        setNotes(found.context.notes ?? '');
        setDateTimeLocal(toLocalDateTimeInputValue(new Date(found.recordedAt)));
      }
    })();
    return () => {
      active = false;
    };
  }, [editId, repo]);

  const parsedSystolic = parseNumeric(systolicRaw);
  const parsedDiastolic = parseNumeric(diastolicRaw);
  const parsedPulse = pulseRaw.trim() === '' ? null : parseNumeric(pulseRaw);

  const systolicInt = parsedSystolic !== null ? Math.round(parsedSystolic) : null;
  const diastolicInt =
    parsedDiastolic !== null ? Math.round(parsedDiastolic) : null;
  const pulseInt = parsedPulse !== null ? Math.round(parsedPulse) : null;

  const category =
    systolicInt !== null && diastolicInt !== null
      ? classifyBloodPressure({ systolic: systolicInt, diastolic: diastolicInt })
      : null;

  const safety = assessBloodPressureSafety({
    systolic: systolicInt,
    diastolic: diastolicInt,
  });

  const adjustValue = (
    currentRaw: string,
    fallback: number,
    delta: number,
    setter: (val: string) => void,
  ) => {
    const current = parseNumeric(currentRaw) ?? fallback;
    const next = Math.max(0, Math.min(999, Math.round(current + delta)));
    setter(String(next));
  };

  const runValidation = () => {
    const check = validateCanonicalMeasurement({
      metricType: 'blood_pressure',
      value: systolicInt,
      secondaryValue: diastolicInt,
      tertiaryValue: pulseRaw.trim() === '' ? null : (pulseInt ?? Number.NaN),
    });
    const nextErrors = {
      systolic: check.errors.value,
      diastolic: check.errors.secondaryValue,
      pulse: check.errors.tertiaryValue,
    };
    setErrors(nextErrors);
    return { valid: check.valid, nextErrors };
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (submittingRef.current) return;

    const { valid, nextErrors } = runValidation();
    if (!valid) {
      if (nextErrors.systolic) {
        systolicInputRef.current?.focus();
      } else if (nextErrors.diastolic) {
        diastolicInputRef.current?.focus();
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
        metricType: 'blood_pressure',
        value: systolicInt!,
        unit: 'mmHg',
        secondaryValue: diastolicInt!,
        secondaryUnit: 'mmHg',
        tertiaryValue: pulseInt,
        tertiaryUnit: pulseInt !== null ? 'bpm' : null,
        recordedAt: safeRecorded.toISOString(),
        localDay: toLocalDayString(safeRecorded),
        createdAt: existing?.createdAt ?? nowIso,
        updatedAt: nowIso,
        source: existing?.source ?? 'manual',
        isSynced: false,
        deletedAt: null,
        context: {
          posture,
          arm,
          circumstances,
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

  const toggleCircumstance = (item: ReadingCircumstanceWire) => {
    setCircumstances((prev) =>
      prev.includes(item) ? prev.filter((c) => c !== item) : [...prev, item],
    );
  };

  const spec = MetricCatalog.blood_pressure;

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
              {existing ? 'Edit Blood Pressure' : 'Log Blood Pressure'}
            </h1>
            <p
              className="m-0 text-xs"
              style={{ color: 'var(--color-on-surface-variant)' }}
            >
              Stored locally in mmHg • Works offline
            </p>
          </div>
        </div>
        <StatusPill label="AHA/ACC 2017" tone="primary" dense />
      </div>

      {/* Pre-Check Guidance Banner */}
      <div
        style={{
          backgroundColor: 'var(--color-secondary-container)',
          color: 'var(--color-on-secondary-container)',
          borderRadius: 'var(--radius-card)',
        }}
        className="flex items-start gap-3 p-4 text-xs"
      >
        <Heart size={18} className="mt-0.5 shrink-0" aria-hidden="true" />
        <div>
          <div className="font-bold">Pre-Check Guidance (5 min rest)</div>
          <p className="m-0 mt-0.5">
            Rest quietly for 5 minutes. Keep your back supported, feet flat on
            the floor, and your arm resting naturally at heart level.
          </p>
        </div>
      </div>

      {/* Primary Values Card */}
      <AppCard className="space-y-4">
        <div className="flex items-center justify-between">
          <span className="type-title flex items-center gap-2">
            <Activity
              size={18}
              style={{ color: 'var(--metric-bp)' }}
              aria-hidden="true"
            />
            <span>Blood Pressure Reading</span>
          </span>
          <span
            className="text-xs font-semibold"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            mmHg
          </span>
        </div>

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {/* Systolic Field */}
          <div
            style={{
              backgroundColor: 'var(--color-surface-low)',
              borderRadius: 'var(--radius-control)',
            }}
            className="p-4"
          >
            <label
              htmlFor="bp-systolic-input"
              className="type-micro block"
              style={{ color: 'var(--color-on-surface-variant)' }}
            >
              Systolic (mmHg)
            </label>
            <div className="mt-2 flex items-center gap-2">
              <button
                type="button"
                aria-label="Decrease Systolic"
                onClick={() => adjustValue(systolicRaw, 120, -1, setSystolicRaw)}
                style={{
                  backgroundColor: 'var(--color-surface-lowest)',
                  border: '1px solid var(--color-outline-variant)',
                }}
                className="touch-target inline-flex cursor-pointer items-center justify-center rounded-full"
              >
                <Minus size={16} />
              </button>
              <input
                ref={systolicInputRef}
                id="bp-systolic-input"
                type="text"
                inputMode="decimal"
                placeholder="120"
                value={systolicRaw}
                onChange={(e) => setSystolicRaw(e.target.value)}
                onBlur={() => {
                  if (systolicRaw.trim()) runValidation();
                }}
                aria-invalid={Boolean(errors.systolic)}
                aria-describedby={
                  errors.systolic ? 'bp-systolic-error' : 'bp-systolic-range'
                }
                className="type-display w-full bg-transparent text-center tabular-nums focus:outline-none"
                style={{ color: 'var(--color-on-surface)' }}
              />
              <button
                type="button"
                aria-label="Increase Systolic"
                onClick={() => adjustValue(systolicRaw, 120, 1, setSystolicRaw)}
                style={{
                  backgroundColor: 'var(--color-surface-lowest)',
                  border: '1px solid var(--color-outline-variant)',
                }}
                className="touch-target inline-flex cursor-pointer items-center justify-center rounded-full"
              >
                <Plus size={16} />
              </button>
            </div>
            <div
              id="bp-systolic-range"
              className="mt-1 text-center text-[11px]"
              style={{ color: 'var(--color-on-surface-variant)' }}
            >
              Range: {spec.min}–{spec.max} mmHg
            </div>
            {errors.systolic && (
              <p
                id="bp-systolic-error"
                role="alert"
                className="m-0 mt-1.5 text-center text-xs font-semibold"
                style={{ color: 'var(--color-error)' }}
              >
                {errors.systolic}
              </p>
            )}
          </div>

          {/* Diastolic Field */}
          <div
            style={{
              backgroundColor: 'var(--color-surface-low)',
              borderRadius: 'var(--radius-control)',
            }}
            className="p-4"
          >
            <label
              htmlFor="bp-diastolic-input"
              className="type-micro block"
              style={{ color: 'var(--color-on-surface-variant)' }}
            >
              Diastolic (mmHg)
            </label>
            <div className="mt-2 flex items-center gap-2">
              <button
                type="button"
                aria-label="Decrease Diastolic"
                onClick={() =>
                  adjustValue(diastolicRaw, 80, -1, setDiastolicRaw)
                }
                style={{
                  backgroundColor: 'var(--color-surface-lowest)',
                  border: '1px solid var(--color-outline-variant)',
                }}
                className="touch-target inline-flex cursor-pointer items-center justify-center rounded-full"
              >
                <Minus size={16} />
              </button>
              <input
                ref={diastolicInputRef}
                id="bp-diastolic-input"
                type="text"
                inputMode="decimal"
                placeholder="80"
                value={diastolicRaw}
                onChange={(e) => setDiastolicRaw(e.target.value)}
                onBlur={() => {
                  if (diastolicRaw.trim()) runValidation();
                }}
                aria-invalid={Boolean(errors.diastolic)}
                aria-describedby={
                  errors.diastolic ? 'bp-diastolic-error' : 'bp-diastolic-range'
                }
                className="type-display w-full bg-transparent text-center tabular-nums focus:outline-none"
                style={{ color: 'var(--color-on-surface)' }}
              />
              <button
                type="button"
                aria-label="Increase Diastolic"
                onClick={() => adjustValue(diastolicRaw, 80, 1, setDiastolicRaw)}
                style={{
                  backgroundColor: 'var(--color-surface-lowest)',
                  border: '1px solid var(--color-outline-variant)',
                }}
                className="touch-target inline-flex cursor-pointer items-center justify-center rounded-full"
              >
                <Plus size={16} />
              </button>
            </div>
            <div
              id="bp-diastolic-range"
              className="mt-1 text-center text-[11px]"
              style={{ color: 'var(--color-on-surface-variant)' }}
            >
              Range: {spec.secondary!.min}–{spec.secondary!.max} mmHg
            </div>
            {errors.diastolic && (
              <p
                id="bp-diastolic-error"
                role="alert"
                className="m-0 mt-1.5 text-center text-xs font-semibold"
                style={{ color: 'var(--color-error)' }}
              >
                {errors.diastolic}
              </p>
            )}
          </div>
        </div>

        {/* Optional Resting Heart Rate */}
        <div
          style={{
            backgroundColor: 'var(--color-surface-low)',
            borderRadius: 'var(--radius-control)',
          }}
          className="flex flex-col gap-2 p-3.5 sm:flex-row sm:items-center sm:justify-between"
        >
          <div>
            <label
              htmlFor="bp-pulse-input"
              className="text-sm font-semibold block"
              style={{ color: 'var(--color-on-surface)' }}
            >
              Resting Heart Rate (bpm, optional)
            </label>
            <span
              className="text-xs"
              style={{ color: 'var(--color-on-surface-variant)' }}
            >
              Companion pulse reading ({spec.tertiary!.min}–{spec.tertiary!.max}{' '}
              bpm)
            </span>
          </div>
          <div className="flex items-center gap-2">
            <input
              id="bp-pulse-input"
              type="text"
              inputMode="decimal"
              placeholder="70"
              value={pulseRaw}
              onChange={(e) => setPulseRaw(e.target.value)}
              aria-invalid={Boolean(errors.pulse)}
              aria-describedby={errors.pulse ? 'bp-pulse-error' : undefined}
              style={{
                backgroundColor: 'var(--color-surface-lowest)',
                border: '1px solid var(--color-outline-variant)',
                borderRadius: 'var(--radius-control)',
                color: 'var(--color-on-surface)',
              }}
              className="touch-target w-28 px-3 py-2 text-right font-bold tabular-nums"
            />
            <span
              className="text-xs font-semibold"
              style={{ color: 'var(--color-on-surface-variant)' }}
            >
              bpm
            </span>
          </div>
        </div>
        {errors.pulse && (
          <p
            id="bp-pulse-error"
            role="alert"
            className="m-0 text-xs font-semibold"
            style={{ color: 'var(--color-error)' }}
          >
            {errors.pulse}
          </p>
        )}

        {/* Live Guideline Classification Pill */}
        <div
          aria-live="polite"
          style={{
            backgroundColor: 'var(--color-surface-low)',
            borderRadius: 'var(--radius-control)',
          }}
          className="flex items-center justify-between p-3 text-xs"
        >
          <span className="font-semibold">
            {category
              ? BP_CATEGORIES[category].label
              : 'Enter both systolic and diastolic values'}
          </span>
          {category && (
            <StatusPill
              label={BP_CATEGORIES[category].shortLabel}
              tone={
                category === 'normal'
                  ? 'positive'
                  : category === 'elevated' ||
                      category === 'stage_1_hypertension'
                    ? 'warning'
                    : 'critical'
              }
              dense
            />
          )}
        </div>
      </AppCard>

      {/* Safety-Critical Per-Reading Alert (`assessBloodPressureSafety`) */}
      {safety.requiresAttention && (
        <div
          role="alert"
          style={{
            backgroundColor:
              safety.level === 'urgent'
                ? 'var(--color-error-container)'
                : 'var(--color-tertiary-container)',
            color:
              safety.level === 'urgent'
                ? 'var(--color-on-error-container)'
                : 'var(--color-on-tertiary-container)',
            borderRadius: 'var(--radius-card)',
          }}
          className="flex items-start gap-3 p-4 text-xs"
        >
          {safety.level === 'urgent' ? (
            <ShieldAlert size={20} className="mt-0.5 shrink-0" />
          ) : (
            <AlertTriangle size={20} className="mt-0.5 shrink-0" />
          )}
          <div>
            <div className="font-bold text-sm">{safety.headline}</div>
            <p className="m-0 mt-1 leading-relaxed">{safety.guidance}</p>
          </div>
        </div>
      )}

      {/* Context & Timestamp Card (≤3 optional context groups) */}
      <AppCard className="space-y-4">
        <h2 className="type-title m-0">Measurement Context</h2>

        <div>
          <label
            htmlFor="bp-recorded-at"
            className="type-label block mb-1.5"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            Date &amp; Time
          </label>
          <input
            id="bp-recorded-at"
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

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <span
              className="type-label block mb-1.5"
              style={{ color: 'var(--color-on-surface-variant)' }}
            >
              Body Posture (optional)
            </span>
            <div className="flex flex-wrap gap-2">
              {BODY_POSTURES.map((p) => (
                <SelectableChip
                  key={p.wireName}
                  label={p.label}
                  selected={posture === p.wireName}
                  onClick={() => setPosture(p.wireName)}
                />
              ))}
            </div>
          </div>

          <div>
            <span
              className="type-label block mb-1.5"
              style={{ color: 'var(--color-on-surface-variant)' }}
            >
              Measurement Arm (optional)
            </span>
            <div className="flex flex-wrap gap-2">
              {MEASUREMENT_ARMS.map((a) => (
                <SelectableChip
                  key={a.wireName}
                  label={a.label}
                  selected={arm === a.wireName}
                  onClick={() => setArm(a.wireName)}
                />
              ))}
            </div>
          </div>
        </div>

        <div>
          <span
            className="type-label block mb-1.5"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            Circumstances (optional)
          </span>
          <div className="flex flex-wrap gap-2">
            {READING_CIRCUMSTANCES.map((c) => (
              <SelectableChip
                key={c.wireName}
                label={c.label}
                selected={circumstances.includes(c.wireName)}
                onClick={() => toggleCircumstance(c.wireName)}
              />
            ))}
          </div>
        </div>

        <div>
          <label
            htmlFor="bp-notes-input"
            className="type-label block mb-1.5"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            Notes (optional)
          </label>
          <input
            id="bp-notes-input"
            type="text"
            placeholder="E.g., Measured after 5 minutes seated rest…"
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
                ? 'Update blood pressure'
                : 'Save blood pressure'}
          </span>
        </button>
      </div>
    </form>
  );
}
