<?php

namespace App\Http\Requests;

use App\Support\MetricCatalog;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

class StoreWorkoutRequest extends FormRequest
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
            'workout_type' => ['required', 'string', 'in:running,walking,cycling,strength,swimming,yoga,other'],
            'started_at' => ['required', 'date'],
            'ended_at' => ['required', 'date', 'after:started_at'],
            'duration_seconds' => ['required', 'integer', 'min:0', 'max:86400'],
            'distance_meters' => ['nullable', 'numeric', 'min:0'],
            'calories' => ['nullable', 'integer', 'min:0'],
            'average_heart_rate' => ['nullable', 'integer', 'min:20', 'max:250'],
            'source' => ['sometimes', 'string', 'in:'.implode(',', MetricCatalog::SOURCES)],
            'client_updated_at' => ['required', 'date'],
        ];
    }
}
