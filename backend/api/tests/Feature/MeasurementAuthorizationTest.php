<?php

namespace Tests\Feature;

use App\Models\Measurement;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MeasurementAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    public function test_second_user_sees_nothing_and_cannot_touch_first_users_rows(): void
    {
        $ada = User::factory()->create();
        $bob = User::factory()->create();
        $measurement = Measurement::factory()->for($ada)->create();

        $asBob = $this->actingAs($bob, 'sanctum');

        $asBob->getJson('/api/v1/measurements')
            ->assertOk()
            ->assertJsonPath('total', 0);

        $asBob->getJson("/api/v1/measurements/{$measurement->id}")->assertNotFound();
        $asBob->putJson("/api/v1/measurements/{$measurement->id}", $this->payload($measurement->id))->assertNotFound();
        $asBob->deleteJson("/api/v1/measurements/{$measurement->id}")->assertNotFound();

        // Ada's row is untouched: still one row, still hers.
        $this->assertDatabaseCount('measurements', 1);
        $this->assertDatabaseHas('measurements', ['id' => $measurement->id, 'user_id' => $ada->id]);
    }

    /**
     * @return array<string, mixed>
     */
    private function payload(string $id): array
    {
        return [
            'id' => $id,
            'metric_type' => 'weight',
            'value' => 79.1,
            'unit' => 'kg',
            'recorded_at' => now('UTC')->toIso8601String(),
            'local_day' => now('UTC')->toDateString(),
            'client_updated_at' => now('UTC')->toIso8601String(),
        ];
    }
}
