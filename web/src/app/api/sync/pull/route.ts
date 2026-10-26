import { NextResponse } from 'next/server';
import { resolveRequestUser } from '@/server/auth/session';
import { pullSyncChanges } from '@/server/db/store';

export async function GET(request: Request) {
  const user = await resolveRequestUser(request);
  if (!user) {
    return NextResponse.json(
      { error: 'unauthenticated', message: 'Authentication required' },
      { status: 401 },
    );
  }

  const url = new URL(request.url);
  const since = url.searchParams.get('since');

  const result = await pullSyncChanges({
    authenticatedUserId: user.id,
    since,
  });

  return NextResponse.json(result);
}
