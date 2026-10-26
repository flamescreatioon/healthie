<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\ExportMeasurementsRequest;
use App\Models\Measurement;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ExportController extends Controller
{
    /**
     * Export the authenticated user's measurements as JSON or CSV.
     *
     * Same shape as the offline Drift export: reference, schema version,
     * applied filters, and rows ordered by recorded time.
     */
    public function measurements(ExportMeasurementsRequest $request): JsonResponse|StreamedResponse
    {
        $validated = $request->validated();

        $query = Measurement::ownedBy($request->user())->orderBy('recorded_at', 'asc');

        if (isset($validated['from'])) {
            $query->where('local_day', '>=', $validated['from']);
        }

        if (isset($validated['to'])) {
            $query->where('local_day', '<=', $validated['to']);
        }

        if (isset($validated['metric_type'])) {
            $query->where('metric_type', $validated['metric_type']);
        }

        $rows = $query->get();

        if (($validated['format'] ?? 'json') === 'csv') {
            return $this->csvResponse($rows->toArray());
        }

        return response()->json([
            'export_reference' => (string) Str::uuid(),
            'generated_at' => now('UTC')->toIso8601String(),
            'schema_version' => config('healthie.export_schema_version'),
            'filters' => [
                'from' => $validated['from'] ?? null,
                'to' => $validated['to'] ?? null,
                'metric_type' => $validated['metric_type'] ?? null,
            ],
            'measurements' => $rows,
        ]);
    }

    /**
     * Stream the rows as a CSV download.
     *
     * @param  array<int, array<string, mixed>>  $rows
     */
    private function csvResponse(array $rows): StreamedResponse
    {
        $filename = 'healthie-measurements-'.now('UTC')->format('Ymd-His').'.csv';

        return response()->streamDownload(function () use ($rows): void {
            $handle = fopen('php://output', 'w');

            fputcsv($handle, [
                'id', 'metric_type', 'value', 'unit',
                'secondary_value', 'secondary_unit', 'tertiary_value', 'tertiary_unit',
                'recorded_at', 'local_day', 'source', 'client_updated_at',
            ]);

            foreach ($rows as $row) {
                fputcsv($handle, [
                    $row['id'] ?? null,
                    $row['metric_type'] ?? null,
                    $row['value'] ?? null,
                    $row['unit'] ?? null,
                    $row['secondary_value'] ?? null,
                    $row['secondary_unit'] ?? null,
                    $row['tertiary_value'] ?? null,
                    $row['tertiary_unit'] ?? null,
                    $row['recorded_at'] ?? null,
                    $row['local_day'] ?? null,
                    $row['source'] ?? null,
                    $row['client_updated_at'] ?? null,
                ]);
            }

            fclose($handle);
        }, $filename, ['Content-Type' => 'text/csv']);
    }
}
