<?php

namespace App\Http\Requests;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

class RegisterRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'display_name' => ['nullable', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'confirmed', Password::min(12)],
            'unit_preferences' => ['nullable', 'array'],
            'unit_preferences.mass' => ['nullable', 'string', 'in:kg,lb'],
            'unit_preferences.length' => ['nullable', 'string', 'in:cm,in'],
            'unit_preferences.temperature' => ['nullable', 'string', 'in:c,f'],
            'unit_preferences.volume' => ['nullable', 'string', 'in:ml,l,fl_oz'],
        ];
    }
}
