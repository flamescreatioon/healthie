<?php

namespace Database\Factories;

use App\Models\Meal;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Meal>
 */
class MealFactory extends Factory
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
            'meal_type' => 'breakfast',
            'name' => 'Oatmeal',
            'calories' => 350,
            'protein_g' => 12,
            'carbs_g' => 60,
            'fat_g' => 8,
            'eaten_at' => now('UTC')->subHours(2),
            'local_day' => now('UTC')->toDateString(),
            'source' => 'manual',
            'client_updated_at' => now('UTC'),
        ];
    }
}
