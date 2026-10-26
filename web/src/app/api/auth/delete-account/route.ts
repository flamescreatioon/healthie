import { NextResponse } from 'next/server';
import { clearSessionCookie, resolveRequestUser } from '@/server/auth/session';
import { deleteAccountCascade } from '@/server/db/store';

export async function DELETE(request: Request) {
  const user = await resolveRequestUser(request);
  if (!user) {
    return NextResponse.json(
      { error: 'unauthenticated', message: 'Authentication required' },
      { status: 401 },
    );
  }

  const deleted = await deleteAccountCascade(user.id);
  await clearSessionCookie();

  return NextResponse.json({
    status: 'account_deleted',
    deleted_measurements: deleted.deletedMeasurements,
    deleted_sessions: deleted.deletedSessions,
  });
}
