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
        Schema::create('measurements', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('metric_type');
            $table->double('value');
            $table->string('unit');
            $table->double('secondary_value')->nullable();
            $table->string('secondary_unit')->nullable();
            $table->double('tertiary_value')->nullable();
            $table->string('tertiary_unit')->nullable();
            $table->timestampTz('recorded_at');
            $table->date('local_day');
            $table->string('source', 32)->default('manual');
            $table->json('context_json')->nullable();
            $table->timestampTz('client_updated_at');
            $table->timestampTz('server_updated_at')->useCurrent();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['user_id', 'local_day']);
            $table->index(['user_id', 'metric_type', 'recorded_at']);
            $table->index(['user_id', 'server_updated_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('measurements');
    }
};
