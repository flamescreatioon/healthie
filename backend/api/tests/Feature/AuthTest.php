<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_register_and_receives_token(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Ada',
            'email' => 'ada@example.com',
            'password' => 'correct-horse-12',
            'password_confirmation' => 'correct-horse-12',
        ]);

        $response->assertCreated()
            ->assertJsonPath('user.email', 'ada@example.com')
            ->assertJsonStructure(['user' => ['id', 'name', 'email'], 'token']);

        $this->assertDatabaseHas('users', ['email' => 'ada@example.com']);
    }

    public function test_registration_rejects_duplicate_email(): void
    {
        User::factory()->create(['email' => 'ada@example.com']);

        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Ada',
            'email' => 'ada@example.com',
            'password' => 'correct-horse-12',
            'password_confirmation' => 'correct-horse-12',
        ]);

        $response->assertUnprocessable()->assertJsonValidationErrors('email');
    }

    public function test_user_can_login_and_logout(): void
    {
        User::factory()->create(['email' => 'ada@example.com']);

        $login = $this->postJson('/api/v1/auth/login', [
            'email' => 'ada@example.com',
            'password' => 'password',
        ]);

        $login->assertOk()->assertJsonStructure(['user' => ['id', 'email'], 'token']);

        $token = $login->json('token');

        $this->assertDatabaseCount('personal_access_tokens', 1);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/v1/auth/logout')
            ->assertOk();

        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_revoked_token_is_rejected(): void
    {
        $user = User::factory()->create();

        $token = $user->createToken('mobile', ['sync'])->plainTextToken;
        $user->tokens()->delete();

        // Fresh guard state: the deleted token resolves to no user.
        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/measurements')
            ->assertUnauthorized();
    }

    public function test_login_rejects_wrong_password(): void
    {
        User::factory()->create(['email' => 'ada@example.com']);

        $this->postJson('/api/v1/auth/login', [
            'email' => 'ada@example.com',
            'password' => 'wrong-password',
        ])->assertUnprocessable();
    }

    public function test_private_routes_require_authentication(): void
    {
        $this->getJson('/api/v1/measurements')->assertUnauthorized();
    }
}
