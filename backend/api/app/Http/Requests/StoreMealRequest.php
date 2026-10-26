<?php

namespace App\Http\Requests;

use App\Support\MetricCatalog;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

class StoreMealRequest extends FormRequest
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
            'meal_type' => ['required', 'string', 'in:breakfast,lunch,dinner,snack'],
            'name' => ['required', 'string', 'max:255'],
            'calories' => ['nullable', 'integer', 'min:0', 'max:15000'],
            'protein_g' => ['nullable', 'numeric', 'min:0', 'max:500'],
            'carbs_g' => ['nullable', 'numeric', 'min:0', 'max:1000'],
            'fat_g' => ['nullable', 'numeric', 'min:0', 'max:500'],
            'eaten_at' => ['required', 'date'],
            'local_day' => ['required', 'date_format:Y-m-d'],
            'source' => ['sometimes', 'string', 'in:'.implode(',', MetricCatalog::SOURCES)],
            'client_updated_at' => ['required', 'date'],
        ];
    }
}
