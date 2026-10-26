<?php

namespace Tests\Feature;

use App\Models\Measurement;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PruneInactiveUsersTest extends TestCase
{
    use RefreshDatabase;

    public function test_prunes_accounts_idle_beyond_retention(): void
    {
        $idle = User::factory()->create(['created_at' => now()->subMonths(30)]);
        Measurement::factory()->for($idle)->create();

        $active = User::factory()->create(['created_at' => now()->subMonths(30)]);
        Measurement::factory()->for($active)->create();
        $active->createToken('mobile', ['sync']);
        $active->tokens()->update(['last_used_at' => now()]);

        $this->artisan('app:prune-inactive-users', ['--months' => 24])
            ->assertSuccessful();

        $this->assertDatabaseMissing('users', ['id' => $idle->id]);
        $this->assertDatabaseMissing('measurements', ['user_id' => $idle->id]);
        $this->assertDatabaseHas('users', ['id' => $active->id]);
        $this->assertDatabaseHas('measurements', ['user_id' => $active->id]);
    }

    public function test_dry_run_deletes_nothing(): void
    {
        User::factory()->create(['created_at' => now()->subMonths(30)]);

        $this->artisan('app:prune-inactive-users', ['--months' => 24, '--dry-run' => true])
            ->assertSuccessful();

        $this->assertDatabaseCount('users', 1);
    }
}
