# Healthie Backend (Laravel)

Laravel REST API + PostgreSQL + Sanctum. Implements `docs/api-contract.md`
under `/api/v1`. Plan: `docs/backend-roadmap.md` + `docs/backend/00-overview.md`
… `08-testing-done-criteria.md`. Decision record: `docs/adr/0005-backend-laravel.md`
(supersedes ADR-0004/Supabase).

## Layout

```
backend/
  docker-compose.yml   # local PostgreSQL 16 (db: healthie, user: healthie)
  api/                 # Laravel app (scaffold via composer, see below)
  README.md            # this file
```

## Prerequisites

- PHP 8.3+ with `ext-pdo_pgsql`
- Composer 2.x
- Docker (for local Postgres) — or point at an existing server

## Setup (run from repo root)

```bash
# 1. Verify toolchain
php -v
composer --version

# 2. Start Postgres
cd backend && docker compose up -d && cd ..

# 3. Scaffold Laravel (only once — creates backend/api/)
cd backend && composer create-project laravel/laravel api && cd ..

# 4. Sanctum for bearer tokens
cd backend/api && composer require laravel/sanctum
php artisan vendor:publish --provider="Laravel\Sanctum\SanctumServiceProvider"
```

## Database config (`backend/api/.env`)

```env
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5433
DB_DATABASE=healthie
DB_USERNAME=healthie
DB_PASSWORD=healthie
APP_TIMEZONE=UTC
```

Then:

```bash
cd backend/api
php artisan migrate:fresh --seed
php artisan test
```

## Useful commands

| Command | Purpose |
|---|---|
| `docker compose up -d` (in `backend/`) | start local Postgres |
| `php artisan migrate` | run pending migrations (never edit a shipped one — add new) |
| `php artisan migrate:fresh --seed` | rebuild dev DB |
| `php artisan test` | backend must stay green |
| `./vendor/bin/pint` | format |
