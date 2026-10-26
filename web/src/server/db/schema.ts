/**
 * Unified Neon Postgres + Drizzle Schema shared across Mobile (Laravel API)
 * and Web (Next.js App Router) (`docs/web/03-cloud-sync-and-auth.md`,
 * `docs/api-contract.md`, and `backend/api/database/migrations/`).
 *
 * All tables live in the shared Neon database (`withered-morning-96828630`)
 * so that a user account and measurements created on Mobile are immediately
 * accessible on Web and vice versa.
 */

import {
  bigserial,
  bigint,
  boolean,
  date,
  doublePrecision,
  index,
  integer,
  json,
  pgTable,
  primaryKey,
  text,
  timestamp,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';

export const users = pgTable('users', {
  id: bigserial('id', { mode: 'number' }).primaryKey(),
  name: varchar('name', { length: 255 }).notNull(),
  displayName: varchar('display_name', { length: 255 }),
  unitPreferences: json('unit_preferences').$type<Record<string, unknown> | null>(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  emailVerifiedAt: timestamp('email_verified_at', { withTimezone: false }),
  password: varchar('password', { length: 255 }).notNull(),
  rememberToken: varchar('remember_token', { length: 100 }),
  createdAt: timestamp('created_at', { withTimezone: false }).defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: false }).defaultNow(),
});

export const webSessions = pgTable(
  'web_sessions',
  {
    id: varchar('id', { length: 64 }).primaryKey(),
    userId: bigint('user_id', { mode: 'number' })
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    tokenHash: varchar('token_hash', { length: 128 }).notNull().unique(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow(),
  },
  (table) => [index('web_sessions_user_id_idx').on(table.userId)],
);

export const measurements = pgTable(
  'measurements',
  {
    id: uuid('id').primaryKey(),
    userId: bigint('user_id', { mode: 'number' })
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    metricType: varchar('metric_type', { length: 255 }).notNull(),
    value: doublePrecision('value').notNull(),
    unit: varchar('unit', { length: 255 }).notNull(),
    secondaryValue: doublePrecision('secondary_value'),
    secondaryUnit: varchar('secondary_unit', { length: 255 }),
    tertiaryValue: doublePrecision('tertiary_value'),
    tertiaryUnit: varchar('tertiary_unit', { length: 255 }),
    recordedAt: timestamp('recorded_at', { withTimezone: true }).notNull(),
    localDay: date('local_day', { mode: 'string' }).notNull(),
    source: varchar('source', { length: 32 }).notNull().default('manual'),
    contextJson: json('context_json').$type<Record<string, unknown> | null>(),
    clientUpdatedAt: timestamp('client_updated_at', { withTimezone: true }).notNull(),
    serverUpdatedAt: timestamp('server_updated_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
    createdAt: timestamp('created_at', { withTimezone: false }).defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: false }).defaultNow(),
    deletedAt: timestamp('deleted_at', { withTimezone: false }),
  },
  (table) => [
    index('measurements_user_id_local_day_index').on(table.userId, table.localDay),
    index('measurements_user_id_metric_type_recorded_at_index').on(
      table.userId,
      table.metricType,
      table.recordedAt,
    ),
    index('measurements_user_id_server_updated_at_index').on(
      table.userId,
      table.serverUpdatedAt,
    ),
  ],
);

export const profiles = pgTable('profiles', {
  userId: bigint('user_id', { mode: 'number' })
    .primaryKey()
    .references(() => users.id, { onDelete: 'cascade' }),
  displayName: varchar('display_name', { length: 255 }),
  dateOfBirth: date('date_of_birth', { mode: 'string' }),
  sex: varchar('sex', { length: 32 }),
  heightCm: doublePrecision('height_cm'),
  preferredMassUnit: varchar('preferred_mass_unit', { length: 16 })
    .notNull()
    .default('kg'),
  preferredLengthUnit: varchar('preferred_length_unit', { length: 16 })
    .notNull()
    .default('cm'),
  preferredTemperatureUnit: varchar('preferred_temperature_unit', { length: 16 })
    .notNull()
    .default('°C'),
  timeZone: varchar('time_zone', { length: 64 }),
  weightGoalKind: varchar('weight_goal_kind', { length: 32 })
    .notNull()
    .default('none'),
  targetSystolic: integer('target_systolic'),
  targetDiastolic: integer('target_diastolic'),
  targetWeightKg: doublePrecision('target_weight_kg'),
  serverUpdatedAt: timestamp('server_updated_at', { withTimezone: true })
    .notNull()
    .defaultNow(),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow(),
});

export const goals = pgTable(
  'goals',
  {
    id: varchar('id', { length: 64 }).notNull(),
    userId: bigint('user_id', { mode: 'number' })
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    metricType: varchar('metric_type', { length: 64 }).notNull(),
    targetValue: doublePrecision('target_value').notNull(),
    unit: varchar('unit', { length: 32 }).notNull(),
    startValue: doublePrecision('start_value'),
    targetDate: varchar('target_date', { length: 32 }),
    active: boolean('active').notNull().default(true),
    serverUpdatedAt: timestamp('server_updated_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow(),
    deletedAt: timestamp('deleted_at', { withTimezone: true }),
  },
  (table) => [primaryKey({ columns: [table.userId, table.id] })],
);

export const reminders = pgTable(
  'reminders',
  {
    id: varchar('id', { length: 64 }).notNull(),
    userId: bigint('user_id', { mode: 'number' })
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    kind: varchar('kind', { length: 64 }).notNull(),
    metricType: varchar('metric_type', { length: 64 }).notNull(),
    title: varchar('title', { length: 255 }).notNull(),
    hour: integer('hour').notNull(),
    minute: integer('minute').notNull(),
    enabled: boolean('enabled').notNull().default(true),
    timeZone: varchar('time_zone', { length: 64 }),
    serverUpdatedAt: timestamp('server_updated_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow(),
    deletedAt: timestamp('deleted_at', { withTimezone: true }),
  },
  (table) => [primaryKey({ columns: [table.userId, table.id] })],
);

export const syncCursors = pgTable(
  'sync_cursors',
  {
    userId: bigint('user_id', { mode: 'number' })
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    deviceId: varchar('device_id', { length: 128 }).notNull(),
    cursorTimestamp: timestamp('cursor_timestamp', { withTimezone: true }).notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (table) => [primaryKey({ columns: [table.userId, table.deviceId] })],
);
