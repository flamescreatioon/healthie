<?php

namespace App\Services;

use App\Models\Meal;
use App\Models\Measurement;
use App\Models\SleepSession;
use App\Models\User;
use App\Models\Workout;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * Applies the offline-first replication protocol (docs/backend/04-sync-endpoints.md).
 *
 * Push semantics per row: unknown id inserts; an edit to a tombstone is
 * rejected; a concurrent edit applies only when incoming client_updated_at is
 * newer (server wins ties); deletes always apply and are idempotent.
 */
class SyncService
{
    /**
     * Entity types the sync protocol accepts, mapped to their model.
     *
     * @var array<string, class-string<Model>>
     */
    public const ENTITY_MODELS = [
        'measurements' => Measurement::class,
        'workouts' => Workout::class,
        'sleep_sessions' => SleepSession::class,
        'meals' => Meal::class,
    ];

    /**
     * Validate and normalize one upload batch row.
     *
     * @param  array<string, mixed>  $row
     * @return array{entity_type: string, entity_id: string, operation: string, payload: array<string, mixed>, client_updated_at: string}|null
     */
    public function normalizeRow(array $row): ?array
    {
        $entityType = $row['entity_type'] ?? null;
        $entityId = $row['entity_id'] ?? null;
        $operation = $row['operation'] ?? null;
        $payload = $row['payload'] ?? null;
        $clientUpdatedAt = $row['client_updated_at'] ?? null;

        if (! is_string($entityType) || ! isset(self::ENTITY_MODELS[$entityType])) {
            return null;
        }

        if (! is_string($entityId) || ! is_string($operation) || ! in_array($operation, ['upsert', 'delete'], true)) {
            return null;
        }

        if (! is_array($payload) || ! is_string($clientUpdatedAt)) {
            return null;
        }

        return [
            'entity_type' => $entityType,
            'entity_id' => $entityId,
            'operation' => $operation,
            'payload' => $payload,
            'client_updated_at' => $clientUpdatedAt,
        ];
    }

    /**
     * Apply one normalized row. Returns its sync_push status and server row.
     *
     * @param  array{entity_type: string, entity_id: string, operation: string, payload: array<string, mixed>, client_updated_at: string}  $row
     * @return array{status: string, server_row: array<string, mixed>|null}
     */
    public function applyRow(User $user, array $row): array
    {
        /** @var class-string<Model> $modelClass */
        $modelClass = self::ENTITY_MODELS[$row['entity_type']];

        /** @var Model|null $existing */
        $existing = $modelClass::withTrashed()
            ->where('id', $row['entity_id'])
            ->whereBelongsTo($user)
            ->first();

        if ($row['operation'] === 'delete') {
            if ($existing === null || $existing->trashed()) {
                return ['status' => 'applied', 'server_row' => null];
            }

            $existing->delete();

            return ['status' => 'applied', 'server_row' => null];
        }

        if ($existing !== null && $existing->trashed()) {
            return ['status' => 'rejected', 'server_row' => $existing->toArray()];
        }

        $incomingTs = Carbon::parse($row['client_updated_at']);

        if ($existing !== null) {
            $storedTs = $existing->getAttribute('client_updated_at');

            if ($storedTs !== null && ! $incomingTs->greaterThan($storedTs)) {
                return ['status' => 'conflict', 'server_row' => $existing->toArray()];
            }
        }

        $attributes = $this->attributesFor($row, $user);
        $modelClass::updateOrCreate(
            ['id' => $row['entity_id'], 'user_id' => $user->id],
            $attributes
        );

        return ['status' => 'applied', 'server_row' => null];
    }

    /**
     * Build the attribute array for an upsert, stamping ownership and clocks.
     *
     * @param  array{entity_type: string, entity_id: string, operation: string, payload: array<string, mixed>, client_updated_at: string}  $row
     * @return array<string, mixed>
     */
    private function attributesFor(array $row, User $user): array
    {
        $attributes = $row['payload'];
        unset($attributes['id'], $attributes['user_id'], $attributes['server_updated_at']);

        $attributes['user_id'] = $user->id;
        $attributes['client_updated_at'] = Carbon::parse($row['client_updated_at']);

        return $attributes;
    }
}
