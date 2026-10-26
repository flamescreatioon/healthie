<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations for shared Web + Mobile entities on Neon Postgres.
     */
    public function up(): void
    {
        Schema::create('web_sessions', function (Blueprint $table): void {
            $table->string('id', 64)->primary();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('token_hash', 128)->unique();
            $table->timestampTz('expires_at');
            $table->timestampsTz();

            $table->index('user_id');
        });

        Schema::create('profiles', function (Blueprint $table): void {
            $table->foreignId('user_id')->primary()->constrained('users')->cascadeOnDelete();
            $table->string('display_name')->nullable();
            $table->date('date_of_birth')->nullable();
            $table->string('sex', 32)->nullable();
            $table->double('height_cm')->nullable();
            $table->string('preferred_mass_unit', 16)->default('kg');
            $table->string('preferred_length_unit', 16)->default('cm');
            $table->string('preferred_temperature_unit', 16)->default('°C');
            $table->string('time_zone', 64)->nullable();
            $table->string('weight_goal_kind', 32)->default('none');
            $table->integer('target_systolic')->nullable();
            $table->integer('target_diastolic')->nullable();
            $table->double('target_weight_kg')->nullable();
            $table->timestampTz('server_updated_at')->useCurrent();
            $table->timestampsTz();
        });

        Schema::create('goals', function (Blueprint $table): void {
            $table->string('id', 64);
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('metric_type', 64);
            $table->double('target_value');
            $table->string('unit', 32);
            $table->double('start_value')->nullable();
            $table->string('target_date', 32)->nullable();
            $table->boolean('active')->default(true);
            $table->timestampTz('server_updated_at')->useCurrent();
            $table->timestampsTz();
            $table->softDeletesTz();

            $table->primary(['user_id', 'id']);
        });

        Schema::create('reminders', function (Blueprint $table): void {
            $table->string('id', 64);
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('kind', 64);
            $table->string('metric_type', 64);
            $table->string('title');
            $table->integer('hour');
            $table->integer('minute');
            $table->boolean('enabled')->default(true);
            $table->string('time_zone', 64)->nullable();
            $table->timestampTz('server_updated_at')->useCurrent();
            $table->timestampsTz();
            $table->softDeletesTz();

            $table->primary(['user_id', 'id']);
        });

        Schema::create('medications', function (Blueprint $table): void {
            $table->string('id', 64);
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('name');
            $table->text('dosage_instructions');
            $table->string('schedule');
            $table->timestampTz('start_date');
            $table->timestampTz('end_date')->nullable();
            $table->boolean('active')->default(true);
            $table->timestampTz('server_updated_at')->useCurrent();
            $table->timestampsTz();
            $table->softDeletesTz();

            $table->primary(['user_id', 'id']);
        });

        Schema::create('medication_logs', function (Blueprint $table): void {
            $table->string('id', 64);
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('medication_id', 64);
            $table->timestampTz('scheduled_at');
            $table->string('status', 32);
            $table->timestampTz('recorded_at');
            $table->text('notes')->nullable();
            $table->timestampTz('server_updated_at')->useCurrent();
            $table->timestampsTz();
            $table->softDeletesTz();

            $table->primary(['user_id', 'id']);
        });

        Schema::create('sync_cursors', function (Blueprint $table): void {
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('device_id', 128);
            $table->timestampTz('cursor_timestamp');
            $table->timestampTz('updated_at')->useCurrent();

            $table->primary(['user_id', 'device_id']);
        });

        if (Schema::getConnection()->getDriverName() === 'pgsql') {
            $rlsTables = [
                'measurements',
                'workouts',
                'sleep_sessions',
                'meals',
                'profiles',
                'goals',
                'reminders',
                'medications',
                'medication_logs',
                'sync_cursors',
            ];

            foreach ($rlsTables as $table) {
                DB::statement("ALTER TABLE {$table} ENABLE ROW LEVEL SECURITY");
                DB::statement("DROP POLICY IF EXISTS {$table}_user_isolation ON {$table}");
                DB::statement("
                    CREATE POLICY {$table}_user_isolation ON {$table}
                    USING (
                        current_setting('app.current_user_id', true) IS NULL
                        OR current_setting('app.current_user_id', true) = ''
                        OR user_id::text = current_setting('app.current_user_id', true)
                    )
                    WITH CHECK (
                        current_setting('app.current_user_id', true) IS NULL
                        OR current_setting('app.current_user_id', true) = ''
                        OR user_id::text = current_setting('app.current_user_id', true)
                    )
                ");
            }
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('sync_cursors');
        Schema::dropIfExists('medication_logs');
        Schema::dropIfExists('medications');
        Schema::dropIfExists('reminders');
        Schema::dropIfExists('goals');
        Schema::dropIfExists('profiles');
        Schema::dropIfExists('web_sessions');
    }
};
