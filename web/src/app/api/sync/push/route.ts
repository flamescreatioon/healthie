import { NextResponse } from 'next/server';
import { z } from 'zod';
import { resolveRequestUser } from '@/server/auth/session';
import { applySyncPushBatch } from '@/server/db/store';

const pushRowSchema = z.object({
  entity_type: z.string().default('measurements'),
  entity_id: z.string().min(1),
  operation: z.enum(['upsert', 'delete']),
  payload: z.record(z.unknown()),
  client_updated_at: z.string().optional(),
});

const pushRequestSchema = z.object({
  rows: z.array(pushRowSchema),
});

export async function POST(request: Request) {
  const user = await resolveRequestUser(request);
  if (!user) {
    return NextResponse.json(
      { error: 'unauthenticated', message: 'Authentication required' },
      { status: 401 },
    );
  }

  try {
    const raw = await request.json();
    const parsed = pushRequestSchema.safeParse(raw);
    if (!parsed.success) {
      return NextResponse.json(
        {
          error: 'validation_failed',
          message: 'Invalid sync push batch shape',
        },
        { status: 422 },
      );
    }

    const result = await applySyncPushBatch({
      authenticatedUserId: user.id,
      operations: parsed.data.rows,
    });

    return NextResponse.json(result);
  } catch {
    return NextResponse.json(
      { error: 'server_error', message: 'Failed to process sync push' },
      { status: 500 },
    );
  }
}
