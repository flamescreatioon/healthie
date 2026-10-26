<?php

namespace App\Policies;

use App\Models\Meal;
use App\Models\User;

class MealPolicy
{
    /**
     * Determine whether the user can view the meal.
     */
    public function view(User $user, Meal $meal): bool
    {
        return $user->id === $meal->user_id;
    }

    /**
     * Determine whether the user can update the meal.
     */
    public function update(User $user, Meal $meal): bool
    {
        return $user->id === $meal->user_id;
    }

    /**
     * Determine whether the user can delete the meal.
     */
    public function delete(User $user, Meal $meal): bool
    {
        return $user->id === $meal->user_id;
    }

    /**
     * Determine whether the user can restore the meal.
     */
    public function restore(User $user, Meal $meal): bool
    {
        return $user->id === $meal->user_id;
    }

    /**
     * Determine whether the user can permanently delete the meal.
     */
    public function forceDelete(User $user, Meal $meal): bool
    {
        return $user->id === $meal->user_id;
    }
}
