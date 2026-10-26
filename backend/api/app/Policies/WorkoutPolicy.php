<?php

namespace App\Policies;

use App\Models\User;
use App\Models\Workout;

class WorkoutPolicy
{
    /**
     * Determine whether the user can view the workout.
     */
    public function view(User $user, Workout $workout): bool
    {
        return $user->id === $workout->user_id;
    }

    /**
     * Determine whether the user can update the workout.
     */
    public function update(User $user, Workout $workout): bool
    {
        return $user->id === $workout->user_id;
    }

    /**
     * Determine whether the user can delete the workout.
     */
    public function delete(User $user, Workout $workout): bool
    {
        return $user->id === $workout->user_id;
    }

    /**
     * Determine whether the user can restore the workout.
     */
    public function restore(User $user, Workout $workout): bool
    {
        return $user->id === $workout->user_id;
    }

    /**
     * Determine whether the user can permanently delete the workout.
     */
    public function forceDelete(User $user, Workout $workout): bool
    {
        return $user->id === $workout->user_id;
    }
}
