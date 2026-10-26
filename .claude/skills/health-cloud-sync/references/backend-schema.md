# Supabase / Postgres Schema

Reference schema for the Healthie backend. Apply via the Supabase CLI or the SQL
editor, in a **new** migration each time — never edit a shipped migration.

```sql
-- supabase/migrations/0001_initial_schema.sql
```

## Enums

```sql
create type measurement_source as enum (
  'manual', 'health_connect', 'imported', 'derived'
);

create type sync_operation as enum ('upsert', 'delete');
```

## Shared columns

Every synced table has the same shape:

```sql
-- user_id uuid not null references auth.users(id) on delete cascade
-- id          uuid not null          -- client-generated, stable across devices
-- created_at  timestamptz not null default now()
-- client_updated_at timestamptz not null
-- updated_at  timestamptz not null default now()
-- deleted_at  timestamptz
```

`id` is client-generated so the device can create records while offline. The
primary key is `(user_id, id)` — the same record id may exist for two users
without colliding.

## Measurements

```sql
create table measurements (
  id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  metric_type text not null,
  value double precision not null,
  unit text not null,
  recorded_at timestamptz not null,
  local_day date not null,
  source measurement_source not null default 'manual',
  note text,
  created_at timestamptz not null default now(),
  client_updated_at timestamptz not null,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (user_id, id)
);

create index measurements_user_day_idx
  on measurements (user_id, local_day);
create index measurements_user_type_recorded_idx
  on measurements (user_id, metric_type, recorded_at desc);
create index measurements_sync_idx
  on measurements (user_id, updated_at);
```

`local_day` is stored as a `date`. The device computes it from the user's local
timezone at write time and sends it — the server must not recompute it, because
the server does not know the user's timezone and a device that travels keeps its
original local-day grouping.

## Workouts, sleep sessions, meals

Same column shape, with their own fields:

```sql
create table workouts (
  id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  workout_type text not null,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  duration_seconds integer not null,
  distance_meters double precision,
  calories integer,
  average_heart_rate integer,
  source measurement_source not null default 'manual',
  created_at timestamptz not null default now(),
  client_updated_at timestamptz not null,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (user_id, id)
);

create table sleep_sessions (
  id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  duration_minutes integer not null,
  deep_minutes integer,
  rem_minutes integer,
  light_minutes integer,
  awake_minutes integer,
  source measurement_source not null default 'manual',
  created_at timestamptz not null default now(),
  client_updated_at timestamptz not null,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (user_id, id)
);

create table meals (
  id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  meal_type text not null,
  name text not null,
  calories integer,
  protein_g double precision,
  carbs_g double precision,
  fat_g double precision,
  eaten_at timestamptz not null,
  local_day date not null,
  source measurement_source not null default 'manual',
  created_at timestamptz not null default now(),
  client_updated_at timestamptz not null,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (user_id, id)
);
```

## Row-Level Security

```sql
alter table measurements enable row level security;
alter table workouts enable row level security;
alter table sleep_sessions enable row level security;
alter table meals enable row level security;
```

A single helper keeps the policies consistent:

```sql
create or replace function current_user_id() returns uuid
language sql stable as $$
  select auth.uid();
$$;
```

```sql
create policy "own rows: select" on measurements
  for select using (auth.uid() = user_id);
create policy "own rows: insert" on measurements
  for insert with check (auth.uid() = user_id);
create policy "own rows: update" on measurements
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows: delete" on measurements
  for delete using (auth.uid() = user_id);
```

Repeat for the other three tables.

**A `delete` policy is still needed** even though the app soft-deletes: it lets
the account-deletion function and the cleanup job remove rows, and it keeps the
door open if soft-delete is ever abandoned.

## Sync RPCs

Two functions implement the protocol. They are `security invoker` (the default),
so RLS applies to them — the caller's `auth.uid()` scopes everything.

```sql
create or replace function sync_push(rows jsonb)
returns table (entity_id uuid, status text, server_row jsonb)
language plpgsql
security invoker
as $$
declare
  r jsonb;
  tbl text;
  rid uuid;
  op text;
  incoming_client_ts timestamptz;
  existing_deleted timestamptz;
  existing_client_ts timestamptz;
begin
  for r in select * from jsonb_array_elements(rows) loop
    tbl := r->>'entity_type';
    rid := (r->>'entity_id')::uuid;
    op := r->>'operation';
    incoming_client_ts := (r->>'client_updated_at')::timestamptz;

    if tbl = 'measurements' then
      if op = 'delete' then
        insert into measurements (id, user_id, metric_type, value, unit,
                                  recorded_at, local_day, source,
                                  client_updated_at, deleted_at)
        values (rid, auth.uid(), r->'payload'->>'metric_type',
                (r->'payload'->>'value')::double precision,
                r->'payload'->>'unit',
                (r->'payload'->>'recorded_at')::timestamptz,
                (r->'payload'->>'local_day')::date,
                coalesce((r->'payload'->>'source')::measurement_source, 'manual'),
                incoming_client_ts, now())
        on conflict (user_id, id) do update
          set deleted_at = now(), updated_at = now(),
              client_updated_at = incoming_client_ts;
        entity_id := rid; status := 'applied'; server_row := null;
        continue;
      end if;

      select deleted_at, client_updated_at into existing_deleted, existing_client_ts
        from measurements where id = rid and user_id = auth.uid();

      if existing_deleted is not null then
        -- Tombstone wins: reject the edit, hand back the deleted row.
        entity_id := rid; status := 'rejected';
        server_row := to_jsonb(m.*) from measurements m
          where m.id = rid and m.user_id = auth.uid();
        continue;
      end if;

      if existing_client_ts is null or incoming_client_ts > existing_client_ts then
        insert into measurements (id, user_id, metric_type, value, unit,
                                  recorded_at, local_day, source,
                                  client_updated_at)
        values (rid, auth.uid(), r->'payload'->>'metric_type',
                (r->'payload'->>'value')::double precision,
                r->'payload'->>'unit',
                (r->'payload'->>'recorded_at')::timestamptz,
                (r->'payload'->>'local_day')::date,
                coalesce((r->'payload'->>'source')::measurement_source, 'manual'),
                incoming_client_ts)
        on conflict (user_id, id) do update
          set metric_type = excluded.metric_type,
              value = excluded.value,
              unit = excluded.unit,
              recorded_at = excluded.recorded_at,
              local_day = excluded.local_day,
              source = excluded.source,
              client_updated_at = excluded.client_updated_at,
              updated_at = now();
        entity_id := rid; status := 'applied'; server_row := null;
      else
        entity_id := rid; status := 'conflict';
        server_row := to_jsonb(m.*) from measurements m
          where m.id = rid and m.user_id = auth.uid();
      end if;

    -- repeat the same block for workouts, sleep_sessions, meals
    end if;
  end loop;
  return next;
end;
$$;
```

The production version should factor the per-table logic into a helper rather
than repeating it four times. The shape above is written out for clarity.

```sql
create or replace function sync_pull(since timestamptz)
returns table (
  entity_type text,
  entity_id uuid,
  operation text,
  payload jsonb,
  updated_at timestamptz
)
language sql
security invoker
as $$
  select 'measurements', id,
         case when deleted_at is not null then 'delete' else 'upsert' end,
         to_jsonb(m.*), m.updated_at
    from measurements m
   where m.user_id = auth.uid()
     and m.updated_at > coalesce(since, '-infinity'::timestamptz)
  union all
  select 'workouts', id,
         case when deleted_at is not null then 'delete' else 'upsert' end,
         to_jsonb(w.*), w.updated_at
    from workouts w
   where w.user_id = auth.uid()
     and w.updated_at > coalesce(since, '-infinity'::timestamptz)
  union all
  select 'sleep_sessions', id,
         case when deleted_at is not null then 'delete' else 'upsert' end,
         to_jsonb(s.*), s.updated_at
    from sleep_sessions s
   where s.user_id = auth.uid()
     and s.updated_at > coalesce(since, '-infinity'::timestamptz)
  union all
  select 'meals', id,
         case when deleted_at is not null then 'delete' else 'upsert' end,
         to_jsonb(m.*), m.updated_at
    from meals m
   where m.user_id = auth.uid()
     and m.updated_at > coalesce(since, '-infinity'::timestamptz)
  order by updated_at asc;
$$;
```

`union all` plus `order by updated_at` gives a single ordered change log across
all entity types — which is what makes a single cursor work.

## Account Deletion

```sql
create or replace function delete_account()
returns void
language plpgsql
security invoker
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;
```

The `on delete cascade` on every `user_id` foreign key removes all health data
when the auth user is deleted. Verify this actually cascades — a leftover health
record belonging to a deleted account is a serious privacy defect.

Provide a client-facing "Delete my account" that calls this, then clears the
local database and signs out.

## Data Export

```sql
create or replace function export_my_data()
returns jsonb
language sql
security invoker
as $$
  select jsonb_build_object(
    'measurements', (select coalesce(jsonb_agg(to_jsonb(m)), '[]'::jsonb)
                        from measurements m where m.user_id = auth.uid()),
    'workouts', (select coalesce(jsonb_agg(to_jsonb(w)), '[]'::jsonb)
                    from workouts w where w.user_id = auth.uid()),
    'sleep_sessions', (select coalesce(jsonb_agg(to_jsonb(s)), '[]'::jsonb)
                          from sleep_sessions s where s.user_id = auth.uid()),
    'meals', (select coalesce(jsonb_agg(to_jsonb(m)), '[]'::jsonb)
                 from meals m where m.user_id = auth.uid()),
    'exported_at', now()
  );
$$;
```

Exporting is a legal requirement for many privacy regimes and a trust signal for
users of a health app. It should also be available offline — the local database
can export the same shape.

## Verification

Test RLS and the RPCs directly in the SQL editor with two different users before
shipping. A leak here is invisible from the app side.

```sql
-- as user A, confirm user B's rows are invisible
select count(*) from measurements;
```

Set the request JWT for the second user and re-run. The count must not change.
