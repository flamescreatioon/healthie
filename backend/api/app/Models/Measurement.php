<?php

namespace App\Models;

use App\Models\Concerns\HasServerWatermark;
use Database\Factories\MeasurementFactory;
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
    'metric_type',
    'value',
    'unit',
    'secondary_value',
    'secondary_unit',
    'tertiary_value',
    'tertiary_unit',
    'recorded_at',
    'local_day',
    'source',
    'context_json',
    'client_updated_at',
])]
#[Hidden(['user_id'])]
class Measurement extends Model
{
    /** @use HasFactory<MeasurementFactory> */
    use HasFactory, HasServerWatermark, HasUuids, SoftDeletes;

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'value' => 'float',
            'secondary_value' => 'float',
            'tertiary_value' => 'float',
            'recorded_at' => 'datetime',
            'local_day' => 'date',
            'context_json' => 'array',
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
