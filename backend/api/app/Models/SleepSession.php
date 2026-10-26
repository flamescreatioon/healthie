<?php

namespace App\Models;

use App\Models\Concerns\HasServerWatermark;
use Database\Factories\SleepSessionFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Attributes\Scope;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable([
    'id',
    'user_id',
    'started_at',
    'ended_at',
    'duration_minutes',
    'deep_minutes',
    'rem_minutes',
    'light_minutes',
    'awake_minutes',
    'source',
    'client_updated_at',
])]
#[Hidden(['user_id'])]
class SleepSession extends Model
{
    /** @use HasFactory<SleepSessionFactory> */
    use HasFactory, HasServerWatermark, HasUuids, SoftDeletes;

    /**
     * The table associated with the model.
     *
     * @var string
     */
    protected $table = 'sleep_sessions';

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'started_at' => 'datetime',
            'ended_at' => 'datetime',
            'duration_minutes' => 'integer',
            'deep_minutes' => 'integer',
            'rem_minutes' => 'integer',
            'light_minutes' => 'integer',
            'awake_minutes' => 'integer',
            'client_updated_at' => 'datetime',
            'server_updated_at' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Scope a query to rows owned by the given user.
     */
    #[Scope]
    protected function ownedBy(Builder $query, User $user): Builder
    {
        return $query->whereBelongsTo($user);
    }

    /**
     * Scope a query to rows changed after a server watermark.
     */
    #[Scope]
    protected function changedSince(Builder $query, string $watermark): Builder
    {
        return $query->where('server_updated_at', '>', $watermark);
    }
}
