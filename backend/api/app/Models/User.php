<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\HasApiTokens;

#[Fillable(['name', 'display_name', 'email', 'password', 'unit_preferences'])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'unit_preferences' => 'array',
        ];
    }

    /**
     * @return HasMany<Measurement, $this>
     */
    public function measurements(): HasMany
    {
        return $this->hasMany(Measurement::class);
    }

    /**
     * @return HasMany<Workout, $this>
     */
    public function workouts(): HasMany
    {
        return $this->hasMany(Workout::class);
    }

    /**
     * @return HasMany<SleepSession, $this>
     */
    public function sleepSessions(): HasMany
    {
        return $this->hasMany(SleepSession::class);
    }

    /**
     * @return HasMany<Meal, $this>
     */
    public function meals(): HasMany
    {
        return $this->hasMany(Meal::class);
    }

    /**
     * Delete the account and everything it owns. Final: health rows cascade
     * from the users foreign key; tokens, sessions, and reset tokens have no
     * database cascade and are removed here first.
     */
    public function deleteAccount(): void
    {
        DB::transaction(function (): void {
            $this->tokens()->delete();
            DB::table('sessions')->where('user_id', $this->id)->delete();
            DB::table('password_reset_tokens')->where('email', $this->email)->delete();
            $this->forceDelete();
        });
    }
}
