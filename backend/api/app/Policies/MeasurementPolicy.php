<?php

namespace App\Policies;

use App\Models\Measurement;
use App\Models\User;

class MeasurementPolicy
{
    /**
     * Determine whether the user can view the measurement.
     */
    public function view(User $user, Measurement $measurement): bool
    {
        return $user->id === $measurement->user_id;
    }

    /**
     * Determine whether the user can update the measurement.
     */
    public function update(User $user, Measurement $measurement): bool
    {
        return $user->id === $measurement->user_id;
    }

    /**
     * Determine whether the user can delete the measurement.
     */
    public function delete(User $user, Measurement $measurement): bool
    {
        return $user->id === $measurement->user_id;
    }

    /**
     * Determine whether the user can restore the measurement.
     */
    public function restore(User $user, Measurement $measurement): bool
    {
        return $user->id === $measurement->user_id;
    }

    /**
     * Determine whether the user can permanently delete the measurement.
     */
    public function forceDelete(User $user, Measurement $measurement): bool
    {
        return $user->id === $measurement->user_id;
    }
}
