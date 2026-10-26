<?php

namespace App\Policies;

use App\Models\SleepSession;
use App\Models\User;

class SleepSessionPolicy
{
    /**
     * Determine whether the user can view the sleep session.
     */
    public function view(User $user, SleepSession $sleepSession): bool
    {
        return $user->id === $sleepSession->user_id;
    }

    /**
     * Determine whether the user can update the sleep session.
     */
    public function update(User $user, SleepSession $sleepSession): bool
    {
        return $user->id === $sleepSession->user_id;
    }

    /**
     * Determine whether the user can delete the sleep session.
     */
    public function delete(User $user, SleepSession $sleepSession): bool
    {
        return $user->id === $sleepSession->user_id;
    }

    /**
     * Determine whether the user can restore the sleep session.
     */
    public function restore(User $user, SleepSession $sleepSession): bool
    {
        return $user->id === $sleepSession->user_id;
    }

    /**
     * Determine whether the user can permanently delete the sleep session.
     */
    public function forceDelete(User $user, SleepSession $sleepSession): bool
    {
        return $user->id === $sleepSession->user_id;
    }
}
