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
        Schema::create('meals', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('meal_type');
            $table->string('name');
            $table->integer('calories')->nullable();
            $table->double('protein_g')->nullable();
            $table->double('carbs_g')->nullable();
            $table->double('fat_g')->nullable();
            $table->timestampTz('eaten_at');
            $table->date('local_day');
            $table->string('source', 32)->default('manual');
            $table->timestampTz('client_updated_at');
            $table->timestampTz('server_updated_at')->useCurrent();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['user_id', 'local_day']);
            $table->index(['user_id', 'server_updated_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('meals');
    }
};
