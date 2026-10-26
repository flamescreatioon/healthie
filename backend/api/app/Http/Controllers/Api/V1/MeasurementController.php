<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreMeasurementRequest;
use App\Models\Measurement;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class MeasurementController extends Controller
{
    /**
     * List the authenticated user's measurements with filters.
     */
    public function index(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'metric_type' => ['sometimes', 'string'],
            'recorded_at.gte' => ['sometimes', 'date'],
            'recorded_at.lt' => ['sometimes', 'date'],
            'is_synced' => ['sometimes', 'boolean'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);

        $query = Measurement::ownedBy($request->user())->orderBy('recorded_at', 'desc');

        if (isset($validated['metric_type'])) {
            $query->where('metric_type', $validated['metric_type']);
        }

        if (isset($validated['recorded_at']['gte'])) {
            $query->where('recorded_at', '>=', $validated['recorded_at']['gte']);
        }

        if (isset($validated['recorded_at']['lt'])) {
            $query->where('recorded_at', '<', $validated['recorded_at']['lt']);
        }

        return response()->json($query->paginate($validated['per_page'] ?? 50));
    }

    /**
     * Upsert one measurement idempotently by client-generated id.
     */
    public function store(StoreMeasurementRequest $request): JsonResponse
    {
        $validated = $request->validated();
        $user = $request->user();

        $measurement = Measurement::ownedBy($user)->find($validated['id']);

        if ($measurement !== null) {
            Gate::authorize('update', $measurement);
            $measurement->update($validated);

            return response()->json($measurement->fresh(), 200);
        }

        $measurement = Measurement::create($validated + ['user_id' => $user->id]);

        return response()->json($measurement, 201);
    }

    /**
     * Read one measurement. Unknown or foreign ids return 404.
     */
    public function show(Request $request, string $id): JsonResponse
    {
        $measurement = Measurement::ownedBy($request->user())->find($id);

        if ($measurement === null) {
            return response()->json(['error' => 'not_found', 'message' => 'Measurement not found.'], 404);
        }

        return response()->json($measurement);
    }

    /**
     * Update one measurement.
     */
    public function update(StoreMeasurementRequest $request, string $id): JsonResponse
    {
        $measurement = Measurement::ownedBy($request->user())->find($id);

        if ($measurement === null) {
            return response()->json(['error' => 'not_found', 'message' => 'Measurement not found.'], 404);
        }

        $measurement->update($request->validated());

        return response()->json($measurement->fresh());
    }

    /**
     * Soft-delete one measurement (tombstone, never a hard delete).
     */
    public function destroy(Request $request, string $id): JsonResponse
    {
        $measurement = Measurement::ownedBy($request->user())->find($id);

        if ($measurement === null) {
            return response()->json(['error' => 'not_found', 'message' => 'Measurement not found.'], 404);
        }

        $measurement->delete();

        return response()->json(['message' => 'Measurement deleted.']);
    }
}
