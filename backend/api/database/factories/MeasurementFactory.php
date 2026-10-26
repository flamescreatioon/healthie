<?php

namespace Database\Factories;

use App\Models\Measurement;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Measurement>
 */
class MeasurementFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'metric_type' => 'weight',
            'value' => 78.4,
            'unit' => 'kg',
            'recorded_at' => now('UTC')->subHour(),
            'local_day' => now('UTC')->toDateString(),
            'source' => 'manual',
            'client_updated_at' => now('UTC'),
        ];
    }
}
