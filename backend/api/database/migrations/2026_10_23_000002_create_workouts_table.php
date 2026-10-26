<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('workouts', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('workout_type');
            $table->timestampTz('started_at');
            $table->timestampTz('ended_at');
            $table->integer('duration_seconds');
            $table->double('distance_meters')->nullable();
            $table->integer('calories')->nullable();
            $table->integer('average_heart_rate')->nullable();
            $table->string('source', 32)->default('manual');
            $table->timestampTz('client_updated_at');
            $table->timestampTz('server_updated_at')->useCurrent();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['user_id', 'started_at']);
            $table->index(['user_id', 'server_updated_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('workouts');
    }
};
