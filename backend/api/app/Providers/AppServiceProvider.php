<?php

namespace App\Providers;

use App\Models\Meal;
use App\Models\Measurement;
use App\Models\SleepSession;
use App\Models\Workout;
use App\Policies\MealPolicy;
use App\Policies\MeasurementPolicy;
use App\Policies\SleepSessionPolicy;
use App\Policies\WorkoutPolicy;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Gate::policy(Measurement::class, MeasurementPolicy::class);
        Gate::policy(Workout::class, WorkoutPolicy::class);
        Gate::policy(SleepSession::class, SleepSessionPolicy::class);
        Gate::policy(Meal::class, MealPolicy::class);

        RateLimiter::for('auth', function (Request $request): Limit {
            return Limit::perMinute(10)->by($request->ip());
        });

        RateLimiter::for('sync', function (Request $request): Limit {
            $key = $request->user()?->getAuthIdentifier() ?? $request->ip();

            return Limit::perMinute(60)->by($key);
        });
    }
}
