/**
 * Resource CRUD endpoint: `GET / POST /api/v1/measurements` (`docs/api-contract.md` §2).
 * Enforces object-level authorization + Postgres RLS on Neon.
 */

import { NextResponse } from 'next/server';
import { resolveRequestUser } from '@/server/auth/session';
import { applySyncPushBatch, pullSyncChanges } from '@/server/db/store';

export async function GET(request: Request) {
  const user = await resolveRequestUser(request);
  if (!user) {
    return NextResponse.json(
      { error: 'unauthenticated', message: 'Authentication required' },
      { status: 401 },
    );
  }

  const url = new URL(request.url);
  const metricType = url.searchParams.get('metric_type');
  const gte = url.searchParams.get('recorded_at.gte');
  const lt = url.searchParams.get('recorded_at.lt');

  const pulled = await pullSyncChanges({
    authenticatedUserId: user.id,
    since: null,
  });

  const data = pulled.changes
    .filter((c) => c.operation !== 'delete' && !c.payload.deleted_at)
    .map((c) => c.payload)
    .filter((m) => {
      if (metricType && m.metric_type !== metricType) return false;
      if (gte && new Date(m.recorded_at).getTime() < new Date(gte).getTime()) {
        return false;
      }
      if (lt && new Date(m.recorded_at).getTime() >= new Date(lt).getTime()) {
        return false;
      }
      return true;
    });

  return NextResponse.json({ data });
}

export async function POST(request: Request) {
  const user = await resolveRequestUser(request);
  if (!user) {
    return NextResponse.json(
      { error: 'unauthenticated', message: 'Authentication required' },
      { status: 401 },
    );
  }

  const body = (await request.json()) as Record<string, unknown>;
  const id = typeof body.id === 'string' ? body.id : '';

  const pushed = await applySyncPushBatch({
    authenticatedUserId: user.id,
    operations: [
      {
        entity_type: 'measurements',
        entity_id: id,
        operation: 'upsert',
        payload: body,
        client_updated_at:
          typeof body.updated_at === 'string' ? body.updated_at : undefined,
      },
    ],
  });

  const resItem = pushed.results[0];
  if (!resItem || resItem.status === 'invalid') {
    return NextResponse.json(
      {
        error: 'validation_failed',
        message: resItem?.message ?? 'Invalid measurement payload',
        field: 'value',
      },
      { status: 422 },
    );
  }

  if (resItem.status === 'rejected' || resItem.status === 'conflict') {
    return NextResponse.json(
      {
        error: resItem.status,
        message: resItem.message ?? 'Conflict on measurement upsert',
        server_row: resItem.server_row,
      },
      { status: 409 },
    );
  }

  return NextResponse.json({ status: 'applied', id: resItem.entity_id });
}
