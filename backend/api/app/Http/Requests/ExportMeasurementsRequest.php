<?php

namespace App\Http\Requests;

use App\Support\MetricCatalog;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class ExportMeasurementsRequest extends FormRequest
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
            'from' => ['nullable', 'date_format:Y-m-d'],
            'to' => ['nullable', 'date_format:Y-m-d'],
            'metric_type' => ['nullable', 'string', 'in:'.implode(',', MetricCatalog::wireNames())],
            'format' => ['sometimes', 'string', 'in:json,csv'],
        ];
    }

    /**
     * The date range must be coherent when both ends are present.
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

                $from = $this->input('from');
                $to = $this->input('to');

                if (is_string($from) && is_string($to) && $to < $from) {
                    $validator->errors()->add('to', 'The end of the range must not be before its start.');
                }
            },
        ];
    }
}
