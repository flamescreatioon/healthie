<?php

namespace Database\Factories;

use App\Models\User;
use App\Models\Workout;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Workout>
 */
class WorkoutFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $started = now('UTC')->subHour();

        return [
            'user_id' => User::factory(),
            'workout_type' => 'running',
            'started_at' => $started,
            'ended_at' => (clone $started)->addMinutes(30),
            'duration_seconds' => 1800,
            'distance_meters' => 5000,
            'calories' => 320,
            'average_heart_rate' => 142,
            'source' => 'manual',
            'client_updated_at' => now('UTC'),
        ];
    }
}
