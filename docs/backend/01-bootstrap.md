# Phase 1 — Laravel Project Bootstrap

**Goal:** clean Laravel API project with Sanctum, Postgres, and rate limits.

## Tasks

1. `composer create-project laravel/laravel healthie-backend` (PHP 8.3+,
   `ext-pdo_pgsql`). Configure `DB_CONNECTION=pgsql` for local/staging/prod.
2. `composer require laravel/sanctum`; publish + migrate; attach Sanctum
   `EnsureFrontendRequestsAreStateful` only if cookie SPA needed — mobile uses
   bearer tokens (`auth:sanctum` on `Route::prefix('v1')` group).
3. Base config: `APP_TIMEZONE=UTC`; API-only responses (no Blade dependency);
   CORS locked down; trusted proxies set so `https` is detected behind LB.
4. Rate limiting in `RouteServiceProvider` / `AppServiceProvider`:
   `throttle:api` default, stricter `throttle:auth` (register/login) and
   `throttle:sync` (`sync/upload`, `sync/changes`) — mobile retries hard
   on flaky networks.
5. Tooling: Pint (`composer lint`), Larastan/PHPStan, Pest or PHPUnit
   (`php artisan test`). CI runs migrate:fresh + seed + test.
6. Secrets: per-env `.env` / vault / CI secrets. Never commit `.env`.
   TLS everywhere; reject non-HTTPS API hosts in release builds.
7. Queue driver (database or redis) for export jobs + change-log pruning;
   scheduler (`schedule:run`) for retention command.

**Done when:** fresh clone → `composer install` → `php artisan migrate:fresh --seed`
→ `php artisan test` all green; private route without token → 401.

Next: [Schema](./02-schema.md).
