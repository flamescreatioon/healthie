import { describe, expect, it } from 'vitest';
import {
  Units,
  toCanonical,
  fromCanonical,
  convert,
  parseNumeric,
  formatBloodPressure,
  ahaAcc2017Guideline,
  ALL_BP_CATEGORIES,
  classifyBloodPressure,
  assessBloodPressureSafety,
  validateCanonicalMeasurement,
  measurementToJson,
  measurementFromJson,
  startOfLocalDay,
  toLocalDayString,
  dateRangeEndingOn,
  dateRangeDayCount,
  dateRangeContains,
  computeDescriptiveStats,
  movingAverage,
  aggregateByDay,
  analyseTrend,
  summariseBloodPressure,
  summariseWeight,
  computeGoalProgress,
  bloodPressureInsights,
  weightInsights,
  dashboardInsight,
  type Measurement,
} from '@/domain';

describe('Domain Layer — Units & Locale Numeric Parsing', () => {
  it('converts weight between kg and lb accurately', () => {
    const lb = fromCanonical(70, Units.pound);
    expect(lb).toBeCloseTo(154.3236, 3);
    const backToKg = toCanonical(lb, Units.pound);
    expect(backToKg).toBeCloseTo(70, 5);
  });

  it('converts temperature between Celsius and Fahrenheit accurately', () => {
    expect(convert(37, Units.celsius, Units.fahrenheit)).toBeCloseTo(98.6, 4);
    expect(convert(98.6, Units.fahrenheit, Units.celsius)).toBeCloseTo(37, 4);
  });

  it('converts blood glucose between mg/dL and mmol/L accurately', () => {
    const mmol = fromCanonical(90, Units.millimolePerLitre);
    expect(mmol).toBeCloseTo(4.995, 2);
    expect(toCanonical(mmol, Units.millimolePerLitre)).toBeCloseTo(90, 4);
  });

  it('parses decimal-point, decimal-comma, and thousands-separated numbers', () => {
    expect(parseNumeric('72.4')).toBeCloseTo(72.4, 4);
    expect(parseNumeric('72,4')).toBeCloseTo(72.4, 4);
    expect(parseNumeric('1,234.5')).toBeCloseTo(1234.5, 4);
    expect(parseNumeric('1.234,5')).toBeCloseTo(1234.5, 4);
    expect(parseNumeric('')).toBeNull();
    expect(parseNumeric('abc')).toBeNull();
  });

  it('formats blood pressure strings cleanly', () => {
    expect(formatBloodPressure(122, 78)).toBe('122/78');
    expect(formatBloodPressure(118, null)).toBe('118/—');
  });
});

describe('Domain Layer — AHA/ACC 2017 Blood Pressure Guideline & Safety Alerts', () => {
  it('classifies all AHA/ACC 2017 boundary values identically to Flutter', () => {
    expect(classifyBloodPressure({ systolic: 119, diastolic: 79 })).toBe('normal');
    expect(classifyBloodPressure({ systolic: 120, diastolic: 79 })).toBe('elevated');
    expect(classifyBloodPressure({ systolic: 129, diastolic: 79 })).toBe('elevated');
    expect(classifyBloodPressure({ systolic: 130, diastolic: 79 })).toBe(
      'stage_1_hypertension',
    );
    expect(classifyBloodPressure({ systolic: 118, diastolic: 80 })).toBe(
      'stage_1_hypertension',
    );
    expect(classifyBloodPressure({ systolic: 139, diastolic: 89 })).toBe(
      'stage_1_hypertension',
    );
    expect(classifyBloodPressure({ systolic: 140, diastolic: 75 })).toBe(
      'stage_2_hypertension',
    );
    expect(classifyBloodPressure({ systolic: 125, diastolic: 90 })).toBe(
      'stage_2_hypertension',
    );
    expect(classifyBloodPressure({ systolic: 180, diastolic: 95 })).toBe(
      'stage_2_hypertension',
    );
    expect(classifyBloodPressure({ systolic: 181, diastolic: 95 })).toBe(
      'hypertensive_crisis',
    );
    expect(classifyBloodPressure({ systolic: 145, diastolic: 121 })).toBe(
      'hypertensive_crisis',
    );
  });

  it('triggers non-diagnostic safety guidance for crisis, hypotension, and normal readings', () => {
    const crisis = assessBloodPressureSafety({ systolic: 184, diastolic: 122 });
    expect(crisis.level).toBe('urgent');
    expect(crisis.requiresAttention).toBe(true);

    const low = assessBloodPressureSafety({ systolic: 86, diastolic: 56 });
    expect(low.level).toBe('caution');
    expect(low.requiresAttention).toBe(true);

    const normal = assessBloodPressureSafety({ systolic: 118, diastolic: 76 });
    expect(normal.level).toBe('none');
    expect(normal.requiresAttention).toBe(false);
  });

  it('exposes official AHA/ACC 2017 source metadata', () => {
    expect(ahaAcc2017Guideline.id).toBe('aha_acc_2017');
    expect(ALL_BP_CATEGORIES).toHaveLength(5);
  });
});

describe('Domain Layer — Canonical Measurement Validation & Wire Serialization', () => {
  const fixedNow = new Date('2026-05-15T12:00:00.000Z');

  it('rejects blood pressure where systolic <= diastolic', () => {
    const result = validateCanonicalMeasurement({
      metricType: 'blood_pressure',
      value: 80,
      secondaryValue: 85,
      tertiaryValue: 70,
    });
    expect(result.valid).toBe(false);
    expect(result.errors.value).toMatch(/Systolic must be greater than diastolic/i);
  });

  it('rejects timestamps more than 5 minutes in the future', () => {
    const result = validateCanonicalMeasurement({
      metricType: 'weight',
      value: 70.5,
      recordedAt: new Date('2026-05-15T12:10:00.000Z'),
      now: fixedNow,
    });
    expect(result.valid).toBe(false);
    expect(result.errors.recordedAt).toMatch(/future/i);
  });

  it('serializes and deserializes measurement wire JSON losslessly', () => {
    const original: Measurement = {
      id: 'bp-wire-1',
      metricType: 'blood_pressure',
      value: 124,
      unit: 'mmHg',
      secondaryValue: 80,
      secondaryUnit: 'mmHg',
      tertiaryValue: 66,
      tertiaryUnit: 'bpm',
      recordedAt: '2026-05-15T08:30:00.000Z',
      localDay: '2026-05-15',
      createdAt: fixedNow.toISOString(),
      updatedAt: fixedNow.toISOString(),
      source: 'manual',
      isSynced: false,
      deletedAt: null,
      context: {
        posture: 'sitting',
        arm: 'left',
        circumstances: ['resting'],
        notes: 'Morning check',
      },
    };

    const wire = measurementToJson(original);
    expect(wire.metric_type).toBe('blood_pressure');
    expect(wire.recorded_at).toBe('2026-05-15T08:30:00.000Z');
    expect(wire.value).toBe(124);
    expect(wire.secondary_value).toBe(80);

    const roundTrip = measurementFromJson(wire as unknown as Record<string, unknown>);
    expect(roundTrip.id).toBe(original.id);
    expect(roundTrip.value).toBe(124);
    expect(roundTrip.secondaryValue).toBe(80);
    expect(roundTrip.context.posture).toBe('sitting');
    expect(roundTrip.context.notes).toBe('Morning check');
  });
});

describe('Domain Layer — Local-Day Rule, Statistics, Trend & Insights', () => {
  it('groups timestamps by local calendar day and computes preset ranges', () => {
    const localDate = new Date(2026, 4, 15, 23, 45, 0);
    const dayStart = startOfLocalDay(localDate);
    expect(dayStart.getHours()).toBe(0);
    expect(dayStart.getMinutes()).toBe(0);
    expect(toLocalDayString(localDate)).toBe('2026-05-15');

    const range7d = dateRangeEndingOn(localDate, 7);
    expect(dateRangeDayCount(range7d)).toBe(7);
    expect(dateRangeContains(range7d, localDate)).toBe(true);
  });

  it('computes descriptive statistics, moving average, daily aggregates, and Theil-Sen trend', () => {
    const statsEven = computeDescriptiveStats([110, 120, 130, 140]);
    expect(statsEven?.mean).toBe(125);
    expect(statsEven?.median).toBe(125);

    const statsOdd = computeDescriptiveStats([110, 120, 145]);
    expect(statsOdd?.median).toBe(120);

    const points = [
      { at: new Date(2026, 4, 10, 8, 0), value: 75.0 },
      { at: new Date(2026, 4, 10, 20, 0), value: 75.4 },
      { at: new Date(2026, 4, 12, 8, 0), value: 74.2 },
      { at: new Date(2026, 4, 14, 8, 0), value: 73.4 },
      { at: new Date(2026, 4, 16, 8, 0), value: 72.6 },
    ];

    const daily = aggregateByDay(points);
    expect(daily).toHaveLength(4);
    expect(daily[0]?.value).toBeCloseTo(75.2, 4);

    const smoothed = movingAverage(
      daily.map((d) => d.value),
      3,
    );
    expect(smoothed).toHaveLength(4);

    const trend = analyseTrend(
      daily.map((d) => ({ at: d.day, value: d.value! })),
      { meaningfulChange: 0.5 },
    );
    expect(trend.direction).toBe('decreasing');
    expect(trend.slopePerDay).toBeLessThan(-0.1);
  });

  it('computes BP summary, weight goal progress, and rule-based insights', () => {
    const now = new Date(2026, 4, 15, 12, 0);
    const period = dateRangeEndingOn(now, 7);
    const nowIso = now.toISOString();

    const bpReadings: Measurement[] = [
      {
        id: 'bp-1',
        metricType: 'blood_pressure',
        value: 126,
        unit: 'mmHg',
        secondaryValue: 82,
        secondaryUnit: 'mmHg',
        tertiaryValue: 68,
        tertiaryUnit: 'bpm',
        recordedAt: new Date(2026, 4, 13, 7, 30).toISOString(),
        localDay: '2026-05-13',
        createdAt: nowIso,
        updatedAt: nowIso,
        source: 'manual',
        isSynced: false,
        deletedAt: null,
        context: {},
      },
      {
        id: 'bp-2',
        metricType: 'blood_pressure',
        value: 122,
        unit: 'mmHg',
        secondaryValue: 78,
        secondaryUnit: 'mmHg',
        tertiaryValue: 64,
        tertiaryUnit: 'bpm',
        recordedAt: new Date(2026, 4, 14, 8, 15).toISOString(),
        localDay: '2026-05-14',
        createdAt: nowIso,
        updatedAt: nowIso,
        source: 'manual',
        isSynced: false,
        deletedAt: null,
        context: {},
      },
      {
        id: 'bp-3',
        metricType: 'blood_pressure',
        value: 118,
        unit: 'mmHg',
        secondaryValue: 76,
        secondaryUnit: 'mmHg',
        tertiaryValue: 62,
        tertiaryUnit: 'bpm',
        recordedAt: new Date(2026, 4, 14, 20, 15).toISOString(),
        localDay: '2026-05-14',
        createdAt: nowIso,
        updatedAt: nowIso,
        source: 'manual',
        isSynced: false,
        deletedAt: null,
        context: {},
      },
    ];

    const bpSummary = summariseBloodPressure({
      period,
      measurements: bpReadings,
    });
    expect(bpSummary.readingCount).toBe(3);
    expect(bpSummary.morning.systolic).toBeCloseTo(124, 2);
    expect(bpSummary.evening.systolic).toBeCloseTo(118, 2);

    const bpInsightList = bloodPressureInsights({ current: bpSummary });
    expect(bpInsightList.length).toBeGreaterThan(0);

    const weightReadings: Measurement[] = [
      {
        id: 'w-1',
        metricType: 'weight',
        value: 78.0,
        unit: 'kg',
        recordedAt: new Date(2026, 4, 10, 8, 0).toISOString(),
        localDay: '2026-05-10',
        createdAt: nowIso,
        updatedAt: nowIso,
        source: 'manual',
        isSynced: false,
        deletedAt: null,
        context: {},
      },
      {
        id: 'w-2',
        metricType: 'weight',
        value: 75.0,
        unit: 'kg',
        recordedAt: new Date(2026, 4, 15, 8, 0).toISOString(),
        localDay: '2026-05-15',
        createdAt: nowIso,
        updatedAt: nowIso,
        source: 'manual',
        isSynced: false,
        deletedAt: null,
        context: {},
      },
    ];

    const weightSummary = summariseWeight({
      period,
      measurements: weightReadings,
    });
    expect(weightInsights({ current: weightSummary }).length).toBeGreaterThan(0);

    const dash = dashboardInsight({ current: bpSummary });
    expect(dash.title.length).toBeGreaterThan(0);

    const loseGoal = computeGoalProgress({
      start: 80.0,
      current: 75.0,
      target: 70.0,
    });
    expect(loseGoal.percentAchieved).toBeCloseTo(0.5, 3);
  });
});
