<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\SyncService;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class SyncController extends Controller
{
    /**
     * Accept a batch of outbox operations and return per-row results.
     */
    public function upload(Request $request, SyncService $sync): JsonResponse
    {
        $validated = $request->validate([
            'rows' => ['required', 'array', 'max:500'],
            'rows.*.entity_type' => ['required', 'string'],
            'rows.*.entity_id' => ['required', 'string'],
            'rows.*.operation' => ['required', 'string'],
            'rows.*.payload' => ['nullable', 'array'],
            'rows.*.client_updated_at' => ['required', 'date'],
        ]);

        $user = $request->user();
        $results = [];

        DB::transaction(function () use ($validated, $sync, $user, &$results): void {
            foreach ($validated['rows'] as $raw) {
                $row = $sync->normalizeRow($raw);

                if ($row === null) {
                    $results[] = [
                        'entity_id' => $raw['entity_id'] ?? null,
                        'status' => 'invalid',
                        'server_row' => null,
                    ];

                    continue;
                }

                $applied = $sync->applyRow($user, $row);
                $results[] = ['entity_id' => $row['entity_id']] + $applied;
            }
        });

        return response()->json([
            'results' => $results,
            'server_timestamp' => Carbon::now('UTC')->toIso8601String(),
        ]);
    }

    /**
     * Return the ordered changelog of rows changed after a watermark.
     */
    public function changes(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'since' => ['nullable', 'date'],
        ]);

        $user = $request->user();
        $since = $validated['since'] ?? null;
        $changes = [];

        /** @var array<string, class-string<Model>> $entityModels */
        $entityModels = SyncService::ENTITY_MODELS;

        foreach ($entityModels as $entityType => $modelClass) {
            $query = $modelClass::withTrashed()
                ->whereBelongsTo($user)
                ->orderBy('server_updated_at', 'asc');

            if ($since !== null) {
                $query->where('server_updated_at', '>', Carbon::parse($since));
            }

            foreach ($query->get() as $model) {
                $changes[] = [
                    'entity_type' => $entityType,
                    'entity_id' => $model->getKey(),
                    'operation' => $model->trashed() ? 'delete' : 'upsert',
                    'payload' => $model->toArray(),
                    'server_updated_at' => $model->getAttribute('server_updated_at')?->toIso8601String(),
                ];
            }
        }

        usort($changes, fn (array $a, array $b): int => strcmp((string) $a['server_updated_at'], (string) $b['server_updated_at']));

        return response()->json([
            'changes' => $changes,
            'server_timestamp' => Carbon::now('UTC')->toIso8601String(),
        ]);
    }
}
