<?php

namespace Tests\Feature;

use App\Models\Measurement;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MeasurementCrudTest extends TestCase
{
    use RefreshDatabase;

    public function test_upsert_creates_then_updates_same_id(): void
    {
        $user = User::factory()->create();
        $id = (string) fake()->uuid();

        $create = $this->actingAs($user, 'sanctum')->postJson('/api/v1/measurements', $this->payload($id, 78.4));

        $create->assertCreated()->assertJsonPath('id', $id);

        $update = $this->actingAs($user, 'sanctum')->postJson('/api/v1/measurements', $this->payload($id, 79.1));

        $update->assertOk()->assertJsonPath('value', 79.1);

        $this->assertDatabaseCount('measurements', 1);
    }

    public function test_validation_rejects_wrong_unit_and_out_of_range(): void
    {
        $user = User::factory()->create();

        $wrongUnit = $this->actingAs($user, 'sanctum')->postJson(
            '/api/v1/measurements',
            $this->payload((string) fake()->uuid(), 78.4, 'lb')
        );

        $wrongUnit->assertUnprocessable()->assertJsonValidationErrors('unit');

        $outOfRange = $this->actingAs($user, 'sanctum')->postJson(
            '/api/v1/measurements',
            $this->payload((string) fake()->uuid(), 900)
        );

        $outOfRange->assertUnprocessable()->assertJsonValidationErrors('value');

        $this->assertDatabaseCount('measurements', 0);
    }

    public function test_delete_soft_deletes_and_hides_row(): void
    {
        $user = User::factory()->create();
        $measurement = Measurement::factory()->for($user)->create();

        $this->actingAs($user, 'sanctum')
            ->deleteJson("/api/v1/measurements/{$measurement->id}")
            ->assertOk();

        $this->assertSoftDeleted('measurements', ['id' => $measurement->id]);

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/measurements')
            ->assertOk()
            ->assertJsonPath('total', 0);
    }

    /**
     * @return array<string, mixed>
     */
    private function payload(string $id, float $value, string $unit = 'kg'): array
    {
        return [
            'id' => $id,
            'metric_type' => 'weight',
            'value' => $value,
            'unit' => $unit,
            'recorded_at' => now('UTC')->toIso8601String(),
            'local_day' => now('UTC')->toDateString(),
            'client_updated_at' => now('UTC')->toIso8601String(),
        ];
    }
}
