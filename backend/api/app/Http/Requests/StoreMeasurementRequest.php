<?php

namespace App\Http\Requests;

use App\Support\MetricCatalog;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class StoreMeasurementRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'id' => ['required', 'uuid'],
            'metric_type' => ['required', 'string', 'in:'.implode(',', MetricCatalog::wireNames())],
            'value' => ['required', 'numeric'],
            'unit' => ['required', 'string', 'max:32'],
            'secondary_value' => ['nullable', 'numeric'],
            'secondary_unit' => ['nullable', 'string', 'max:32'],
            'tertiary_value' => ['nullable', 'numeric'],
            'tertiary_unit' => ['nullable', 'string', 'max:32'],
            'recorded_at' => ['required', 'date'],
            'local_day' => ['required', 'date_format:Y-m-d'],
            'source' => ['sometimes', 'string', 'in:'.implode(',', MetricCatalog::SOURCES)],
            'context_json' => ['nullable', 'array'],
            'client_updated_at' => ['required', 'date'],
        ];
    }

    /**
     * Cross-field checks: canonical unit, plausible ranges, composite BP.
     *
     * @return array<int, \Closure(string, mixed, \Closure(string): void): void>
     */
    public function after(): array
    {
        return [
            function (Validator $validator): void {
                if ($validator->errors()->any()) {
                    return;
                }

                $metricType = (string) $this->input('metric_type');
                $spec = MetricCatalog::specFor($metricType);

                if ($spec === null) {
                    return;
                }

                $this->checkRange($validator, 'value', (float) $this->input('value'), $spec['min'], $spec['max'], $spec['unit']);

                if ($this->input('unit') !== $spec['unit']) {
                    $validator->errors()->add('unit', "Unit must be {$spec['unit']} for {$metricType}. Convert before saving.");
                }

                if ($metricType === 'blood_pressure') {
                    $this->checkBloodPressureComponents($validator);
                }

                $this->checkContextKeys($validator);
            },
        ];
    }

    /**
     * Validate blood pressure component fields.
     */
    private function checkBloodPressureComponents(Validator $validator): void
    {
        $diastolic = $this->input('secondary_value');
        $pulse = $this->input('tertiary_value');

        if ($diastolic === null) {
            $validator->errors()->add('secondary_value', 'Diastolic value is required for blood_pressure.');

            return;
        }

        $components = MetricCatalog::BLOOD_PRESSURE_COMPONENTS;
        $this->checkRange($validator, 'secondary_value', (float) $diastolic, $components['secondary']['min'], $components['secondary']['max'], $components['secondary']['unit']);

        if ($this->input('secondary_unit') !== $components['secondary']['unit']) {
            $validator->errors()->add('secondary_unit', 'Secondary unit must be mmHg for blood_pressure.');
        }

        if ($pulse !== null) {
            $this->checkRange($validator, 'tertiary_value', (float) $pulse, $components['tertiary']['min'], $components['tertiary']['max'], $components['tertiary']['unit']);

            if ($this->input('tertiary_unit') !== $components['tertiary']['unit']) {
                $validator->errors()->add('tertiary_unit', 'Tertiary unit must be bpm for blood_pressure.');
            }
        }
    }

    /**
     * Reject unknown context keys.
     */
    private function checkContextKeys(Validator $validator): void
    {
        $context = $this->input('context_json');

        if (! is_array($context)) {
            return;
        }

        foreach (array_keys($context) as $key) {
            if (! in_array($key, MetricCatalog::CONTEXT_KEYS, true)) {
                $validator->errors()->add('context_json', "Unknown context key: {$key}.");
            }
        }
    }

    /**
     * Add a range error without silently clamping.
     *
     * @param  array{min: float, max: float}  $bounds
     */
    private function checkRange(Validator $validator, string $field, float $value, float $min, float $max, string $unit): void
    {
        if ($value < $min || $value > $max) {
            $validator->errors()->add($field, "Enter a value between {$min} and {$max} {$unit}.");
        }
    }
}
