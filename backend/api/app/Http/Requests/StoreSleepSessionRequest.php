<?php

namespace App\Http\Requests;

use App\Support\MetricCatalog;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

class StoreSleepSessionRequest extends FormRequest
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
            'started_at' => ['required', 'date'],
            'ended_at' => ['required', 'date', 'after:started_at'],
            'duration_minutes' => ['required', 'integer', 'min:0', 'max:1440'],
            'deep_minutes' => ['nullable', 'integer', 'min:0', 'max:720'],
            'rem_minutes' => ['nullable', 'integer', 'min:0', 'max:720'],
            'light_minutes' => ['nullable', 'integer', 'min:0', 'max:720'],
            'awake_minutes' => ['nullable', 'integer', 'min:0', 'max:720'],
            'source' => ['sometimes', 'string', 'in:'.implode(',', MetricCatalog::SOURCES)],
            'client_updated_at' => ['required', 'date'],
        ];
    }
}
