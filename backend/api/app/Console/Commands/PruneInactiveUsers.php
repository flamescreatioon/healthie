<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\PersonalAccessToken;

class PruneInactiveUsers extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'app:prune-inactive-users
                            {--months= : Inactivity threshold in months (defaults to healthie.retention_inactive_months)}
                            {--dry-run : Report prunable accounts without deleting}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Delete accounts with no token activity inside the retention window';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $months = (int) ($this->option('months') ?: config('healthie.retention_inactive_months'));
        $cutoff = Carbon::now()->subMonths($months);
        $morph = (new User)->getMorphClass();

        $activeIds = PersonalAccessToken::query()
            ->where('tokenable_type', $morph)
            ->where(function ($query) use ($cutoff): void {
                $query->where('last_used_at', '>=', $cutoff)
                    ->orWhere(function ($query) use ($cutoff): void {
                        $query->whereNull('last_used_at')->where('created_at', '>=', $cutoff);
                    });
            })
            ->pluck('tokenable_id');

        $prunable = User::query()
            ->where('created_at', '<', $cutoff)
            ->whereNotIn('id', $activeIds);

        if ($this->option('dry-run')) {
            $this->info("Prunable accounts older than {$cutoff->toDateString()}: {$prunable->count()}");

            return self::SUCCESS;
        }

        $deleted = 0;

        $prunable->chunkById(100, function ($users) use (&$deleted): void {
            foreach ($users as $user) {
                $user->deleteAccount();
                $deleted++;
            }
        });

        $this->info("Deleted {$deleted} inactive account(s).");

        return self::SUCCESS;
    }
}
