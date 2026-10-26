<?php

namespace App\Support;

/**
 * Canonical units and plausible validation ranges per metric wire name.
 *
 * Mirrors health-domain-model/references/metric-catalog.md. Wire names are a
 * permanent sync contract: never rename a key, only add new ones. Ranges catch
 * typos, not medical judgement — the API rejects out-of-range input instead of
 * clamping it.
 *
 * @phpstan-type MetricSpec array{unit: string, min: float, max: float}
 */
class MetricCatalog
{
    /**
     * @var array<string, MetricSpec>
     */
    public const METRICS = [
        'weight' => ['unit' => 'kg', 'min' => 20, 'max' => 400],
        'height' => ['unit' => 'cm', 'min' => 80, 'max' => 250],
        'body_fat' => ['unit' => '%', 'min' => 2, 'max' => 70],
        'waist_circumference' => ['unit' => 'cm', 'min' => 30, 'max' => 200],
        'body_temperature' => ['unit' => '°C', 'min' => 30, 'max' => 45],
        'steps' => ['unit' => 'count', 'min' => 0, 'max' => 200000],
        'distance' => ['unit' => 'm', 'min' => 0, 'max' => 200000],
        'active_calories' => ['unit' => 'kcal', 'min' => 0, 'max' => 10000],
        'total_calories' => ['unit' => 'kcal', 'min' => 0, 'max' => 15000],
        'exercise_minutes' => ['unit' => 'min', 'min' => 0, 'max' => 1440],
        'heart_rate' => ['unit' => 'bpm', 'min' => 20, 'max' => 250],
        'resting_heart_rate' => ['unit' => 'bpm', 'min' => 20, 'max' => 150],
        'blood_pressure' => ['unit' => 'mmHg', 'min' => 50, 'max' => 260],
        'spo2' => ['unit' => '%', 'min' => 50, 'max' => 100],
        'respiratory_rate' => ['unit' => 'breaths/min', 'min' => 5, 'max' => 60],
        'sleep_duration' => ['unit' => 'min', 'min' => 0, 'max' => 1440],
        'time_in_bed' => ['unit' => 'min', 'min' => 0, 'max' => 1440],
        'deep_sleep' => ['unit' => 'min', 'min' => 0, 'max' => 720],
        'rem_sleep' => ['unit' => 'min', 'min' => 0, 'max' => 720],
        'light_sleep' => ['unit' => 'min', 'min' => 0, 'max' => 720],
        'sleep_score' => ['unit' => 'points', 'min' => 0, 'max' => 100],
        'calories_consumed' => ['unit' => 'kcal', 'min' => 0, 'max' => 15000],
        'protein' => ['unit' => 'g', 'min' => 0, 'max' => 500],
        'carbohydrates' => ['unit' => 'g', 'min' => 0, 'max' => 1000],
        'fat' => ['unit' => 'g', 'min' => 0, 'max' => 500],
        'water' => ['unit' => 'ml', 'min' => 0, 'max' => 20000],
        'alcohol' => ['unit' => 'g', 'min' => 0, 'max' => 500],
        'mood' => ['unit' => 'score', 'min' => 1, 'max' => 5],
        'energy' => ['unit' => 'score', 'min' => 1, 'max' => 5],
        'stress' => ['unit' => 'score', 'min' => 1, 'max' => 5],
        'pain' => ['unit' => 'score', 'min' => 0, 'max' => 10],
    ];

    /**
     * Blood pressure rides on one row: value is systolic, secondary_value is
     * diastolic, tertiary_value is pulse. Kept here (not in METRICS) because
     * the component fields have their own ranges.
     *
     * @var array{secondary: MetricSpec, tertiary: MetricSpec}
     */
    public const BLOOD_PRESSURE_COMPONENTS = [
        'secondary' => ['unit' => 'mmHg', 'min' => 30, 'max' => 160],
        'tertiary' => ['unit' => 'bpm', 'min' => 20, 'max' => 250],
    ];

    /**
     * Known context keys for measurement payloads (api-contract §3).
     *
     * @var list<string>
     */
    public const CONTEXT_KEYS = ['posture', 'arm', 'circumstances', 'notes', 'device'];

    /**
     * Allowed record sources.
     *
     * @var list<string>
     */
    public const SOURCES = ['manual', 'health_connect', 'imported', 'derived'];

    /**
     * Look up a metric spec by wire name.
     *
     * @return MetricSpec|null
     */
    public static function specFor(string $wireName): ?array
    {
        return self::METRICS[$wireName] ?? null;
    }

    /**
     * All known wire names.
     *
     * @return list<string>
     */
    public static function wireNames(): array
    {
        return array_keys(self::METRICS);
    }
}
