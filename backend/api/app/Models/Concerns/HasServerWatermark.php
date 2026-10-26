<?php

namespace App\Models\Concerns;

use Illuminate\Database\Eloquent\Model;

/**
 * Stamp server_updated_at on every write so the sync pull cursor moves.
 *
 * Regular inserts/updates are covered by the saving hook. Soft deletes run a
 * direct update query without firing saving, so the deleting hook stages the
 * watermark and SoftDeletes merges it via getDirty(). Force deletes remove
 * the row entirely and need no watermark.
 */
trait HasServerWatermark
{
    /**
     * Boot the trait and register the watermark hooks.
     */
    public static function bootHasServerWatermark(): void
    {
        static::saving(function (Model $model): void {
            $model->server_updated_at = $model->freshTimestamp();
        });

        static::deleting(function (Model $model): void {
            if (! $model->isForceDeleting()) {
                $model->server_updated_at = $model->freshTimestamp();
            }
        });
    }
}
