import { NextResponse } from 'next/server';
import {
  issueSessionForUser,
  resolveRequestUser,
  revokeCurrentSession,
  setSessionCookie,
} from '@/server/auth/session';

export async function POST(request: Request) {
  const user = await resolveRequestUser(request);
  if (!user) {
    return NextResponse.json(
      { error: 'unauthenticated', message: 'Session expired. Please sign in again.' },
      { status: 401 },
    );
  }

  await revokeCurrentSession(request);
  const { rawToken, expiresAt } = await issueSessionForUser(user.id);
  await setSessionCookie(rawToken, expiresAt);

  return NextResponse.json({
    user,
    expires_at: expiresAt,
  });
}
