# Phase 3 — Auth (Sanctum) + Authorization (replaces RLS)

## Auth — `POST /api/v1/auth/register|login|logout`

1. `RegisterRequest`/`LoginRequest` validation; `Hash::make` passwords;
   `createToken('mobile', ['sync'])` on register/login;
   `currentAccessToken()->delete()` on logout; revoke all on password change.
2. 401 = dead/rotated token → client drops token, routes to sign-in. No silent
   retry loop, no second refresh mechanism (Sanctum tokens don't refresh).
3. Rate-limit auth endpoints per IP + per email/device.
4. Never log tokens, passwords, or `Authorization` headers — not in Laravel
   logs, Telescope, Horizon, or error reporters. Redact before it leaves
   the server.

## Authorization — server enforces ownership on every request

1. Global scope / base query: everything private is
   `->where('user_id', auth()->id())`.
2. `MeasurementPolicy` (etc.) per model: `view/update/delete` require
   `$model->user_id === $user->id`. Register in `AuthServiceProvider`.
3. Route-model binding scoped — a raw `findOrFail($id)` without ownership
   check is a leak.
4. Another user's id → **404, not 403** (avoid id-oracle). Same for PUT/DELETE.

## Verify before any sync client code (two-user feature tests)

1. User B `GET /measurements` sees 0 of A's rows; `GET /measurements/{a-id}` → 404.
2. B `PUT/DELETE {a-id}` → 404; A unaffected.
3. Unauthenticated → 401 on every private route.
4. Expired/revoked token → 401; client signs out cleanly.

Next: [Sync endpoints](./04-sync-endpoints.md).
