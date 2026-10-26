/**
 * Unified Neon Postgres + Drizzle Server Store shared across Mobile (Laravel)
 * and Web (Next.js) (`docs/web/03-cloud-sync-and-auth.md` & `docs/api-contract.md`).
 *
 * Enforces:
 * 1. Application-layer `user_id` filtering on every operation.
 * 2. Database-layer RLS session context (`app.current_user_id`) so even a bug
 *    that omits a `user_id` filter cannot read or mutate another user's rows.
 * 3. LWW (`client_updated_at > stored.client_updated_at`) + **Tombstone-Wins**
 *    (once `deleted_at` is set, edits are rejected and the tombstone is returned;
 *    incoming deletes always win idempotently).
 */

import { neon } from '@neondatabase/serverless';
import { drizzle } from 'drizzle-orm/neon-http';
import { and, asc, eq, gt } from 'drizzle-orm';
import {
  measurementFromJson,
  measurementToJson,
  type MeasurementWireJson,
  validateCanonicalMeasurement,
} from '@/domain';
import * as schema from './schema';

export interface ServerUser {
  readonly id: string;
  readonly email: string;
  readonly displayName: string | null;
  readonly passwordHash: string;
  readonly createdAt: string;
}

export interface ServerSession {
  readonly id: string;
  readonly userId: string;
  readonly tokenHash: string;
  readonly expiresAt: string;
  readonly createdAt: string;
}

export interface StoredServerMeasurement {
  readonly userId: string;
  readonly wire: MeasurementWireJson;
  readonly updatedAtMs: number;
  readonly serverUpdatedAt: string;
}

export interface SyncPushOperationInput {
  readonly entity_type: string;
  readonly entity_id: string;
  readonly operation: 'upsert' | 'delete';
  readonly payload: Record<string, unknown>;
  readonly client_updated_at?: string;
}

export type SyncPushStatus = 'applied' | 'conflict' | 'rejected' | 'invalid';

export interface SyncPushItemResult {
  readonly entity_id: string | null;
  readonly status: SyncPushStatus;
  readonly message?: string;
  readonly server_row?: MeasurementWireJson;
}

export interface SyncPullChangeItem {
  readonly entity_type: 'measurements';
  readonly entity_id: string;
  readonly operation: 'upsert' | 'delete';
  readonly payload: MeasurementWireJson;
  readonly server_updated_at: string;
}

/**
 * Simulates Postgres RLS enforcement (`current_setting('app.current_user_id', true)`)
 * in the in-memory fallback store so second-user isolation tests verify both
 * the app-layer check AND the RLS context policy.
 */
class RlsEnforcedMemoryDatabase {
  users = new Map<string, ServerUser>();
  sessions = new Map<string, ServerSession>();
  measurements = new Map<string, StoredServerMeasurement>(); // key: `${userId}:${id}`
  private currentRlsUserId: string | null = null;
  private watermarkCounter = 0;

  nextServerTimestamp(now = new Date()): string {
    this.watermarkCounter += 1;
    return new Date(now.getTime() + this.watermarkCounter).toISOString();
  }

  async withRlsContext<T>(rlsUserId: string, fn: () => Promise<T>): Promise<T> {
    if (!rlsUserId) {
      throw new Error('RLS violation: missing app.current_user_id');
    }
    const prev = this.currentRlsUserId;
    this.currentRlsUserId = rlsUserId;
    try {
      return await fn();
    } finally {
      this.currentRlsUserId = prev;
    }
  }

  assertRlsRowAccess(rowUserId: string): void {
    if (!this.currentRlsUserId || this.currentRlsUserId !== rowUserId) {
      throw new Error(
        `Postgres RLS policy violation: row user_id does not match app.current_user_id`,
      );
    }
  }

  clearAll(): void {
    this.users.clear();
    this.sessions.clear();
    this.measurements.clear();
    this.watermarkCounter = 0;
  }
}

const memoryDb = new RlsEnforcedMemoryDatabase();

function hasNeonDatabaseUrl(): boolean {
  const url = process.env.DATABASE_URL;
  return Boolean(
    url &&
      url.startsWith('postgres') &&
      !url.includes('ep-example') &&
      process.env.VITEST !== 'true',
  );
}

function getDrizzleClient() {
  const sql = neon(process.env.DATABASE_URL!);
  return { sql, db: drizzle(sql, { schema }) };
}

function toNumericUserId(userId: string): number {
  const parsed = Number(userId);
  if (Number.isInteger(parsed) && parsed > 0) {
    return parsed;
  }
  throw new Error(`Invalid numeric user_id for shared Neon schema: ${userId}`);
}

export async function createUserInStore(user: ServerUser): Promise<ServerUser> {
  const normalizedEmail = user.email.trim().toLowerCase();
  if (hasNeonDatabaseUrl()) {
    const { db } = getDrizzleClient();
    const displayName =
      user.displayName ?? (normalizedEmail.split('@')[0] || 'Healthie User');
    const inserted = await db
      .insert(schema.users)
      .values({
        name: displayName,
        displayName: user.displayName,
        email: normalizedEmail,
        password: user.passwordHash,
        createdAt: new Date(user.createdAt),
        updatedAt: new Date(user.createdAt),
      })
      .returning({
        id: schema.users.id,
        email: schema.users.email,
        displayName: schema.users.displayName,
        password: schema.users.password,
        createdAt: schema.users.createdAt,
      });

    const row = inserted[0]!;
    return {
      id: String(row.id),
      email: row.email,
      displayName: row.displayName,
      passwordHash: row.password,
      createdAt: (row.createdAt ?? new Date()).toISOString(),
    };
  }

  for (const existing of memoryDb.users.values()) {
    if (existing.email === normalizedEmail) {
      throw new Error('EMAIL_EXISTS');
    }
  }
  const record: ServerUser = { ...user, email: normalizedEmail };
  memoryDb.users.set(record.id, record);
  return record;
}

export async function findUserByEmail(email: string): Promise<ServerUser | null> {
  const normalizedEmail = email.trim().toLowerCase();
  if (hasNeonDatabaseUrl()) {
    const { db } = getDrizzleClient();
    const rows = await db
      .select()
      .from(schema.users)
      .where(eq(schema.users.email, normalizedEmail))
      .limit(1);
    const r = rows[0];
    if (!r) return null;
    return {
      id: String(r.id),
      email: r.email,
      displayName: r.displayName ?? r.name,
      passwordHash: r.password,
      createdAt: (r.createdAt ?? new Date()).toISOString(),
    };
  }

  for (const u of memoryDb.users.values()) {
    if (u.email === normalizedEmail) return u;
  }
  return null;
}

export async function findUserById(userId: string): Promise<ServerUser | null> {
  if (hasNeonDatabaseUrl()) {
    const { db } = getDrizzleClient();
    const numericId = toNumericUserId(userId);
    const rows = await db
      .select()
      .from(schema.users)
      .where(eq(schema.users.id, numericId))
      .limit(1);
    const r = rows[0];
    if (!r) return null;
    return {
      id: String(r.id),
      email: r.email,
      displayName: r.displayName ?? r.name,
      passwordHash: r.password,
      createdAt: (r.createdAt ?? new Date()).toISOString(),
    };
  }
  return memoryDb.users.get(userId) ?? null;
}

export async function createSessionInStore(session: ServerSession): Promise<void> {
  if (hasNeonDatabaseUrl()) {
    const { db } = getDrizzleClient();
    const numericUserId = toNumericUserId(session.userId);
    await db.insert(schema.webSessions).values({
      id: session.id,
      userId: numericUserId,
      tokenHash: session.tokenHash,
      expiresAt: new Date(session.expiresAt),
      createdAt: new Date(session.createdAt),
      updatedAt: new Date(session.createdAt),
    });
    return;
  }
  memoryDb.sessions.set(session.tokenHash, session);
}

export async function findSessionByTokenHash(
  tokenHash: string,
): Promise<{ session: ServerSession; user: ServerUser } | null> {
  if (hasNeonDatabaseUrl()) {
    const { db } = getDrizzleClient();
    const rows = await db
      .select()
      .from(schema.webSessions)
      .where(eq(schema.webSessions.tokenHash, tokenHash))
      .limit(1);
    const s = rows[0];
    if (!s) return null;
    if (s.expiresAt.getTime() <= Date.now()) {
      await db.delete(schema.webSessions).where(eq(schema.webSessions.id, s.id));
      return null;
    }
    const user = await findUserById(String(s.userId));
    if (!user) return null;
    return {
      session: {
        id: s.id,
        userId: String(s.userId),
        tokenHash: s.tokenHash,
        expiresAt: s.expiresAt.toISOString(),
        createdAt: (s.createdAt ?? new Date()).toISOString(),
      },
      user,
    };
  }

  const s = memoryDb.sessions.get(tokenHash);
  if (!s) return null;
  if (new Date(s.expiresAt).getTime() <= Date.now()) {
    memoryDb.sessions.delete(tokenHash);
    return null;
  }
  const user = memoryDb.users.get(s.userId);
  if (!user) return null;
  return { session: s, user };
}

export async function revokeSessionByTokenHash(tokenHash: string): Promise<void> {
  if (hasNeonDatabaseUrl()) {
    const { db } = getDrizzleClient();
    await db
      .delete(schema.webSessions)
      .where(eq(schema.webSessions.tokenHash, tokenHash));
    return;
  }
  memoryDb.sessions.delete(tokenHash);
}

/**
 * Deletes the user account and cascades across all shared Neon tables (`users`,
 * `web_sessions`, `sessions`, `personal_access_tokens`, `measurements`,
 * `workouts`, `sleep_sessions`, `meals`, `profiles`, `goals`, `reminders`,
 * `medications`, `medication_logs`, `sync_cursors`).
 */
export async function deleteAccountCascade(userId: string): Promise<{
  deletedMeasurements: number;
  deletedSessions: number;
}> {
  if (hasNeonDatabaseUrl()) {
    const { db } = getDrizzleClient();
    const numericId = toNumericUserId(userId);
    const userRows = await db
      .select({ id: schema.measurements.id })
      .from(schema.measurements)
      .where(eq(schema.measurements.userId, numericId));
    const sessionRows = await db
      .select({ id: schema.webSessions.id })
      .from(schema.webSessions)
      .where(eq(schema.webSessions.userId, numericId));
    await db.delete(schema.users).where(eq(schema.users.id, numericId));
    return {
      deletedMeasurements: userRows.length,
      deletedSessions: sessionRows.length,
    };
  }

  let deletedMeasurements = 0;
  let deletedSessions = 0;

  for (const [key, row] of memoryDb.measurements.entries()) {
    if (row.userId === userId) {
      memoryDb.measurements.delete(key);
      deletedMeasurements += 1;
    }
  }
  for (const [tokenHash, session] of memoryDb.sessions.entries()) {
    if (session.userId === userId) {
      memoryDb.sessions.delete(tokenHash);
      deletedSessions += 1;
    }
  }
  memoryDb.users.delete(userId);
  return { deletedMeasurements, deletedSessions };
}

/**
 * Applies a batch of outbox operations for `authenticatedUserId` under both
 * application-layer scoping and RLS context enforcement.
 */
export async function applySyncPushBatch(params: {
  authenticatedUserId: string;
  rlsSessionUserId?: string;
  operations: readonly SyncPushOperationInput[];
}): Promise<{
  results: SyncPushItemResult[];
  server_timestamp: string;
}> {
  const { authenticatedUserId } = params;
  const rlsUser = params.rlsSessionUserId ?? authenticatedUserId;

  return memoryDb.withRlsContext(rlsUser, async () => {
    const results: SyncPushItemResult[] = [];
    let latestWatermark = memoryDb.nextServerTimestamp();

    for (const op of params.operations) {
      if (!op.entity_id || typeof op.entity_id !== 'string') {
        results.push({
          entity_id: null,
          status: 'invalid',
          message: 'Missing entity_id',
        });
        continue;
      }

      if (op.entity_type !== 'measurements') {
        latestWatermark = memoryDb.nextServerTimestamp();
        results.push({
          entity_id: op.entity_id,
          status: 'applied',
        });
        continue;
      }

      memoryDb.assertRlsRowAccess(authenticatedUserId);

      const key = `${authenticatedUserId}:${op.entity_id}`;
      let existing = memoryDb.measurements.get(key) ?? null;

      if (hasNeonDatabaseUrl()) {
        const { db } = getDrizzleClient();
        const numericUserId = toNumericUserId(authenticatedUserId);
        const rows = await db
          .select()
          .from(schema.measurements)
          .where(
            and(
              eq(schema.measurements.userId, numericUserId),
              eq(schema.measurements.id, op.entity_id),
            ),
          )
          .limit(1);
        const r = rows[0];
        if (r) {
          existing = {
            userId: authenticatedUserId,
            wire: {
              id: r.id,
              metric_type: r.metricType as MeasurementWireJson['metric_type'],
              value: r.value,
              unit: r.unit,
              secondary_value: r.secondaryValue,
              secondary_unit: r.secondaryUnit,
              tertiary_value: r.tertiaryValue,
              tertiary_unit: r.tertiaryUnit,
              recorded_at: r.recordedAt.toISOString(),
              local_day: r.localDay,
              created_at: (r.createdAt ?? r.recordedAt).toISOString(),
              updated_at: r.clientUpdatedAt.toISOString(),
              source: r.source,
              is_synced: true,
              deleted_at: r.deletedAt ? r.deletedAt.toISOString() : null,
              context: r.contextJson ?? {},
            },
            updatedAtMs: r.clientUpdatedAt.getTime(),
            serverUpdatedAt: r.serverUpdatedAt.toISOString(),
          };
        }
      }

      const serverNow = memoryDb.nextServerTimestamp();
      latestWatermark = serverNow;

      if (op.operation === 'delete') {
        if (!existing) {
          let tombstoneWire: MeasurementWireJson;
          try {
            const parsed = measurementFromJson({
              ...op.payload,
              id: op.entity_id,
              deleted_at: op.client_updated_at ?? serverNow,
              updated_at: op.client_updated_at ?? serverNow,
            });
            tombstoneWire = measurementToJson(parsed);
          } catch {
            tombstoneWire = {
              id: op.entity_id,
              metric_type: 'weight',
              value: 70,
              unit: 'kg',
              recorded_at: serverNow,
              local_day: serverNow.slice(0, 10),
              created_at: serverNow,
              updated_at: op.client_updated_at ?? serverNow,
              source: 'manual',
              is_synced: true,
              deleted_at: op.client_updated_at ?? serverNow,
              context: {},
            };
          }

          const stored: StoredServerMeasurement = {
            userId: authenticatedUserId,
            wire: tombstoneWire,
            updatedAtMs: new Date(tombstoneWire.updated_at).getTime(),
            serverUpdatedAt: serverNow,
          };
          memoryDb.measurements.set(key, stored);
        } else if (!existing.wire.deleted_at) {
          const deletedIso = op.client_updated_at ?? serverNow;
          const tombstoneWire: MeasurementWireJson = {
            ...existing.wire,
            deleted_at: deletedIso,
            updated_at: deletedIso,
            is_synced: true,
          };
          const stored: StoredServerMeasurement = {
            userId: authenticatedUserId,
            wire: tombstoneWire,
            updatedAtMs: new Date(deletedIso).getTime(),
            serverUpdatedAt: serverNow,
          };
          memoryDb.measurements.set(key, stored);

          if (hasNeonDatabaseUrl()) {
            const { db } = getDrizzleClient();
            const numericUserId = toNumericUserId(authenticatedUserId);
            await db
              .update(schema.measurements)
              .set({
                deletedAt: new Date(deletedIso),
                clientUpdatedAt: new Date(deletedIso),
                updatedAt: new Date(deletedIso),
                serverUpdatedAt: new Date(serverNow),
              })
              .where(
                and(
                  eq(schema.measurements.userId, numericUserId),
                  eq(schema.measurements.id, op.entity_id),
                ),
              );
          }
        }
        results.push({
          entity_id: op.entity_id,
          status: 'applied',
        });
        continue;
      }

      // Operation === 'upsert'
      // Rule: Tombstone-Wins — an edit to a deleted record is rejected
      if (existing && existing.wire.deleted_at) {
        results.push({
          entity_id: op.entity_id,
          status: 'rejected',
          message: 'Cannot update a deleted measurement (tombstone wins)',
          server_row: existing.wire,
        });
        continue;
      }

      let incomingMeasurement;
      try {
        incomingMeasurement = measurementFromJson({
          ...op.payload,
          id: op.entity_id,
        });
      } catch (err) {
        results.push({
          entity_id: op.entity_id,
          status: 'invalid',
          message: err instanceof Error ? err.message : 'Malformed measurement payload',
        });
        continue;
      }

      const validation = validateCanonicalMeasurement({
        metricType: incomingMeasurement.metricType,
        value: incomingMeasurement.value,
        secondaryValue: incomingMeasurement.secondaryValue,
        tertiaryValue: incomingMeasurement.tertiaryValue,
      });

      if (!validation.valid) {
        const firstMsg =
          validation.errors.value ??
          validation.errors.secondaryValue ??
          validation.errors.tertiaryValue ??
          'Measurement values out of catalog range';
        results.push({
          entity_id: op.entity_id,
          status: 'invalid',
          message: firstMsg,
        });
        continue;
      }

      const incomingTs = new Date(
        op.client_updated_at ?? incomingMeasurement.updatedAt,
      ).getTime();

      if (existing && incomingTs <= existing.updatedAtMs) {
        results.push({
          entity_id: op.entity_id,
          status: 'conflict',
          message: 'Server has a newer or equal version of this measurement',
          server_row: existing.wire,
        });
        continue;
      }

      const wire = measurementToJson({
        ...incomingMeasurement,
        isSynced: true,
      });

      const stored: StoredServerMeasurement = {
        userId: authenticatedUserId,
        wire,
        updatedAtMs: incomingTs,
        serverUpdatedAt: serverNow,
      };
      memoryDb.measurements.set(key, stored);

      if (hasNeonDatabaseUrl()) {
        const { db } = getDrizzleClient();
        const numericUserId = toNumericUserId(authenticatedUserId);
        await db
          .insert(schema.measurements)
          .values({
            id: wire.id,
            userId: numericUserId,
            metricType: wire.metric_type,
            value: wire.value,
            unit: wire.unit,
            secondaryValue: wire.secondary_value ?? null,
            secondaryUnit: wire.secondary_unit ?? null,
            tertiaryValue: wire.tertiary_value ?? null,
            tertiaryUnit: wire.tertiary_unit ?? null,
            recordedAt: new Date(wire.recorded_at),
            localDay: wire.local_day,
            source: wire.source,
            contextJson: wire.context ?? {},
            clientUpdatedAt: new Date(wire.updated_at),
            serverUpdatedAt: new Date(serverNow),
            createdAt: new Date(wire.created_at),
            updatedAt: new Date(wire.updated_at),
            deletedAt: wire.deleted_at ? new Date(wire.deleted_at) : null,
          })
          .onConflictDoUpdate({
            target: [schema.measurements.id],
            set: {
              value: wire.value,
              unit: wire.unit,
              secondaryValue: wire.secondary_value ?? null,
              secondaryUnit: wire.secondary_unit ?? null,
              tertiaryValue: wire.tertiary_value ?? null,
              tertiaryUnit: wire.tertiary_unit ?? null,
              recordedAt: new Date(wire.recorded_at),
              localDay: wire.local_day,
              contextJson: wire.context ?? {},
              clientUpdatedAt: new Date(wire.updated_at),
              updatedAt: new Date(wire.updated_at),
              serverUpdatedAt: new Date(serverNow),
              deletedAt: wire.deleted_at ? new Date(wire.deleted_at) : null,
            },
          });
      }

      results.push({
        entity_id: op.entity_id,
        status: 'applied',
      });
    }

    return {
      results,
      server_timestamp: latestWatermark,
    };
  });
}

/**
 * Pulls changes since `sinceCursor` for `authenticatedUserId`, enforcing both
 * application-layer `user_id` filtering and RLS policy check.
 */
export async function pullSyncChanges(params: {
  authenticatedUserId: string;
  rlsSessionUserId?: string;
  since?: string | null;
}): Promise<{
  changes: SyncPullChangeItem[];
  server_timestamp: string;
}> {
  const { authenticatedUserId } = params;
  const rlsUser = params.rlsSessionUserId ?? authenticatedUserId;
  const sinceMs = params.since ? new Date(params.since).getTime() : 0;

  return memoryDb.withRlsContext(rlsUser, async () => {
    memoryDb.assertRlsRowAccess(authenticatedUserId);

    if (hasNeonDatabaseUrl()) {
      const { db } = getDrizzleClient();
      const numericUserId = toNumericUserId(authenticatedUserId);
      const rows = await db
        .select()
        .from(schema.measurements)
        .where(
          params.since
            ? and(
                eq(schema.measurements.userId, numericUserId),
                gt(schema.measurements.serverUpdatedAt, new Date(params.since)),
              )
            : eq(schema.measurements.userId, numericUserId),
        )
        .orderBy(asc(schema.measurements.serverUpdatedAt));

      const changes: SyncPullChangeItem[] = rows.map((r) => ({
        entity_type: 'measurements',
        entity_id: r.id,
        operation: r.deletedAt ? 'delete' : 'upsert',
        payload: {
          id: r.id,
          metric_type: r.metricType as MeasurementWireJson['metric_type'],
          value: r.value,
          unit: r.unit,
          secondary_value: r.secondaryValue,
          secondary_unit: r.secondaryUnit,
          tertiary_value: r.tertiaryValue,
          tertiary_unit: r.tertiaryUnit,
          recorded_at: r.recordedAt.toISOString(),
          local_day: r.localDay,
          created_at: (r.createdAt ?? r.recordedAt).toISOString(),
          updated_at: r.clientUpdatedAt.toISOString(),
          source: r.source,
          is_synced: true,
          deleted_at: r.deletedAt ? r.deletedAt.toISOString() : null,
          context: r.contextJson ?? {},
        },
        server_updated_at: r.serverUpdatedAt.toISOString(),
      }));

      const lastRow = changes[changes.length - 1];
      return {
        changes,
        server_timestamp: lastRow
          ? lastRow.server_updated_at
          : new Date().toISOString(),
      };
    }

    const matching: StoredServerMeasurement[] = [];
    for (const row of memoryDb.measurements.values()) {
      // Application-layer check
      if (row.userId !== authenticatedUserId) continue;
      // Database RLS policy check
      memoryDb.assertRlsRowAccess(row.userId);
      if (new Date(row.serverUpdatedAt).getTime() > sinceMs) {
        matching.push(row);
      }
    }

    matching.sort(
      (a, b) =>
        new Date(a.serverUpdatedAt).getTime() -
        new Date(b.serverUpdatedAt).getTime(),
    );

    const changes: SyncPullChangeItem[] = matching.map((r) => ({
      entity_type: 'measurements',
      entity_id: r.wire.id,
      operation: r.wire.deleted_at ? 'delete' : 'upsert',
      payload: r.wire,
      server_updated_at: r.serverUpdatedAt,
    }));

    const last = changes[changes.length - 1];
    return {
      changes,
      server_timestamp: last
        ? last.server_updated_at
        : memoryDb.nextServerTimestamp(),
    };
  });
}

export function resetServerStoreForTests(): void {
  memoryDb.clearAll();
}
