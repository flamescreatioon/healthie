-- Healthie Shared Neon Postgres Schema + Row-Level Security (RLS)
-- Shared across Mobile (Laravel API) and Web (Next.js App Router)
-- Authority: docs/web/03-cloud-sync-and-auth.md, docs/api-contract.md, backend/api/database/migrations/

CREATE TABLE IF NOT EXISTS users (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  display_name VARCHAR(255),
  unit_preferences JSON,
  email VARCHAR(255) NOT NULL UNIQUE,
  email_verified_at TIMESTAMP,
  password VARCHAR(255) NOT NULL,
  remember_token VARCHAR(100),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS web_sessions (
  id VARCHAR(64) PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(128) NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS web_sessions_user_id_idx ON web_sessions(user_id);

CREATE TABLE IF NOT EXISTS measurements (
  id UUID PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  metric_type VARCHAR(255) NOT NULL,
  value DOUBLE PRECISION NOT NULL,
  unit VARCHAR(255) NOT NULL,
  secondary_value DOUBLE PRECISION,
  secondary_unit VARCHAR(255),
  tertiary_value DOUBLE PRECISION,
  tertiary_unit VARCHAR(255),
  recorded_at TIMESTAMPTZ NOT NULL,
  local_day DATE NOT NULL,
  source VARCHAR(32) NOT NULL DEFAULT 'manual',
  context_json JSON,
  client_updated_at TIMESTAMPTZ NOT NULL,
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);
CREATE INDEX IF NOT EXISTS measurements_user_id_local_day_index ON measurements(user_id, local_day);
CREATE INDEX IF NOT EXISTS measurements_user_id_metric_type_recorded_at_index ON measurements(user_id, metric_type, recorded_at);
CREATE INDEX IF NOT EXISTS measurements_user_id_server_updated_at_index ON measurements(user_id, server_updated_at);

CREATE TABLE IF NOT EXISTS profiles (
  user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  display_name VARCHAR(255),
  date_of_birth DATE,
  sex VARCHAR(32),
  height_cm DOUBLE PRECISION,
  preferred_mass_unit VARCHAR(16) NOT NULL DEFAULT 'kg',
  preferred_length_unit VARCHAR(16) NOT NULL DEFAULT 'cm',
  preferred_temperature_unit VARCHAR(16) NOT NULL DEFAULT '°C',
  time_zone VARCHAR(64),
  weight_goal_kind VARCHAR(32) NOT NULL DEFAULT 'none',
  target_systolic INTEGER,
  target_diastolic INTEGER,
  target_weight_kg DOUBLE PRECISION,
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS goals (
  id VARCHAR(64) NOT NULL,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  metric_type VARCHAR(64) NOT NULL,
  target_value DOUBLE PRECISION NOT NULL,
  unit VARCHAR(32) NOT NULL,
  start_value DOUBLE PRECISION,
  target_date VARCHAR(32),
  active BOOLEAN NOT NULL DEFAULT TRUE,
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  PRIMARY KEY (user_id, id)
);

CREATE TABLE IF NOT EXISTS reminders (
  id VARCHAR(64) NOT NULL,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind VARCHAR(64) NOT NULL,
  metric_type VARCHAR(64) NOT NULL,
  title VARCHAR(255) NOT NULL,
  hour INTEGER NOT NULL,
  minute INTEGER NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  time_zone VARCHAR(64),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  PRIMARY KEY (user_id, id)
);

CREATE TABLE IF NOT EXISTS sync_cursors (
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id VARCHAR(128) NOT NULL,
  cursor_timestamp TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, device_id)
);

-- Postgres Row-Level Security (RLS) policies on Neon tables
ALTER TABLE measurements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS measurements_user_isolation ON measurements;
CREATE POLICY measurements_user_isolation ON measurements
  USING (
    current_setting('app.current_user_id', true) IS NULL
    OR current_setting('app.current_user_id', true) = ''
    OR user_id::text = current_setting('app.current_user_id', true)
  )
  WITH CHECK (
    current_setting('app.current_user_id', true) IS NULL
    OR current_setting('app.current_user_id', true) = ''
    OR user_id::text = current_setting('app.current_user_id', true)
  );
