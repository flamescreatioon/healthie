<?php

namespace Tests\Feature;

use App\Models\Measurement;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ExportTest extends TestCase
{
    use RefreshDatabase;

    public function test_export_returns_json_with_reference_and_filters(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();

        Measurement::factory()->for($user)->create(['local_day' => '2026-03-10']);
        Measurement::factory()->for($user)->create(['local_day' => '2026-04-10']);
        Measurement::factory()->for($other)->create(['local_day' => '2026-03-10']);

        Sanctum::actingAs($user);

        $response = $this->getJson('/api/v1/exports/measurements?from=2026-03-01&to=2026-03-31');

        $response->assertOk()
            ->assertJsonStructure(['export_reference', 'generated_at', 'schema_version', 'filters', 'measurements'])
            ->assertJsonPath('schema_version', config('healthie.export_schema_version'));

        $measurements = $response->json('measurements');
        $this->assertCount(1, $measurements);
        $this->assertStringStartsWith('2026-03-10', $measurements[0]['local_day']);
    }

    public function test_export_csv_downloads_rows(): void
    {
        $user = User::factory()->create();
        Measurement::factory()->for($user)->create();

        Sanctum::actingAs($user);

        $response = $this->get('/api/v1/exports/measurements?format=csv');

        $response->assertOk();
        $this->assertStringContainsString('text/csv', $response->headers->get('Content-Type'));
        $this->assertStringContainsString('metric_type', $response->streamedContent());
    }

    public function test_export_rejects_inverted_range(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/v1/exports/measurements?from=2026-04-01&to=2026-03-01')
            ->assertUnprocessable();
    }
}
