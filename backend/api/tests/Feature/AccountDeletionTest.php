<?php

namespace Tests\Feature;

use App\Models\Measurement;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AccountDeletionTest extends TestCase
{
    use RefreshDatabase;

    public function test_delete_account_removes_user_and_all_health_rows(): void
    {
        $user = User::factory()->create(['password' => Hash::make('correct-horse-12')]);
        Measurement::factory()->for($user)->count(3)->create();

        Sanctum::actingAs($user);

        $this->deleteJson('/api/v1/account', ['password' => 'correct-horse-12'])
            ->assertOk();

        $this->assertDatabaseCount('users', 0);
        $this->assertDatabaseCount('measurements', 0);
        $this->assertDatabaseCount('personal_access_tokens', 0);
        $this->assertDatabaseCount('sessions', 0);
        $this->assertDatabaseCount('password_reset_tokens', 0);
    }

    public function test_delete_account_requires_correct_password(): void
    {
        $user = User::factory()->create(['password' => Hash::make('correct-horse-12')]);
        Measurement::factory()->for($user)->create();

        Sanctum::actingAs($user);

        $this->deleteJson('/api/v1/account', ['password' => 'wrong-password'])
            ->assertUnprocessable();

        $this->assertDatabaseCount('users', 1);
        $this->assertDatabaseCount('measurements', 1);
    }

    public function test_delete_account_requires_authentication(): void
    {
        $this->deleteJson('/api/v1/account', ['password' => 'anything'])
            ->assertUnauthorized();
    }
}
