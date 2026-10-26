<?php

namespace Tests\Feature;

use App\Models\Measurement;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SyncProtocolTest extends TestCase
{
    use RefreshDatabase;

    public function test_upload_applies_new_row_and_returns_server_timestamp(): void
    {
        $user = User::factory()->create();
        $id = (string) fake()->uuid();

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/sync/upload', [
            'rows' => [[
                'entity_type' => 'measurements',
                'entity_id' => $id,
                'operation' => 'upsert',
                'payload' => $this->measurementPayload($id, 78.4),
                'client_updated_at' => now('UTC')->toIso8601String(),
            ]],
        ]);

        $response->assertOk()
            ->assertJsonPath('results.0.entity_id', $id)
            ->assertJsonPath('results.0.status', 'applied')
            ->assertJsonStructure(['server_timestamp']);

        $this->assertDatabaseHas('measurements', ['id' => $id, 'user_id' => $user->id]);
    }

    public function test_stale_edit_conflicts_and_fresh_edit_wins(): void
    {
        $user = User::factory()->create();
        $id = (string) fake()->uuid();

        Measurement::factory()->for($user)->create([
            'id' => $id,
            'value' => 80.0,
            'client_updated_at' => now('UTC'),
        ]);

        $stale = $this->actingAs($user, 'sanctum')->postJson('/api/v1/sync/upload', [
            'rows' => [[
                'entity_type' => 'measurements',
                'entity_id' => $id,
                'operation' => 'upsert',
                'payload' => $this->measurementPayload($id, 75.0),
                'client_updated_at' => now('UTC')->subDay()->toIso8601String(),
            ]],
        ]);

        $stale->assertOk()->assertJsonPath('results.0.status', 'conflict');
        $this->assertDatabaseHas('measurements', ['id' => $id, 'value' => 80.0]);

        $fresh = $this->actingAs($user, 'sanctum')->postJson('/api/v1/sync/upload', [
            'rows' => [[
                'entity_type' => 'measurements',
                'entity_id' => $id,
                'operation' => 'upsert',
                'payload' => $this->measurementPayload($id, 79.5),
                'client_updated_at' => now('UTC')->addMinute()->toIso8601String(),
            ]],
        ]);

        $fresh->assertOk()->assertJsonPath('results.0.status', 'applied');
        $this->assertDatabaseHas('measurements', ['id' => $id, 'value' => 79.5]);
    }

    public function test_edit_to_tombstone_is_rejected_and_delete_is_idempotent(): void
    {
        $user = User::factory()->create();
        $id = (string) fake()->uuid();

        Measurement::factory()->for($user)->create(['id' => $id]);

        $delete = $this->actingAs($user, 'sanctum')->postJson('/api/v1/sync/upload', [
            'rows' => [[
                'entity_type' => 'measurements',
                'entity_id' => $id,
                'operation' => 'delete',
                'payload' => [],
                'client_updated_at' => now('UTC')->toIso8601String(),
            ]],
        ]);

        $delete->assertOk()->assertJsonPath('results.0.status', 'applied');
        $this->assertSoftDeleted('measurements', ['id' => $id]);

        // Retrying the delete is a no-op, not an error.
        $retry = $this->actingAs($user, 'sanctum')->postJson('/api/v1/sync/upload', [
            'rows' => [[
                'entity_type' => 'measurements',
                'entity_id' => $id,
                'operation' => 'delete',
                'payload' => [],
                'client_updated_at' => now('UTC')->toIso8601String(),
            ]],
        ]);

        $retry->assertOk()->assertJsonPath('results.0.status', 'applied');

        // Editing the tombstone is rejected with the deleted row returned.
        $edit = $this->actingAs($user, 'sanctum')->postJson('/api/v1/sync/upload', [
            'rows' => [[
                'entity_type' => 'measurements',
                'entity_id' => $id,
                'operation' => 'upsert',
                'payload' => $this->measurementPayload($id, 81.0),
                'client_updated_at' => now('UTC')->addMinute()->toIso8601String(),
            ]],
        ]);

        $edit->assertOk()
            ->assertJsonPath('results.0.status', 'rejected')
            ->assertJsonPath('results.0.server_row.id', $id);
    }

    public function test_changes_returns_ordered_changelog_scoped_to_user(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();

        Measurement::factory()->for($user)->create();
        Measurement::factory()->for($other)->create();

        $response = $this->actingAs($user, 'sanctum')->getJson('/api/v1/sync/changes');

        $response->assertOk()->assertJsonStructure(['changes', 'server_timestamp']);

        $changes = $response->json('changes');
        $this->assertCount(1, $changes);
        $this->assertSame('measurements', $changes[0]['entity_type']);
        $this->assertSame('upsert', $changes[0]['operation']);
    }

    public function test_unknown_entity_type_returns_invalid_not_500(): void
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/sync/upload', [
            'rows' => [[
                'entity_type' => 'telepathy',
                'entity_id' => (string) fake()->uuid(),
                'operation' => 'upsert',
                'payload' => [],
                'client_updated_at' => now('UTC')->toIso8601String(),
            ]],
        ]);

        $response->assertOk()->assertJsonPath('results.0.status', 'invalid');
    }

    /**
     * @return array<string, mixed>
     */
    private function measurementPayload(string $id, float $value): array
    {
        return [
            'id' => $id,
            'metric_type' => 'weight',
            'value' => $value,
            'unit' => 'kg',
            'recorded_at' => now('UTC')->toIso8601String(),
            'local_day' => now('UTC')->toDateString(),
        ];
    }
}
