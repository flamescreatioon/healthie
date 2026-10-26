<?php

namespace Database\Factories;

use App\Models\SleepSession;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<SleepSession>
 */
class SleepSessionFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $started = now('UTC')->subHours(9);

        return [
            'user_id' => User::factory(),
            'started_at' => $started,
            'ended_at' => (clone $started)->addHours(8),
            'duration_minutes' => 480,
            'deep_minutes' => 90,
            'rem_minutes' => 110,
            'light_minutes' => 250,
            'awake_minutes' => 30,
            'source' => 'manual',
            'client_updated_at' => now('UTC'),
        ];
    }
}
